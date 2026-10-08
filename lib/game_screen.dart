import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

class TrackDef {
  final String name;
  final double a1, p1, a2, p2;
  const TrackDef(this.name, this.a1, this.p1, this.a2, this.p2);
}

const _tracks = [
  TrackDef('Sunny Speedway', 0.16, 0.0, 0.10, 1.2),
  TrackDef('Wiggly Circuit', 0.24, 0.8, 0.16, 2.4),
  TrackDef('Spaghetti Bowl', 0.30, 1.9, 0.22, 0.4),
];

const _samples = 240;
const _roadW = 52.0;
const _lapsToWin = 2;

class DriftSlingScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const DriftSlingScreen({super.key, required this.players, required this.callbacks});

  @override
  State<DriftSlingScreen> createState() => _DriftSlingScreenState();
}

class _DriftSlingScreenState extends State<DriftSlingScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  int _track = -1; // -1 = choosing
  List<Offset> _pts = [];
  Size _size = Size.zero;
  Offset _pos = Offset.zero;
  Offset _vel = Offset.zero;
  double _heading = 0;
  int _lap = 1;
  int _nextCp = 1;
  double _elapsed = 0;
  bool _launched = false;
  bool _over = false;
  int _coins = 0;
  List<Offset> _coinPts = [];
  List<bool> _coinTaken = [];
  Offset? _pullFrom; // car pos when pull started
  Offset? _pullCur; // current finger pos while pulling
  Offset? _steerTo; // steering target while moving
  double? _best;
  final _cps = <int>[];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _buildTrack() {
    final t = _tracks[_track];
    final cx = _size.width / 2, cy = _size.height / 2;
    final r = math.min(_size.width, _size.height) * 0.36;
    _pts = List.generate(_samples, (i) {
      final a = i / _samples * math.pi * 2;
      final rr = r * (1 + t.a1 * math.sin(2 * a + t.p1) + t.a2 * math.sin(3 * a + t.p2));
      return Offset(cx + rr * math.cos(a), cy + rr * math.sin(a) * 0.86);
    });
    _cps
      ..clear()
      ..addAll(List.generate(8, (i) => i * _samples ~/ 8));
    _coinPts = List.generate(12, (i) {
      final p = _pts[(i * 20 + 10) % _samples];
      return p + const Offset(0, -14);
    });
    _coinTaken = List.filled(12, false);
    _pos = _pts[0];
    _vel = Offset.zero;
    _heading = 0;
    _lap = 1;
    _nextCp = 1;
    _elapsed = 0;
    _launched = false;
    _over = false;
    _coins = 0;
    _loadBest();
  }

  Future<void> _loadBest() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _best = p.getDouble('drift_best_$_track'));
  }

  void _selectTrack(int i) {
    Sfx.tap();
    setState(() {
      _track = i;
      _buildTrack();
    });
  }

  void _tick(Duration _) {
    if (_track < 0 || _over || _pts.isEmpty) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    const dt = 1 / 60;
    setState(() {
      if (_launched) {
        if (_steerTo != null) {
          final d = _steerTo! - _pos;
          if (d.distance > 4) _vel += (d / d.distance) * 620 * dt;
        }
        var f = math.exp(-0.55 * dt);
        if (_offRoad()) f *= math.exp(-2.4 * dt);
        _vel *= f;
        if (_vel.distance < 6 && _steerTo == null) _vel = Offset.zero;
        _pos += _vel * dt;
        _pos = Offset(
          _pos.dx.clamp(10.0, _size.width - 10),
          _pos.dy.clamp(10.0, _size.height - 10),
        );
        if (_vel.distance > 24) _heading = math.atan2(_vel.dy, _vel.dx);
        _elapsed += dt;
        _checkCp();
        _checkCoins();
      }
    });
  }

  bool _offRoad() {
    var best = 1e9;
    for (final p in _pts) {
      final d = (p - _pos).distanceSquared;
      if (d < best) best = d;
    }
    return best > (_roadW / 2) * (_roadW / 2);
  }

  void _checkCp() {
    final cp = _pts[_cps[_nextCp % 8]];
    if ((_pos - cp).distance < _roadW * 0.9) {
      _nextCp++;
      Sfx.click();
      if (_nextCp % 8 == 0) {
        _lap++;
        if (_lap > _lapsToWin) {
          _finish();
        } else {
          Sfx.move();
        }
      }
    }
  }

  void _checkCoins() {
    for (var i = 0; i < _coinPts.length; i++) {
      if (!_coinTaken[i] && (_pos - _coinPts[i]).distance < 30) {
        _coinTaken[i] = true;
        _coins++;
        Sfx.tap();
      }
    }
  }

  Future<void> _finish() async {
    _over = true;
    _ticker.stop();
    Sfx.win();
    final p = await SharedPreferences.getInstance();
    final prevVal = p.getDouble('drift_best_$_track') ?? double.infinity;
    final isBest = _elapsed < prevVal;
    if (isBest) await p.setDouble('drift_best_$_track', _elapsed);
    if (!mounted) return;
    widget.callbacks.finish(
      headline: 'Finished in ${_elapsed.toStringAsFixed(1)}s!',
      subline: '🪙 $_coins coins · ${_tracks[_track].name}'
          '${isBest ? ' · NEW BEST! 🏆' : ' · Best: ${prevVal.toStringAsFixed(1)}s'}',
    );
  }

  void _onDown(Offset at) {
    if (_track < 0 || _over) return;
    if (!_launched || _vel.distance < 40) {
      if ((at - _pos).distance < 70) {
        _pullFrom = _pos;
        _pullCur = at;
      }
    } else {
      _steerTo = at;
    }
  }

  void _onMove(Offset at) {
    if (_pullFrom != null) {
      setState(() => _pullCur = at);
    } else if (_steerTo != null) {
      setState(() => _steerTo = at);
    }
  }

  void _onUp() {
    if (_pullFrom != null && _pullCur != null) {
      final pull = _pullFrom! - _pullCur!;
      if (pull.distance > 24) {
        var v = pull * 7.0;
        if (v.distance > 1500) v = v / v.distance * 1500;
        setState(() {
          _vel = v;
          _launched = true;
          _heading = math.atan2(v.dy, v.dx);
        });
        Sfx.move();
      }
    }
    setState(() {
      _pullFrom = null;
      _pullCur = null;
      _steerTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.of(context).theme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('⏱ ${_elapsed.toStringAsFixed(1)}s',
                  style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
              Text('🏁 Lap $_lap/$_lapsToWin',
                  style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
              Text('🪙 $_coins',
                  style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, c) {
              final s = Size(c.maxWidth, c.maxHeight);
              if (s != _size && s.width > 0) {
                _size = s;
                if (_track >= 0) _buildTrack();
              }
              return GestureDetector(
                onPanDown: (d) => _onDown(d.localPosition),
                onPanUpdate: (d) => _onMove(d.localPosition),
                onPanEnd: (_) => _onUp(),
                child: CustomPaint(
                  size: s,
                  painter: _TrackPainter(
                    pts: _pts,
                    pos: _pos,
                    heading: _heading,
                    cps: _cps,
                    nextCp: _nextCp,
                    coins: _coinPts,
                    taken: _coinTaken,
                    pullFrom: _pullFrom,
                    pullCur: _pullCur,
                    theme: theme,
                    launched: _launched,
                  ),
                ),
              );
            },
          ),
        ),
        if (_track < 0)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text('Pick your circuit 🏁',
                    style: TextStyle(color: theme.text, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < _tracks.length; i++)
                      WajihaButton(
                        label: _tracks[i].name,
                        emoji: ['🌤️', '🌀', '🍝'][i],
                        onTap: () => _selectTrack(i),
                      ),
                  ],
                ),
              ],
            ),
          )
        else if (_best != null && !_launched && _elapsed == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Best on ${_tracks[_track].name}: ${_best!.toStringAsFixed(1)}s 🏆',
                style: TextStyle(color: theme.muted)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_launched ? 'Drag to steer! 🌀' : 'Pull back on the car & release to launch! 🚀',
                style: TextStyle(color: theme.muted)),
          ),
      ],
    );
  }
}

