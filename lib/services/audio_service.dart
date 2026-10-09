import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Drift Sling — all sounds synthesized in code as WAV
/// bytes. No asset files. Warm, physical, toy-garage sounds: rubber bands,
/// wooden knocks, metal toy engine, tire squeaks.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Clips are synthesized ONCE and cached.
/// - A [_musicGen] generation counter serializes track changes so the LATEST
///   request always wins — music never silently dies.
/// - Lifecycle uses pause()/resume() so interruptions resume where they left.
/// - Every public method catches player errors; audio can never crash the app.
class DriftAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _engine = AudioPlayer();
  final AudioPlayer _screech = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  final Map<String, Uint8List> _cache = {};

  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;
  bool _engineOn = false;
  bool _screechOn = false;

  DriftAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
    _engine.setReleaseMode(ReleaseMode.loop);
    _screech.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0).toDouble();
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.55 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) { stopMusic(); }
    if (!sfxOn) {
      _engineOn = false;
      _screechOn = false;
      try {
        _engine.stop();
        _screech.stop();
      } catch (_) { /* audio/store/review must never crash the app */ }
    }
  }

  Future<void> prewarm() async {
    if (_disposed) { return; }
    await Future(() {});
    _menuBytes();
    _gameBytes();
    _engineBytes();
    _screechBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0).toDouble();
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0).toDouble();
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: 0.2));
      out.addAll(List<double>.filled((_rate * gapSecs).round(), 0));
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0).toDouble());
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  /// Rubber-band twang: a plucked string with a pitch drop.
  List<double> _twang(double base, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = base * (1.0 - 0.55 * i / n);
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: 0.004) *
          (0.8 * sin(ph) + 0.4 * sin(2 * ph) * exp(-t * 18) + 0.2 * sin(3 * ph) * exp(-t * 30));
    }
    return out;
  }

  /// Toy-car engine: low sawtooth-ish buzz loop.
  List<double> _engineLoop() {
    const secs = 1.0;
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    const base = 82.0;
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final ph = 2 * pi * base * t;
      double v = sin(ph) + 0.5 * sin(2 * ph) + 0.3 * sin(3 * ph + 0.7);
      // Loop-safe amplitude wobble (integer cycles per loop).
      v *= 0.75 + 0.25 * sin(2 * pi * 4 * t);
      out[i] = v * 0.4;
    }
    // Crossfade the loop edges so it loops seamlessly.
    final xf = (_rate * 0.05).round();
    for (int i = 0; i < xf; i++) {
      final w = i / xf;
      out[i] = out[i] * w + out[n - xf + i] * (1 - w);
    }
    return out;
  }

  /// Tire screech: bandy noise loop.
  List<double> _screechLoop() {
    const secs = 0.8;
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final noise = _rand.nextDouble() * 2 - 1;
      out[i] = (0.45 * noise +
              0.3 * sin(2 * pi * 1400 * t) +
              0.2 * sin(2 * pi * 2100 * t + 0.5)) *
          0.35;
    }
    final xf = (_rate * 0.05).round();
    for (int i = 0; i < xf; i++) {
      final w = i / xf;
      out[i] = out[i] * w + out[n - xf + i] * (1 - w);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // Cheerful toy-march: C – F – G bounce, 16s loop.
        final seq = [
          [261.63, 329.63, 392.0], // C
          [174.61, 220.0, 261.63], // F
          [196.0, 246.94, 293.66], // G
          [261.63, 329.63, 392.0], // C
        ];
        final out = <double>[];
        for (final chord in seq) {
          out.addAll(_padChord(chord, 4.0));
        }
        return out;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Driving rhythm: rolling bass + pentatonic sparks, 12s loop.
        final bass = _padChord([65.41, 98.0], 12.0);
        final n = (_rate * 12).round();
        final out = List<double>.from(bass);
        final sparks = [523.25, 587.33, 659.25, 587.33, 523.25, 440.0, 523.25, 659.25];
        for (int k = 0; k < sparks.length; k++) {
          final start = (n * k / sparks.length).round();
          final tone = _tone(sparks[k], 0.45, harmonics: 0.35);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.3;
          }
        }
        return out;
      });

  Uint8List _engineBytes() => _clip('loop_engine', _engineLoop);
  Uint8List _screechBytes() => _clip('loop_screech', _screechLoop);

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) { return; }
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) { /* audio/store/review must never crash the app */ }
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));
  Future<void> invalid() =>
      _play(_clip('invalid', () => _tone(150, 0.16, harmonics: 0.5)));

  /// Slingshot launch: rubber twang + whoosh.
  Future<void> launch() => _play(_clip('launch', () {
        final tw = _twang(240, 0.35);
        final whoosh = _tone(180, 0.4, freqEnd: 900, attack: 0.1, harmonics: 0.1);
        final n = tw.length > whoosh.length ? tw.length : whoosh.length;
        final out = List<double>.filled(n, 0);
        for (int i = 0; i < n; i++) {
          out[i] = (i < tw.length ? tw[i] : 0) * 0.8 +
              (i < whoosh.length ? whoosh[i] : 0) * 0.5;
        }
        return out;
      }));

  Future<void> checkpoint() => _play(
      _clip('checkpoint', () => _arp([659.25, 880.0], 0.12, 0.02)));
  Future<void> lap() =>
      _play(_clip('lap', () => _arp([523.25, 659.25, 783.99], 0.14, 0.03)));
  Future<void> coin() =>
      _play(_clip('coin', () => _tone(1568, 0.18, freqEnd: 2093, harmonics: 0.15)));

  /// Drift-chain milestone: rising sparkle.
  Future<void> chainMilestone() => _play(
      _clip('chain', () => _arp([880.0, 1174.66, 1567.98], 0.1, 0.02)));

  Future<void> countTick() => _play(_clip('count', () => _tone(660, 0.1)));
  Future<void> countGo() => _play(_clip('go', () => _tone(990, 0.3)));

  /// Wooden crash thud.
  Future<void> crash() => _play(_clip('crash', () {
        final n = (_rate * 0.3).round();
        final out = List<double>.filled(n, 0);
        for (int i = 0; i < n; i++) {
          final t = i / _rate;
          out[i] = _env(i, n, attack: 0.004) *
              (0.9 * sin(2 * pi * 95 * t) * exp(-t * 18) +
                  0.4 * (_rand.nextDouble() * 2 - 1) * exp(-t * 40));
        }
        return out;
      }));

  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(420, 0.32, freqEnd: 840)));
  Future<void> win() => _play(_clip(
      'win', () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));
  Future<void> lose() => _play(
      _clip('lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));

  // --------------------------------------------------- continuous loops
  /// Engine hum: rate follows speed (0.7x idle .. 2.0x full chat).
  Future<void> setEngine(double speed01, {required bool running}) async {
    if (_disposed || !sfxOn) { return; }
    try {
      final s = speed01.clamp(0.0, 1.0).toDouble();
      if (!running) {
        if (_engineOn) {
          _engineOn = false;
          await _engine.stop();
        }
        return;
      }
      if (!_engineOn) {
        _engineOn = true;
        await _engine.play(BytesSource(_engineBytes()));
      }
      await _engine.setVolume((0.12 + 0.5 * s) * volume);
      await _engine.setPlaybackRate(0.7 + 1.3 * s);
    } catch (_) { /* audio/store/review must never crash the app */ }
  }

  /// Tire screech while drifting hard.
  Future<void> setScreech(bool on) async {
    if (_disposed || !sfxOn) { return; }
    if (on == _screechOn) { return; }
    _screechOn = on;
    try {
      if (on) {
        await _screech.play(BytesSource(_screechBytes()));
        await _screech.setVolume(0.4 * volume);
      } else {
        await _screech.stop();
      }
    } catch (_) { /* audio/store/review must never crash the app */ }
  }

  Future<void> stopLoops() async {
    _engineOn = false;
    _screechOn = false;
    try {
      await _engine.stop();
      await _screech.stop();
    } catch (_) { /* audio/store/review must never crash the app */ }
  }

  // ----------------------------------------------------------------- music
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) { return; }
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      try {
        await _music.resume();
      } catch (_) { /* audio/store/review must never crash the app */ }
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) { return; }
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) { return; }
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) { _currentTrack = null; }
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  Future<void> stopMusic() async {
    ++_musicGen;
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) { return; }
    try {
      await _music.stop();
    } catch (_) { /* audio/store/review must never crash the app */ }
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  Future<void> onAppPaused() async {
    if (_disposed) { return; }
    try {
      await stopLoops();
      if (_currentTrack != null) {
        await _music.pause();
        _pausedByLifecycle = true;
      }
    } catch (_) { /* audio/store/review must never crash the app */ }
  }

  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) { return; }
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
      await _engine.dispose();
      await _screech.dispose();
    } catch (_) { /* audio/store/review must never crash the app */ }
  }
}
