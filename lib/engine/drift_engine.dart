import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Drift Sling engine: slingshot-drift arcade racing on a toy playroom table.
///
/// The engine owns ALL state and phases. The UI only renders and forwards
/// input. Phases:
///
/// - [DriftPhase.countdown]: 3-2-1-GO ticks, owned by engine timers.
/// - [DriftPhase.aiming]: car parked at the start line (or wherever it
///   stalled). Pull back on the car and release to slingshot-launch.
/// - [DriftPhase.flying]: physics active; drag while moving to steer.
///   Pulling on the car again while slow relaunchs it — a stalled car can
///   ALWAYS be relaunched, so a "stuck car" is impossible by construction.
/// - [DriftPhase.settling]: a big moment just happened (lap, chain bank);
///   input briefly locked while the banner shows, then play resumes.
/// - [DriftPhase.over]: run finished; results available.
///
/// A watchdog timer recovers any phase found without a live timer, so stuck
/// states are impossible by construction.
enum DriftPhase { countdown, aiming, flying, settling, over }

/// Game modes.
enum DriftMode { trial, attack, cruise }

/// Track definitions: name + waviness parameters + base road width.
class TrackDef {
  final String name;
  final double a1, p1, a2, p2;
  final double roadW;
  const TrackDef(this.name, this.a1, this.p1, this.a2, this.p2, this.roadW);
}

const trackDefs = [
  TrackDef('Sunny Speedway', 0.16, 0.0, 0.10, 1.2, 64.0),
  TrackDef('Wiggly Circuit', 0.24, 0.8, 0.16, 2.4, 56.0),
  TrackDef('Spaghetti Bowl', 0.30, 1.9, 0.22, 0.4, 48.0),
];

const _samples = 240;
const _lapsToWin = 2;
const _attackSeconds = 75;

/// Difficulty scaling: road width factor, off-road drag, top speed factor,
/// and the drift meter needed per chain level.
class DifficultyTune {
  final double roadFactor;
  final double offroadDrag;
  final double speedFactor;
  final double chainNeed;
  const DifficultyTune(
      this.roadFactor, this.offroadDrag, this.speedFactor, this.chainNeed);
}

const difficultyTunes = [
  DifficultyTune(1.18, 1.6, 0.85, 80.0), // Sunday Cruise
  DifficultyTune(1.0, 2.4, 1.0, 100.0), // Track Racer
  DifficultyTune(0.85, 3.4, 1.15, 125.0), // Champion
];

/// A skid-mark segment left by drifting tires.
class SkidMark {
  final Offset a;
  final Offset b;
  final DateTime born;
  SkidMark(this.a, this.b) : born = DateTime.now();
}

/// A floating score popup ("+250 DRIFT x3!").
class ScorePopup {
  final String text;
  final Offset at;
  final DateTime born = DateTime.now();
  ScorePopup(this.text, this.at);
}

enum DriftEvent {
  launch,
  checkpoint,
  lap,
  coin,
  countTick,
  countGo,
  chainMilestone,
  crash,
  invalid,
  win,
  lose,
  banked,
}

class DriftEngine extends ChangeNotifier {
  final DriftMode mode;
  final int circuit;
  final int difficulty;
  final DifficultyTune tune;

  DriftPhase phase = DriftPhase.countdown;
  int countdown = 3;

  // Track.
  List<Offset> pts = [];
  List<int> cps = []; // checkpoint sample indices
  List<Offset> coinPts = [];
  List<bool> coinTaken = [];
  Size arena = Size.zero;

  // Car state.
  Offset pos = Offset.zero;
  Offset vel = Offset.zero;
  double heading = 0;
  double roadW = 56;

  // Run state.
  int lap = 1;
  int nextCp = 1;
  double elapsed = 0; // seconds, trial mode
  double timeLeft = _attackSeconds.toDouble();
  int score = 0;
  int coins = 0;
  int driftPoints = 0;
  bool over = false;
  bool? won; // true = finished/won, false = ran out / lost, null = quit
  int? finishMs;
  bool newBest = false;

  // Drift state.
  bool drifting = false;
  double driftMeter = 0;
  int driftChain = 0; // consecutive chain levels in the current drift
  final List<SkidMark> skids = [];
  final List<ScorePopup> popups = [];

  // Input state (engine-owned).
  Offset? pullFrom;
  Offset? pullCur;
  Offset? steerTo;

  String banner = '';
  bool paused = false;

  // Stall tracking: a slow car is always relaunchable; after 6s of crawling
  // the banner prompts the player so it never feels stuck.
  double _slowTime = 0;

  Timer? _timer; // single phase-transition timer
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;
  bool _started = false; // a run is live (set by startRun)

  /// UI hook for sounds. Set by the screen.
  void Function(DriftEvent event)? onEvent;

