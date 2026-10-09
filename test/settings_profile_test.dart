import 'package:flutter_test/flutter_test.dart';
import 'package:driftsling/services/settings_service.dart';

/// Regression tests for the profile persistence contract:
///
/// The driver profile is stored as ONE JSON string. setStringList must
/// never be used for it — on Android, SharedPreferences backs StringList
/// with an unordered StringSet, which scrambles order on every restart.
void main() {
  test('profile name survives an encode/decode round-trip exactly', () {
    const name = 'Wajiha';
    final decoded = DriftSettings.decodeProfileName(
      DriftSettings.encodeProfile(name: name),
    );
    expect(decoded, name);
  });

  test('decode falls back to the default on missing or corrupt data', () {
    expect(
      DriftSettings.decodeProfileName(null),
      DriftSettings.defaultPlayerName,
    );
    expect(
      DriftSettings.decodeProfileName('definitely not json'),
      DriftSettings.defaultPlayerName,
    );
    expect(
      DriftSettings.decodeProfileName('["not","an","object"]'),
      DriftSettings.defaultPlayerName,
    );
    expect(
      DriftSettings.decodeProfileName('{"other":"fields"}'),
      DriftSettings.defaultPlayerName,
    );
    expect(
      DriftSettings.decodeProfileName('{"name":"   "}'),
      DriftSettings.defaultPlayerName,
    );
  });

  test('blank names fall back to the default, valid names are trimmed', () {
    expect(
      DriftSettings.decodeProfileName(
          DriftSettings.encodeProfile(name: '   ')),
      DriftSettings.defaultPlayerName,
    );
    expect(
      DriftSettings.decodeProfileName(
          DriftSettings.encodeProfile(name: '  Zara  ')),
      'Zara',
    );
  });

  test('free tier clamps Champion difficulty and Pro-only styles', () async {
    final s = DriftSettings();
    // No prefs loaded: isPro defaults to false.
    await s.setDifficulty(2); // Champion is Pro-only
    expect(s.difficulty, isNot(2));
    await s.setTheme('midnight'); // Pro theme
    expect(s.themeId, isNot('midnight'));
    await s.setCarStyle(8); // Pro car paint
    expect(s.carStyle, isNot(8));
    await s.setTrackStyle(7); // Pro track style
    expect(s.trackStyle, isNot(7));

    await s.setPro(true);
    await s.setDifficulty(2);
    expect(s.difficulty, 2);
    await s.setTheme('midnight');
    expect(s.themeId, 'midnight');

    // Losing Pro clamps everything back.
    await s.setPro(false);
    expect(s.difficulty, isNot(2));
    expect(s.themeId, isNot('midnight'));
  });
}
