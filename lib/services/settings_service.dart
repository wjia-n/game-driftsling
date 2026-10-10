import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/garage_themes.dart';

/// Persisted settings + stats for Drift Sling. Survives app restarts.
///
/// The player profile (name) is stored as ONE JSON string under
/// [kProfileJson]. NEVER use setStringList for ordered/named data on
/// Android — SharedPreferences backs StringList with an unordered StringSet,
/// which scrambles order on every restart.
class DriftSettings extends ChangeNotifier {
  // Profile — order-safe single JSON string.
  // NEVER use setStringList for this: Android backs it with an unordered
  // StringSet that scrambles slot order on every restart.
  static const _kProfileJson = 'driftsling_player_names_json';
  static const _kLegacyProfileJson =
      'driftsling_profile_json'; // pre-exemplar key, migrate once
  static const _kLegacyName = 'drift_player_name'; // legacy single-string key

  static const _kMusic = 'driftsling_music_on';
  static const _kSfx = 'driftsling_sfx_on';
  static const _kVolume = 'driftsling_volume';
  static const _kTheme = 'driftsling_theme_id';
  static const _kCar = 'driftsling_car_style';
  static const _kTrack = 'driftsling_track_style';
  static const _kDifficulty = 'driftsling_difficulty'; // 0 cruise,1 racer,2 champion
  static const _kMode = 'driftsling_mode'; // 'trial' | 'attack' | 'cruise'
  static const _kCircuit = 'driftsling_circuit';
  static const _kIsPro = 'driftsling_is_pro';
  static const _kGames = 'driftsling_games_played';
  static const _kBestScore = 'driftsling_best_score';
  static const _kBestCoins = 'driftsling_best_coins';
  static const _kCustomPrefix = 'driftsling_custom_';

  static const defaultPlayerName = 'Speedster';

  /// Encode the profile as one JSON string (order/field preserving).
  static String encodeProfile({required String name}) =>
      jsonEncode({'name': name.trim().isEmpty ? defaultPlayerName : name.trim()});

  /// Decode persisted profile; falls back to defaults on missing/corrupt.
  static String decodeProfileName(String? raw) {
    if (raw == null) { return defaultPlayerName; }
    try {
      final d = jsonDecode(raw);
      if (d is Map) {
        final n = d['name'];
        if (n is String && n.trim().isNotEmpty) { return n.trim(); }
      }
    } catch (_) { /* corrupt JSON falls back to the default name */ }
    return defaultPlayerName;
  }

  /// Read the profile, migrating (once) from the two legacy keys.
  /// Returns the decoded name; legacy keys are removed on the next [_save].
  String _readMigratedProfile(SharedPreferences p) {
    final current = p.getString(_kProfileJson);
    if (current != null) { return decodeProfileName(current); }
    final older = p.getString(_kLegacyProfileJson);
    if (older != null) { return decodeProfileName(older); }
    final legacy = p.getString(_kLegacyName);
    if (legacy == null || legacy.trim().isEmpty) { return defaultPlayerName; }
    return legacy.trim();
  }

  static const gameModes = ['trial', 'attack', 'cruise'];
  static const gameModeNames = {
    'trial': 'Time Trial',
    'attack': 'Drift Attack',
    'cruise': 'Free Cruise',
  };
  static const difficultyNames = ['Sunday Cruise', 'Track Racer', 'Champion'];

  String playerName = defaultPlayerName;
  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String themeId = 'classic';
  int carStyle = 0;
  int trackStyle = 0;
  int difficulty = 0;
  String mode = 'trial';
  int circuit = 0;
  bool isPro = true; // everything unlocked — no Pro version
  int gamesPlayed = 0;
  int bestScore = 0; // best drift-attack/cruise score
  int bestCoins = 0; // most coins in one run
  final Map<String, int> bestTimes = {}; // 'circuitX_diffY' -> milliseconds