  DriftEngine({
    required this.mode,
    required this.circuit,
    this.difficulty = 0,
  }) : tune = difficultyTunes[difficulty.clamp(0, 2)] {
    banner = mode == DriftMode.cruise
        ? 'Free cruise — drift for fun!'
        : 'Get ready…';
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ lifecycle
  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) { return; }
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) { fn(); }
    });
  }

  void setPaused(bool v) {
    if (paused == v || _disposed || over) { return; }
    paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
    } else {
      _recover();
    }
    notifyListeners();
  }

  /// Watchdog: recover any phase found without a live timer.
  void _recover() {
    if (_disposed || over || paused || _timer != null) { return; }
    if (phase == DriftPhase.countdown) {
      _countTick(); // continue the countdown
    } else if (phase == DriftPhase.settling) {
      _afterSettle();
    }
    // aiming and flying are input-driven (a slow car can always be
    // relaunched); over is terminal. Nothing to recover there.
  }

  @visibleForTesting
  void debugRecover() => _recover();

  // --------------------------------------------------------------- setup
  void setArena(Size s) {
    if (s.width <= 0 || s.height <= 0) { return; }
    final prev = arena;
    arena = s;
    final fresh = pts.isEmpty;
    if (fresh) {
      _buildTrack();
    } else if ((prev.width - s.width).abs() > 2 ||
        (prev.height - s.height).abs() > 2) {
      // Rescale the run onto the new arena instead of resetting it.
      final sx = s.width / prev.width;
      final sy = s.height / prev.height;
      Offset sc(Offset o) => Offset(o.dx * sx, o.dy * sy);
      pts = [for (final p in pts) sc(p)];
      coinPts = [for (final p in coinPts) sc(p)];
      pos = sc(pos);
      roadW = trackDefs[circuit].roadW *
          tune.roadFactor *
          (min(s.width, s.height) / 420).clamp(0.8, 1.6);
      pullFrom = pullFrom == null ? null : sc(pullFrom!);
      pullCur = pullCur == null ? null : sc(pullCur!);
      steerTo = steerTo == null ? null : sc(steerTo!);
    }
    if (fresh &&
        phase == DriftPhase.countdown &&
        !over &&
        _timer == null &&
        !_started) {
      // First layout: the arena was zero when the screen called startRun(),
      // so that call was a no-op. Kick the countdown off now that the track
      // exists — without this the run would sit at "Get ready…" until the
      // watchdog happened to notice.
      _started = true;
      startRun();
    }
    notifyListeners();
  }

  void _buildTrack() {
    final t = trackDefs[circuit];
    final cx = arena.width / 2, cy = arena.height / 2;
    final r = min(arena.width, arena.height) * 0.36;
    pts = List.generate(_samples, (i) {
      final a = i / _samples * pi * 2;
      final rr =
          r * (1 + t.a1 * sin(2 * a + t.p1) + t.a2 * sin(3 * a + t.p2));
      return Offset(cx + rr * cos(a), cy + rr * sin(a) * 0.86);
    });
    roadW = t.roadW *
        tune.roadFactor *
        (min(arena.width, arena.height) / 420).clamp(0.8, 1.6);
    cps = List.generate(8, (i) => i * _samples ~/ 8);
    coinPts = List.generate(12, (i) => pts[(i * 20 + 10) % _samples]);
    coinTaken = List.filled(12, false);
    pos = pts[0];
    vel = Offset.zero;
    heading = 0;
  }

  /// Begin the run: countdown, then aiming.
  void startRun() {
    if (arena.width <= 0) { return; }
    _started = true;
    _buildTrack();
    lap = 1;
    nextCp = 1;
    elapsed = 0;
    timeLeft = _attackSeconds.toDouble();
    score = 0;
    coins = 0;
    driftPoints = 0;
    over = false;
    won = null;
    finishMs = null;
    drifting = false;
    driftMeter = 0;
    driftChain = 0;
    skids.clear();
    popups.clear();
    pullFrom = pullCur = steerTo = null;
    phase = DriftPhase.countdown;
    countdown = 3;
    banner = 'Get ready…';
    onEvent?.call(DriftEvent.countTick);
    notifyListeners();
    _arm(const Duration(milliseconds: 750), _countTick);
  }

  void _countTick() {
    if (over || phase != DriftPhase.countdown) { return; }
    countdown--;
    if (countdown > 0) {
      onEvent?.call(DriftEvent.countTick);
      notifyListeners();
      _arm(const Duration(milliseconds: 750), _countTick);
    } else {
      onEvent?.call(DriftEvent.countGo);
      phase = DriftPhase.aiming;
      banner = 'Pull back on the car & release to launch!';
      notifyListeners();
      // Aiming is input-driven; the watchdog leaves it alone.
    }
  }

  @visibleForTesting
  void debugSkipCountdown() {
    _timer?.cancel();
    _timer = null;
    countdown = 0;
    phase = DriftPhase.aiming;
    banner = 'Pull back on the car & release to launch!';
    notifyListeners();
  }

  // ---------------------------------------------------------------- input
  /// Can the player pull the car right now? Yes when aiming, or when flying
  /// but crawling (relaunch) — this is what makes stalls un-stickable.
  bool get canPull =>
      !over &&
      !paused &&
      (phase == DriftPhase.aiming ||
          (phase == DriftPhase.flying && vel.distance < 60));

  void pressAt(Offset at) {
    if (over || paused) { return; }
    if (canPull && (at - pos).distance < 80) {
      pullFrom = pos;
      pullCur = at;
    } else if (phase == DriftPhase.flying) {
      steerTo = at;
    } else {
      onEvent?.call(DriftEvent.invalid);
    }
    notifyListeners();
  }

  void moveAt(Offset at) {
    if (over || paused) { return; }
    if (pullFrom != null) {
      pullCur = at;
    } else if (steerTo != null) {
      steerTo = at;
    }
    notifyListeners();
  }

  void release() {
    if (over || paused) { return; }
    if (pullFrom != null && pullCur != null) {
      final pull = pullFrom! - pullCur!;
      if (pull.distance > 24) {
        var v = pull * 7.0 * tune.speedFactor;
        const cap = 1500.0;
        if (v.distance > cap) { v = v / v.distance * cap; }
        vel = v;
        heading = atan2(v.dy, v.dx);
        phase = DriftPhase.flying;
        _slowTime = 0;
        banner = 'Drag to steer!';
        onEvent?.call(DriftEvent.launch);
      } else {
        onEvent?.call(DriftEvent.invalid);
      }
    }
    pullFrom = pullCur = steerTo = null;
    notifyListeners();
  }

  // --------------------------------------------------------------- physics
  /// Advance the simulation. Called by the UI ticker; all logic is here.
  void step(double dt) {
    if (over || paused || pts.isEmpty) { return; }
    if (phase != DriftPhase.flying) { return; }

    if (mode == DriftMode.trial) {
      elapsed += dt;
    } else if (mode == DriftMode.attack) {
      timeLeft -= dt;
      if (timeLeft <= 0) {
        timeLeft = 0;
        _finish(false);
        return;
      }
    }

    // Steering: pull the car toward the drag point.
    if (steerTo != null) {
      final d = steerTo! - pos;
      if (d.distance > 4) { vel += (d / d.distance) * 640 * tune.speedFactor * dt; }
    }

    // Rolling friction + heavy drag off the painted road.
    var f = exp(-0.55 * dt);
    final offroad = _offRoad();
    if (offroad) { f *= exp(-tune.offroadDrag * dt); }
    vel *= f;

    // Crash: slamming off the road at speed.
    final speed = vel.distance;
    if (offroad && speed > 950) {
      vel *= 0.25;
      skids.add(SkidMark(pos, pos + Offset(6, 0)));
      popups.add(ScorePopup('CRASH!', pos));
      banner = 'Ouch! Back on the road!';
      onEvent?.call(DriftEvent.crash);
    }

    if (speed < 8 && steerTo == null) { vel = Offset.zero; }
    pos += vel * dt;
    pos = Offset(
      pos.dx.clamp(10.0, arena.width - 10).toDouble(),
      pos.dy.clamp(10.0, arena.height - 10).toDouble(),
    );

    final newSpeed = vel.distance;
    if (newSpeed > 24) { heading = atan2(vel.dy, vel.dx); }

    _updateDrift(dt, newSpeed, offroad);
    _checkCp();
    _checkCoins();

    // Stall detection: crawling for 6s+ prompts a relaunch (never stuck).
    if (newSpeed < 60) {
      _slowTime += dt;
      if (_slowTime > 6 && banner != 'Stalled? Pull back on the car!') {
        banner = 'Stalled? Pull back on the car!';
      }
    } else {
      _slowTime = 0;
    }

    // Fade old skid marks and popups.
    if (skids.length > 420) { skids.removeRange(0, skids.length - 420); }
    final now = DateTime.now();
    popups.removeWhere(
        (p) => now.difference(p.born).inMilliseconds > 1400);

    notifyListeners();
  }

  bool _offRoad() {
    var best = 1e18;
    for (final p in pts) {
      final d = (p - pos).distanceSquared;
      if (d < best) { best = d; }
    }
    return best > (roadW / 2) * (roadW / 2);
  }

  void _updateDrift(double dt, double speed, bool offroad) {
    // Drifting = velocity pointing away from the car's nose at speed.
    var angDiff = (atan2(vel.dy, vel.dx) - heading).abs();
    if (angDiff > pi) { angDiff = 2 * pi - angDiff; }
    final wantDrift = speed > 300 && angDiff > 0.38 && !offroad;

    if (wantDrift) {
      if (!drifting) {
        drifting = true;
        driftMeter = 0;
        driftChain = 0;
      }
      driftMeter += dt * (speed / 300);
      // Lay skid marks from the rear wheels.
      final back = Offset(cos(heading), sin(heading)) * -16;
      final side = Offset(-sin(heading), cos(heading));
      skids.add(SkidMark(pos + back + side * 8, pos + back - side * 8));
      // Chain level-up: visible + audible, never silent.
      if (driftMeter >= tune.chainNeed * (driftChain + 1)) {
        driftChain++;
        final ptsGain = driftChain * 25;
        driftPoints += ptsGain;
        score += ptsGain;
        popups.add(ScorePopup('DRIFT x$driftChain  +$ptsGain', pos));
        onEvent?.call(DriftEvent.chainMilestone);
      }
    } else if (drifting) {
      // Drift ended: bank the chain bonus visibly.
      drifting = false;
      if (driftChain > 0) {
        final bonus = driftChain * 50;
        driftPoints += bonus;
        score += bonus;
        popups.add(ScorePopup('+$bonus CHAIN BANKED!', pos));
        onEvent?.call(DriftEvent.banked);
      }
      driftMeter = 0;
      driftChain = 0;
    }
  }

  void _checkCp() {
    if (cps.isEmpty) { return; }
    final cp = pts[cps[nextCp % 8]];
    if ((pos - cp).distance < roadW * 0.9) {
      nextCp++;
      score += 25;
      popups.add(ScorePopup('+25 CHECKPOINT', cp));
      if (nextCp % 8 == 0) {
        lap++;
        score += 100;
        if (mode == DriftMode.trial && lap > _lapsToWin) {
          _finish(true);
          return;
        }
        popups.add(ScorePopup('LAP $lap!  +100', pos));
        onEvent?.call(DriftEvent.lap);
        // Brief settle: banner moment, then play resumes by engine timer.
        _settlePause(
            const Duration(milliseconds: 900), 'Lap $lap — keep pushing!');
      } else {
        onEvent?.call(DriftEvent.checkpoint);
      }
    }
  }

  void _checkCoins() {
    for (var i = 0; i < coinPts.length; i++) {
      if (!coinTaken[i] && (pos - coinPts[i]).distance < 34) {
        coinTaken[i] = true;
        coins++;
        score += 50;
        popups.add(ScorePopup('+50', coinPts[i]));
        onEvent?.call(DriftEvent.coin);
      }
    }
  }

  void _settlePause(Duration d, String thenBanner) {
    phase = DriftPhase.settling;
    banner = thenBanner;
    notifyListeners();
    _arm(d, _afterSettle);
  }

  void _afterSettle() {
    if (over || phase != DriftPhase.settling) { return; }
    phase = DriftPhase.flying;
    notifyListeners();
  }

  /// End the run. [won]: true = finished strong, false = ran out, null = quit.
  void _finish(bool? won) {
    if (over) { return; }
    over = true;
    this.won = won;
    phase = DriftPhase.over;
    finishMs =
        mode == DriftMode.trial ? (elapsed * 1000).round() : null;
    // Time bonus for trial: faster laps score more.
    if (mode == DriftMode.trial && finishMs != null) {
      final bonus = max(0, (180000 - finishMs!) ~/ 100);
      score += bonus;
    }
    pullFrom = pullCur = steerTo = null;
    drifting = false;
    banner = won == true
        ? 'Finished!'
        : won == false
            ? "Time's up!"
            : 'Cruise over!';
    notifyListeners();
    onEvent?.call(won == true ? DriftEvent.win : DriftEvent.lose);
  }

  /// Player quits from the pause menu: bank the run as a plain finish.
  void quitToMenu() {
    _finish(null);
  }

  void restart() {
    _timer?.cancel();
    paused = false;
    startRun();
  }

  // ------------------------------------------------------------- test hooks
  @visibleForTesting
  void debugTeleport(Offset p) {
    pos = p;
    notifyListeners();
  }

  @visibleForTesting
  void debugForceFlying() {
    phase = DriftPhase.flying;
    vel = const Offset(400, 0);
    heading = 0;
    notifyListeners();
  }

  /// Nearest track sample index to the car (for tests).
  @visibleForTesting
  int debugNearestCpIndex() {
    var best = 0;
    var bd = double.infinity;
    for (var i = 0; i < pts.length; i++) {
      final d = (pts[i] - pos).distanceSquared;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }
}