class _TrackPainter extends CustomPainter {
  final List<Offset> pts;
  final Offset pos;
  final double heading;
  final List<int> cps;
  final int nextCp;
  final List<Offset> coins;
  final List<bool> taken;
  final Offset? pullFrom, pullCur;
  final GameTheme theme;
  final bool launched;

  _TrackPainter({
    required this.pts,
    required this.pos,
    required this.heading,
    required this.cps,
    required this.nextCp,
    required this.coins,
    required this.taken,
    required this.pullFrom,
    required this.pullCur,
    required this.theme,
    required this.launched,
  });

  Path _loop() {
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.isEmpty) return;
    final loop = _loop();
    // outer edge + road
    canvas.drawPath(loop, Paint()..style = PaintingStyle.stroke..strokeWidth = _roadW + 10..color = theme.muted.withValues(alpha: 0.35));
    canvas.drawPath(loop, Paint()..style = PaintingStyle.stroke..strokeWidth = _roadW..color = theme.surface);
    // dashed centerline
    final dash = Path();
    for (var i = 0; i < pts.length; i += 12) {
      dash.moveTo(pts[i].dx, pts[i].dy);
      dash.lineTo(pts[(i + 6) % pts.length].dx, pts[(i + 6) % pts.length].dy);
    }
    canvas.drawPath(dash, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = theme.text.withValues(alpha: 0.25));
    // start line
    final s0 = pts[0];
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromCenter(center: s0 + Offset(0, -18 + i * 12), width: 26, height: 10),
        Paint()..color = i.isEven ? theme.text : theme.muted,
      );
    }
    // next checkpoint marker
    if (cps.isNotEmpty) {
      final cp = pts[cps[nextCp % 8]];
      canvas.drawCircle(cp, 12, Paint()..color = theme.accent.withValues(alpha: 0.85));
      canvas.drawCircle(cp, 12, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = theme.text);
    }
    // coins
    for (var i = 0; i < coins.length; i++) {
      if (taken[i]) continue;
      canvas.drawCircle(coins[i], 10, Paint()..color = const Color(0xFFFFC93C));
      canvas.drawCircle(coins[i] + const Offset(-3, -3), 3.5, Paint()..color = const Color(0xFFFFF3C4));
    }
    // slingshot band + power arrow
    if (pullFrom != null && pullCur != null) {
      final pull = pullFrom! - pullCur!;
      canvas.drawLine(pullFrom!, pullCur!,
          Paint()..strokeWidth = 5..color = theme.primary.withValues(alpha: 0.7));
      if (pull.distance > 24) {
        final dir = pull / pull.distance;
        final tip = pullFrom! + dir * (pull.distance * 0.9).clamp(0, 110);
        canvas.drawLine(pullFrom!, tip, Paint()..strokeWidth = 8..color = theme.accent);
        final a = math.atan2(dir.dy, dir.dx);
        final head = Path()
          ..moveTo(tip.dx + math.cos(a) * 18, tip.dy + math.sin(a) * 18)
          ..lineTo(tip.dx + math.cos(a + 2.6) * 14, tip.dy + math.sin(a + 2.6) * 14)
          ..lineTo(tip.dx + math.cos(a - 2.6) * 14, tip.dy + math.sin(a - 2.6) * 14)
          ..close();
        canvas.drawPath(head, Paint()..color = theme.accent);
      }
    }
    // car
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(heading);
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-18, -10, 36, 20), const Radius.circular(7));
    canvas.drawRRect(body, Paint()..color = theme.primary);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-18, -10, 12, 20), const Radius.circular(6)),
        Paint()..color = theme.accent);
    canvas.drawRect(const Rect.fromLTWH(2, -7, 10, 14), Paint()..color = theme.text.withValues(alpha: 0.55));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) => true;
}