  /// Custom theme colors (ARGB ints).
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'tableDark': 0xFF4A2F1B,
    'tableMid': 0xFF6B4426,
    'tableDeep': 0xFF2C1A0E,
    'accent': 0xFFB8321F,
    'accentLight': 0xFFE8684A,
    'accentDark': 0xFF7A1F12,
    'ivory': 0xFFF7EEDC,
    'infield': 0xFF3E6B3A,
    'road': 0xFF5B5B60,
    'roadEdge': 0xFFF0E6CE,
    'centerLine': 0xFFF5EFE0,
  };

  DriftThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return DriftThemeDef(
      id: 'custom',
      name: 'My Creation',
      tableDark: c('tableDark'),
      tableMid: c('tableMid'),
      tableDeep: c('tableDeep'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      accentDark: c('accentDark'),
      ivory: c('ivory'),
      infield: c('infield'),
      road: c('road'),
      roadEdge: c('roadEdge'),
      centerLine: c('centerLine'),
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    // Profile: prefer the order-safe JSON key; migrate legacy keys once.
    playerName = _readMigratedProfile(p);
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    themeId = p.getString(_kTheme) ?? 'classic';
    carStyle = (p.getInt(_kCar) ?? 0).clamp(0, CarStyles.names.length - 1);
    trackStyle =
        (p.getInt(_kTrack) ?? 0).clamp(0, TrackStyles.names.length - 1);
    difficulty = (p.getInt(_kDifficulty) ?? 0).clamp(0, 2);
    final m = p.getString(_kMode) ?? 'trial';
    mode = gameModes.contains(m) ? m : 'trial';
    circuit = (p.getInt(_kCircuit) ?? 0).clamp(0, 2);
    isPro = true; // everything unlocked
    gamesPlayed = p.getInt(_kGames) ?? 0;
    bestScore = p.getInt(_kBestScore) ?? 0;
    bestCoins = p.getInt(_kBestCoins) ?? 0;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] = p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    for (int c = 0; c < 3; c++) {
      for (int d = 0; d < 3; d++) {
        final ms = p.getInt('driftsling_best_${c}_$d');
        if (ms != null) { bestTimes['${c}_$d'] = ms; }
      }
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) { return; }
    await p.setString(_kProfileJson, encodeProfile(name: playerName));
    await p.remove(_kLegacyProfileJson); // drop legacy keys for good
    await p.remove(_kLegacyName);
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kTheme, themeId);
    await p.setInt(_kCar, carStyle);
    await p.setInt(_kTrack, trackStyle);
    await p.setInt(_kDifficulty, difficulty);
    await p.setString(_kMode, mode);
    await p.setInt(_kCircuit, circuit);
    await p.setBool(_kIsPro, isPro);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kBestScore, bestScore);
    await p.setInt(_kBestCoins, bestCoins);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
    for (final e in bestTimes.entries) {
      await p.setInt('driftsling_best_${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) { return; }
    var changed = false;
    if (themeId == 'custom' || DriftThemes.isProTheme(themeId)) {
      themeId = 'classic';
      changed = true;
    }
    if (CarStyles.isPro(carStyle)) {
      carStyle = 0;
      changed = true;
    }
    if (TrackStyles.isPro(trackStyle)) {
      trackStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) { _enforceFreeLimits(); }
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) { return; } // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) { return; }
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerName = clean.isEmpty ? defaultPlayerName : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0).toDouble();
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || DriftThemes.isProTheme(id))) { return; }
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setCarStyle(int v) async {
    v = v.clamp(0, CarStyles.names.length - 1);
    if (!isPro && CarStyles.isPro(v)) { return; }
    carStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setTrackStyle(int v) async {
    v = v.clamp(0, TrackStyles.names.length - 1);
    if (!isPro && TrackStyles.isPro(v)) { return; }
    trackStyle = v;
    notifyListeners();
    await _save();
  }

  /// Difficulty: 0 cruise / 1 racer / 2 champion (champion is Pro).
  Future<void> setDifficulty(int v) async {
    v = v.clamp(0, 2);
    if (!isPro && v > 1) { return; }
    difficulty = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMode(String m) async {
    if (!gameModes.contains(m)) { return; }
    mode = m;
    notifyListeners();
    await _save();
  }

  Future<void> setCircuit(int c) async {
    circuit = c.clamp(0, 2);
    notifyListeners();
    await _save();
  }

  /// Record a finished run. [ms] is the time-trial finish time (null for
  /// non-trial modes). Returns true if a NEW BEST was set.
  Future<bool> recordRun({
    required int score,
    required int coins,
    int? ms,
  }) async {
    gamesPlayed++;
    var newBest = false;
    if (score > bestScore) {
      bestScore = score;
      newBest = true;
    }
    if (coins > bestCoins) {
      bestCoins = coins;
      newBest = true;
    }
    if (ms != null) {
      final key = '${circuit}_$difficulty';
      final prev = bestTimes[key];
      if (prev == null || ms < prev) {
        bestTimes[key] = ms;
        newBest = true;
      }
    }
    notifyListeners();
    await _save();
    return newBest;
  }

  int? bestTimeMs(int circuit, int difficulty) => bestTimes['${circuit}_$difficulty'];
}
