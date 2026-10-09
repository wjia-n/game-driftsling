import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/drift_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/garage_themes.dart';
import '../theme/toy_garage.dart';

/// Drift Sling gameplay screen. The engine owns all state; this screen
/// renders it and forwards input. Wires engine events to audio and drives
/// the engine/screech loops from live physics.
class GameScreen extends StatefulWidget {
  final DriftEngine engine;
  final DriftAudio audio;
  final DriftSettings settings;

  const GameScreen({
    super.key,
    required this.engine,
    required this.audio,
    required this.settings,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;
  bool _resultsShown = false;
  double _lastEngineRate = -1;
  bool _lastEngineRunning = false;
  bool _lastScreech = false;
  bool _bgPaused = false; // engine frozen by an app-background event
  bool _pauseDialogOpen = false;

  DriftEngine get _e => widget.engine;
  DriftAudio get _a => widget.audio;
  DriftSettings get _s => widget.settings;
  DriftThemeDef get _t =>
      DriftThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _e.onEvent = _onEngineEvent;
    // Gameplay BGM on entry (menu music resumes when we pop back to menu).
    _a.startGameMusic();
    // The run starts when the arena first lays out (engine.startRun via
    // setArena); the countdown timers must never run on a zero-size track.
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // RULES.md edge case: backgrounding mid-run freezes the engine (phase
    // timers stop via setPaused) and the app-level observer pauses audio.
    // On return the pause dialog is shown so play resumes explicitly —
    // the car never moves while the player isn't looking.
    if (state == AppLifecycleState.paused) {
      if (!_e.over && !_e.paused) {
        _a.stopLoops();
        _lastEngineRunning = false;
        _lastScreech = false;
        _e.setPaused(true);
        _bgPaused = true;
      }
    } else if (state == AppLifecycleState.resumed && _bgPaused) {
      _bgPaused = false;
      if (mounted && !_e.over && _e.paused && !_pauseDialogOpen) {
        _showPauseDialog();
      }
    }
  }

  void _onEngineEvent(DriftEvent e) {
    switch (e) {
      case DriftEvent.launch:
        _a.launch();
      case DriftEvent.checkpoint:
        _a.checkpoint();
      case DriftEvent.lap:
        _a.lap();
      case DriftEvent.coin:
        _a.coin();
      case DriftEvent.countTick:
        _a.countTick();
      case DriftEvent.countGo:
        _a.countGo();
      case DriftEvent.chainMilestone:
        _a.chainMilestone();
      case DriftEvent.crash:
        _a.crash();
      case DriftEvent.invalid:
        _a.invalid();
      case DriftEvent.win:
        _a.win();
        _onRunFinished();
      case DriftEvent.lose:
        _a.lose();
        _onRunFinished();
      case DriftEvent.banked:
        _a.coin();
    }
  }

  void _tick(Duration elapsed) {
    final dt = (_lastTick == Duration.zero
            ? 1 / 60
            : (elapsed - _lastTick).inMicroseconds / 1e6)
        .clamp(0.0, 0.05)
        .toDouble();
    _lastTick = elapsed;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) { return; }
    _e.step(dt);
    _driveLoops();
    if (_e.over && !_resultsShown) {
      _resultsShown = true;
      // Let the finish banner breathe for a beat before the results card.
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) { _showResults(); }
      });
    }
  }

  /// Keep the engine hum + tire screech in sync with live physics.
  /// Change-detected so we don't hammer the platform channel every frame.
  void _driveLoops() {
    final running = _e.phase == DriftPhase.flying && !_e.paused && !_e.over;
    final speed01 = (_e.vel.distance / 1500).clamp(0.0, 1.0).toDouble();
    final rateBucket = (speed01 * 20).round();
    if (running != _lastEngineRunning || rateBucket != _lastEngineRate.round()) {
      _lastEngineRunning = running;
      _lastEngineRate = rateBucket.toDouble();
      _a.setEngine(speed01, running: running);
    }
    final screech = _e.drifting && running;
    if (screech != _lastScreech) {
      _lastScreech = screech;
      _a.setScreech(screech);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _a.stopLoops();
    _e.dispose();
    super.dispose();
  }

  Future<void> _onRunFinished() async {
    await _a.stopLoops();
    final newBest = await _s.recordRun(
      score: _e.score,
      coins: _e.coins,
      ms: _e.finishMs,
    );
    _e.newBest = newBest;
    if (mounted) { setState(() {}); }
    // Sensible review moment: a finished run with a new best, throttled to
    // every 3rd game. Graceful when not from Play — never a fake dialog.
    if (newBest && _s.gamesPlayed % 3 == 0) {
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      } catch (_) { /* audio/store/review must never crash the app */ }
    }
  }

  void _shareScore() {
    _a.click();
    final result = _e.mode == DriftMode.trial && _e.finishMs != null
        ? 'finished ${trackDefs[_e.circuit].name} in ${(_e.finishMs! / 1000).toStringAsFixed(1)}s'
        : 'scored ${_e.score} points';
    Share.share(
      'I just $result in Drift Sling! 🏎️💨\n'
      'https://play.google.com/store/apps/details?id=com.gameswajiha.driftsling',
    );
  }

  void _pause() {
    if (_e.over || _e.paused) { return; }
    _a.click();
    _a.stopLoops();
    _lastEngineRunning = false;
    _lastScreech = false;
    _e.setPaused(true);
    _showPauseDialog();
  }

  /// Shows the pause dialog; safe to call when the engine is already
  /// paused (e.g. returning from the background).
  void _showPauseDialog() {
    if (_pauseDialogOpen || _e.over) { return; }
    _pauseDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PauseDialog(
        theme: _t,
        audio: _a,
        onResume: () {
          Navigator.of(context).pop();
          _e.setPaused(false);
        },
        onRestart: () {
          Navigator.of(context).pop();
          _resultsShown = false;
          _e.restart();
        },
        onQuit: () {
          _e.quitToMenu();
          Navigator.of(context).pop(); // dialog
          Navigator.of(context).pop(); // game screen
        },
      ),
    ).then((_) {
      _pauseDialogOpen = false;
    });
  }

  void _showResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultsDialog(
        theme: _t,
        settings: _s,
        engine: _e,
        audio: _a,
        onShare: _shareScore,
        onReplay: () {
          Navigator.of(context).pop();
          _resultsShown = false;
          _e.restart();
        },
        onMenu: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return TableBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _e,
            builder: (_, _) => Column(
              children: [
                _Hud(
                  theme: t,
                  engine: _e,
                  onPause: _pause,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, c) {
                      final s = Size(c.maxWidth, c.maxHeight);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_e.arena != s) { _e.setArena(s); }
                      });
                      return GestureDetector(
                        onPanDown: (d) => _e.pressAt(d.localPosition),
                        onPanUpdate: (d) => _e.moveAt(d.localPosition),
                        onPanEnd: (_) => _e.release(),
                        child: CustomPaint(
                          size: s,
                          painter: _TrackPainter(
                            e: _e,
                            theme: t,
                            carBody: CarStyles.bodies[
                                _s.carStyle.clamp(0, CarStyles.bodies.length - 1)],
                            carStripe: CarStyles.stripes[
                                _s.carStyle.clamp(0, CarStyles.stripes.length - 1)],
                            trackStyle: _s.trackStyle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _BottomBar(theme: t, engine: _e),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _Hud extends StatelessWidget {
  final DriftThemeDef theme;
  final DriftEngine engine;
  final VoidCallback onPause;
  const _Hud(
      {required this.theme, required this.engine, required this.onPause});

  @override
  Widget build(BuildContext context) {
    final e = engine;
    String left, mid;
    if (e.mode == DriftMode.trial) {
      left = '⏱ ${e.elapsed.toStringAsFixed(1)}s';
      mid = e.over
          ? '🏁 DONE'
          : '🏁 Lap ${e.lap.clamp(1, 2)}/2';
    } else if (e.mode == DriftMode.attack) {
      left = '⏳ ${e.timeLeft.ceil()}s';
      mid = '⭐ ${e.score}';
    } else {
      left = '⭐ ${e.score}';
      mid = '🪙 ${e.coins}';
    }
    final right = e.mode == DriftMode.cruise
        ? '🌀 x${e.driftChain}'
        : '🪙 ${e.coins}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.pause_circle_filled,
                color: theme.accentLight, size: 30),
            onPressed: onPause,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.accent.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(left,
                      style: Garage.label(15, theme: theme)),
                  Text(mid, style: Garage.label(15, theme: theme)),
                  Text(right, style: Garage.label(15, theme: theme)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _BottomBar extends StatelessWidget {
  final DriftThemeDef theme;
  final DriftEngine engine;
  const _BottomBar({required this.theme, required this.engine});

  @override
  Widget build(BuildContext context) {
    final e = engine;
    Widget status;
    if (e.phase == DriftPhase.countdown) {
      status = Text(
        e.countdown > 0 ? '${e.countdown}' : 'GO!',
        style: Garage.display(40, theme: theme),
      );
    } else if (e.drifting && e.driftChain > 0) {
      final need =
          difficultyTunes[e.difficulty].chainNeed * (e.driftChain + 1);
      status = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🌀 DRIFT x${e.driftChain}',
              style: Garage.display(22, theme: theme)),
          const SizedBox(height: 4),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              value: (e.driftMeter / need).clamp(0.0, 1.0).toDouble(),
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.accentLight),
              minHeight: 8,
            ),
          ),
        ],
      );
    } else {
      status = Text(
        e.banner,
        style: Garage.body(14,
            theme: theme,
            color: theme.ivory.withValues(alpha: 0.85)),
        textAlign: TextAlign.center,
      );
    }
    return Container(
      height: 76,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(
              '${e.phase}-${e.drifting}-${e.driftChain}-${e.banner}-${e.countdown}'),
          child: status,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _PauseDialog extends StatelessWidget {
  final DriftThemeDef theme;
  final DriftAudio audio;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _PauseDialog({
    required this.theme,
    required this.audio,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.tableMid, theme.tableDeep],
          ),
          border: Border.all(color: theme.accent, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Paused', style: Garage.display(30, theme: theme)),
            const SizedBox(height: 8),
            Text('Catch your breath, racer.',
                style: Garage.body(14, theme: theme)),
            const SizedBox(height: 18),
            GarageButton(
                label: '▶  Resume',
                theme: theme,
                width: 220,
                onTap: () {
                  audio.click();
                  onResume();
                }),
            const SizedBox(height: 10),
            GarageButton(
                label: '🔄  Restart',
                theme: theme,
                width: 220,
                onTap: () {
                  audio.click();
                  onRestart();
                }),
            const SizedBox(height: 10),
            GarageButton(
                label: '🏠  Quit',
                theme: theme,
                width: 220,
                onTap: () {
                  audio.click();
                  onQuit();
                }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _ResultsDialog extends StatelessWidget {
  final DriftThemeDef theme;
  final DriftSettings settings;
  final DriftEngine engine;
  final DriftAudio audio;
  final VoidCallback onShare;
  final VoidCallback onReplay;
  final VoidCallback onMenu;
  const _ResultsDialog({
    required this.theme,
    required this.settings,
    required this.engine,
    required this.audio,
    required this.onShare,
    required this.onReplay,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final e = engine;
    final title = e.won == true
        ? '🏆 Finished!'
        : e.won == false
            ? "⏱ Time's Up!"
            : '🛋 Cruise Over';
    final lines = <String>[];
    if (e.finishMs != null) {
      lines.add('Time: ${(e.finishMs! / 1000).toStringAsFixed(1)}s');
    }
    lines.add('Score: ${e.score}');
    lines.add('Coins: ${e.coins} 🪙');
    lines.add('Drift points: ${e.driftPoints}');
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.tableMid, theme.tableDeep],
          ),
          border: Border.all(color: theme.accent, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: Garage.display(28, theme: theme),
                textAlign: TextAlign.center),
            if (e.newBest) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.accent.withValues(alpha: 0.3),
                  border: Border.all(color: theme.accentLight),
                ),
                child: Text('✨ NEW BEST! ✨',
                    style: Garage.label(15, theme: theme)),
              ),
            ],
            const SizedBox(height: 12),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(l, style: Garage.body(16, theme: theme)),
              ),
            const SizedBox(height: 6),
            Text(
              '${settings.playerName} — ${trackDefs[e.circuit].name}',
              style: Garage.body(13,
                  theme: theme,
                  color: theme.ivory.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 18),
            GarageButton(
                label: '🔄  Race Again',
                theme: theme,
                width: 220,
                onTap: () {
                  audio.click();
                  onReplay();
                }),
            const SizedBox(height: 10),
            GarageButton(
                label: '📣  Share Score',
                theme: theme,
                width: 220,
                onTap: onShare),
            const SizedBox(height: 10),
            GarageButton(
                label: '🏠  Menu',
                theme: theme,
                width: 220,
                onTap: () {
                  audio.click();
                  onMenu();
                }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Toy-table track renderer: painted road, curbs per track style, skid
/// marks, coins, checkpoint flag, die-cast car, slingshot band, popups.
class _TrackPainter extends CustomPainter {
  final DriftEngine e;
  final DriftThemeDef theme;
  final Color carBody;
  final Color carStripe;
  final int trackStyle;

  _TrackPainter({
    required this.e,
    required this.theme,
    required this.carBody,
    required this.carStripe,
    required this.trackStyle,
  });

  Path _loop() {
    final path = Path()
      ..moveTo(e.pts[0].dx, e.pts[0].dy);
    for (var i = 1; i < e.pts.length; i++) {
      path.lineTo(e.pts[i].dx, e.pts[i].dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (e.pts.isEmpty) { return; }
    final loop = _loop();
    final now = DateTime.now();

    // Infield felt wash.
    canvas.drawPath(
        loop,
        Paint()
          ..style = PaintingStyle.fill
          ..color = theme.infield.withValues(alpha: 0.55));

    // Track-style edge treatments.
    _paintEdges(canvas, loop);

    // Road surface with a soft inner shadow for depth.
    canvas.drawPath(
        loop,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = e.roadW
          ..color = theme.road);
    canvas.drawPath(
        loop,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = e.roadW - 10
          ..color = theme.road.withValues(alpha: 0.0));

    // Centerline per style.
    _paintCenterline(canvas);

    // Start/finish checker strip.
    _paintStartLine(canvas);

    // Skid marks (fade over ~8s).
    for (final s in e.skids) {
      final age = now.difference(s.born).inMilliseconds;
      final alpha = (1 - age / 8000).clamp(0.0, 1.0);
      if (alpha <= 0) { continue; }
      canvas.drawLine(
          s.a,
          s.b,
          Paint()
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF2A2018).withValues(alpha: 0.55 * alpha));
    }

    // Next checkpoint flag.
    if (e.cps.isNotEmpty && !e.over) {
      final cp = e.pts[e.cps[e.nextCp % 8]];
      final pulse =
          0.75 + 0.25 * math.sin(now.millisecondsSinceEpoch / 220);
      canvas.drawCircle(
          cp, 13, Paint()..color = theme.accent.withValues(alpha: 0.9 * pulse));
      canvas.drawCircle(
          cp,
          13,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = theme.ivory);
      // Flag pole + pennant.
      canvas.drawLine(
          cp, cp + const Offset(0, -26), Paint()..strokeWidth = 3 ..color = theme.ivory);
      final flag = Path()
        ..moveTo(cp.dx, cp.dy - 26)
        ..lineTo(cp.dx + 20, cp.dy - 20)
        ..lineTo(cp.dx, cp.dy - 14)
        ..close();
      canvas.drawPath(flag, Paint()..color = theme.accentLight);
    }

    // Coins.
    for (var i = 0; i < e.coinPts.length; i++) {
      if (e.coinTaken[i]) { continue; }
      final c = e.coinPts[i];
      final bob = math.sin(now.millisecondsSinceEpoch / 300 + i) * 3;
      final cc = c + Offset(0, bob);
      canvas.drawCircle(
          cc + const Offset(0, 3), 10, Paint()..color = Colors.black.withValues(alpha: 0.3));
      canvas.drawCircle(cc, 10, Paint()..color = const Color(0xFFD4A017));
      canvas.drawCircle(cc, 7,
          Paint()..color = const Color(0xFFF2D06B));
      canvas.drawCircle(
          cc + const Offset(-2.5, -2.5), 2.5, Paint()..color = const Color(0xFFFFF3C4));
    }

    // Slingshot band + power arrow while pulling.
    if (e.pullFrom != null && e.pullCur != null) {
      final pull = e.pullFrom! - e.pullCur!;
      canvas.drawLine(
          e.pullFrom!,
          e.pullCur!,
          Paint()
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round
            ..color = theme.accent.withValues(alpha: 0.75));
      if (pull.distance > 24) {
        final dir = pull / pull.distance;
        final tip =
            e.pullFrom! + dir * (pull.distance * 0.9).clamp(0, 120).toDouble();
        canvas.drawLine(
            e.pullFrom!,
            tip,
            Paint()
              ..strokeWidth = 9
              ..strokeCap = StrokeCap.round
              ..color = theme.accentLight);
        final a = math.atan2(dir.dy, dir.dx);
        final head = Path()
          ..moveTo(tip.dx + math.cos(a) * 20, tip.dy + math.sin(a) * 20)
          ..lineTo(tip.dx + math.cos(a + 2.6) * 15,
              tip.dy + math.sin(a + 2.6) * 15)
          ..lineTo(tip.dx + math.cos(a - 2.6) * 15,
              tip.dy + math.sin(a - 2.6) * 15)
          ..close();
        canvas.drawPath(head, Paint()..color = theme.accentLight);
        // Power pips.
        final pips = (pull.distance / 60).clamp(1, 5).round();
        for (var k = 0; k < pips; k++) {
          final p = e.pullFrom! + dir * (14.0 + k * 16);
          canvas.drawCircle(p, 5, Paint()..color = theme.accentLight);
        }
      }
    }

    _paintCar(canvas);

    // Floating score popups.
    for (final p in e.popups) {
      final age = now.difference(p.born).inMilliseconds;
      final t01 = (age / 1400).clamp(0.0, 1.0).toDouble();
      final rise = 34 * t01;
      final alpha = 1 - t01;
      final tp = TextPainter(
        text: TextSpan(
          text: p.text,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: theme.accentLight.withValues(alpha: alpha),
            shadows: [
              Shadow(
                  color: Colors.black.withValues(alpha: 0.6 * alpha),
                  offset: const Offset(0, 2),
                  blurRadius: 3),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, p.at + Offset(-tp.width / 2, -46 - rise));
    }
  }

  void _paintEdges(Canvas canvas, Path loop) {
    final w = e.roadW;
    switch (trackStyle) {
      case 1: // Checkered curbs.
        canvas.drawPath(
            loop,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w + 12
              ..color = theme.roadEdge);
        for (var i = 0; i < e.pts.length; i += 8) {
          final p = e.pts[i];
          canvas.drawCircle(
              p,
              7,
              Paint()
                ..color = (i ~/ 8).isEven
                    ? const Color(0xFF2E2E34)
                    : theme.ivory);
        }
      case 2: // Painter's tape.
        canvas.drawPath(
            loop,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w + 12
              ..color = const Color(0xFF3F7FBF));
        canvas.drawPath(
            loop,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w + 4
              ..color = theme.roadEdge.withValues(alpha: 0.6));
      case 4: // Construction zone barriers.
        canvas.drawPath(
            loop,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w + 14
              ..color = theme.roadEdge);
        for (var i = 0; i < e.pts.length; i += 10) {
          final p = e.pts[i];
          canvas.drawCircle(
              p,
              8,
              Paint()
                ..color = (i ~/ 10).isEven
                    ? const Color(0xFFE8762B)
                    : theme.ivory);
        }
      case 5: // Wooden fence posts.
        canvas.drawPath(
            loop,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w + 10
              ..color = theme.roadEdge.withValues(alpha: 0.5));
        for (var i = 0; i < e.pts.length; i += 12) {
          final p = e.pts[i];
          canvas.drawRect(
              Rect.fromCenter(center: p, width: 7, height: 14),
              Paint()..color = const Color(0xFF7A5230));
        }
      case 6: // Flower garden daisies.
        canvas.drawPath(
            loop,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w + 10
              ..color = theme.infield);
        for (var i = 0; i < e.pts.length; i += 14) {
          final p = e.pts[i];
          for (var pet = 0; pet < 6; pet++) {
            final a = pet / 6 * math.pi * 2;
            canvas.drawCircle(
                p + Offset(math.cos(a) * 7, math.sin(a) * 7),
                3.2,
                Paint()..color = theme.ivory);
          }
          canvas.drawCircle(p, 3.2, Paint()..color = const Color(0xFFF2D06B));
        }
      case 7: // Cork edge.
        canvas.drawPath(
            loop,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w + 12
              ..color = const Color(0xFFB08D54));
      case 3: // Chalk lines: rough double chalk edge.
        canvas.drawPath(
            loop,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w + 8
              ..color = theme.ivory.withValues(alpha: 0.35));
        canvas.drawPath(
            loop,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w + 14
              ..color = theme.ivory.withValues(alpha: 0.18));
      default: // 0 Painted Dashes edge.
        canvas.drawPath(
            loop,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w + 10
              ..color = theme.roadEdge);
    }
  }

  void _paintCenterline(Canvas canvas) {
    if (trackStyle == 3) {
      // Chalk: wobbly chalk dashes.
      final dash = Path();
      for (var i = 0; i < e.pts.length; i += 14) {
        dash.moveTo(e.pts[i].dx, e.pts[i].dy);
        dash.lineTo(e.pts[(i + 7) % e.pts.length].dx,
            e.pts[(i + 7) % e.pts.length].dy);
      }
      canvas.drawPath(
          dash,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..color = theme.centerLine.withValues(alpha: 0.8));
      return;
    }
    final dash = Path();
    for (var i = 0; i < e.pts.length; i += 12) {
      dash.moveTo(e.pts[i].dx, e.pts[i].dy);
      dash.lineTo(e.pts[(i + 6) % e.pts.length].dx,
          e.pts[(i + 6) % e.pts.length].dy);
    }
    canvas.drawPath(
        dash,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = theme.centerLine.withValues(alpha: 0.7));
  }

  void _paintStartLine(Canvas canvas) {
    final s0 = e.pts[0];
    final dir = (e.pts[4] - e.pts[0]);
    final ang = math.atan2(dir.dy, dir.dx);
    canvas.save();
    canvas.translate(s0.dx, s0.dy);
    canvas.rotate(ang);
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(0, -18 + i * 12), width: 10, height: 10),
        Paint()
          ..color =
              (i.isEven ? theme.ivory : const Color(0xFF2E2E34)),
      );
    }
    canvas.restore();
  }

  /// Die-cast toy car: soft shadow, metal-flake body, painted stripe,
  /// cabin windows, rubber tires, headlights. Rotates to [heading].
  void _paintCar(Canvas canvas) {
    canvas.save();
    canvas.translate(e.pos.dx, e.pos.dy);
    // Soft contact shadow.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-19, -8, 38, 22), const Radius.circular(9)),
        Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.rotate(e.heading);
    // Tires (4, rubber).
    const tire = Rect.fromLTWH(-13, -13, 12, 6);
    const tire2 = Rect.fromLTWH(4, -13, 12, 6);
    const tire3 = Rect.fromLTWH(-13, 7, 12, 6);
    const tire4 = Rect.fromLTWH(4, 7, 12, 6);
    for (final r in [tire, tire2, tire3, tire4]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(3)),
          Paint()..color = const Color(0xFF232326));
    }
    // Body with a top-light metal sheen.
    final bodyRect =
        RRect.fromRectAndRadius(const Rect.fromLTWH(-18, -10, 36, 20), const Radius.circular(8));
    canvas.drawRRect(
        bodyRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _lighten(carBody, 0.25),
              carBody,
              _darken(carBody, 0.25),
            ],
          ).createShader(const Rect.fromLTWH(-18, -10, 36, 20)));
    // Racing stripe.
    canvas.drawRect(
        const Rect.fromLTWH(-18, -2.5, 36, 5), Paint()..color = carStripe);
    // Cabin windows.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-2, -7, 11, 14), const Radius.circular(4)),
        Paint()..color = const Color(0xFFBFD9E8).withValues(alpha: 0.9));
    // Headlights.
    canvas.drawCircle(
        const Offset(17, -6), 2.4, Paint()..color = const Color(0xFFFFF3C4));
    canvas.drawCircle(
        const Offset(17, 6), 2.4, Paint()..color = const Color(0xFFFFF3C4));
    // Rear spoiler.
    canvas.drawRect(
        const Rect.fromLTWH(-20, -11, 4, 22), Paint()..color = _darken(carBody, 0.35));
    // Outline for that painted-toy crispness.
    canvas.drawRRect(
        bodyRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.black.withValues(alpha: 0.4));
    canvas.restore();
  }

  Color _lighten(Color c, double amt) {
    final h = HSLColor.fromColor(c);
    return h
        .withLightness((h.lightness + amt).clamp(0.0, 1.0).toDouble())
        .toColor();
  }

  Color _darken(Color c, double amt) {
    final h = HSLColor.fromColor(c);
    return h
        .withLightness((h.lightness - amt).clamp(0.0, 1.0).toDouble())
        .toColor();
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) => true;
}
