import 'package:flutter/material.dart';

/// Theme, car-style and track-style catalogs for Drift Sling.
///
/// Art direction: the family playroom — a big wooden table, a painted toy
/// racetrack, and a die-cast metal toy car with real paint, rubber tires and
/// weight. Warm physical materials (wood, felt, chalk paint, metal flake).
/// No neon, no cyberpunk, no AI-dashboard looks.
class DriftThemeDef {
  final String id;
  final String name;
  final Color tableDark; // wood, dark
  final Color tableMid; // wood, mid
  final Color tableDeep; // wood, deepest / vignette
  final Color accent; // painted metal accent
  final Color accentLight;
  final Color accentDark;
  final Color ivory; // main light text
  final Color infield; // inside of the track (felt / playmat)
  final Color road; // track surface paint
  final Color roadEdge; // curb / edge paint
  final Color centerLine; // painted centerline color

  const DriftThemeDef({
    required this.id,
    required this.name,
    required this.tableDark,
    required this.tableMid,
    required this.tableDeep,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.ivory,
    required this.infield,
    required this.road,
    required this.roadEdge,
    required this.centerLine,
  });
}

class DriftThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'classic',
    'cherry',
    'sunny',
    'race',
  ];

  static const List<DriftThemeDef> all = [
    DriftThemeDef(
      id: 'classic',
      name: 'Playroom Classic',
      tableDark: Color(0xFF4A2F1B),
      tableMid: Color(0xFF6B4426),
      tableDeep: Color(0xFF2C1A0E),
      accent: Color(0xFFB8321F),
      accentLight: Color(0xFFE8684A),
      accentDark: Color(0xFF7A1F12),
      ivory: Color(0xFFF7EEDC),
      infield: Color(0xFF3E6B3A),
      road: Color(0xFF5B5B60),
      roadEdge: Color(0xFFF0E6CE),
      centerLine: Color(0xFFF5EFE0),
    ),
    DriftThemeDef(
      id: 'cherry',
      name: 'Cherry Workshop',
      tableDark: Color(0xFF54251A),
      tableMid: Color(0xFF7A3A24),
      tableDeep: Color(0xFF331208),
      accent: Color(0xFFD4A017),
      accentLight: Color(0xFFF2D06B),
      accentDark: Color(0xFF96702A),
      ivory: Color(0xFFF9F0DE),
      infield: Color(0xFF2E5A44),
      road: Color(0xFF4C4C52),
      roadEdge: Color(0xFFD4A017),
      centerLine: Color(0xFFF9F0DE),
    ),
    DriftThemeDef(
      id: 'sunny',
      name: 'Sunny Playdate',
      tableDark: Color(0xFFB98A4E),
      tableMid: Color(0xFFD2A867),
      tableDeep: Color(0xFF8F6335),
      accent: Color(0xFF2E7FB8),
      accentLight: Color(0xFF7AC0E8),
      accentDark: Color(0xFF1D5A86),
      ivory: Color(0xFF3A2A16),
      infield: Color(0xFF7CB46B),
      road: Color(0xFF6E6E75),
      roadEdge: Color(0xFFF7EEDC),
      centerLine: Color(0xFFFDF8EA),
    ),
    DriftThemeDef(
      id: 'race',
      name: 'Race Day Red',
      tableDark: Color(0xFF33231B),
      tableMid: Color(0xFF4C3526),
      tableDeep: Color(0xFF1E130D),
      accent: Color(0xFFD62828),
      accentLight: Color(0xFFF25C5C),
      accentDark: Color(0xFF931B1B),
      ivory: Color(0xFFF7EEDC),
      infield: Color(0xFF274D33),
      road: Color(0xFF424248),
      roadEdge: Color(0xFFD62828),
      centerLine: Color(0xFFF7EEDC),
    ),
    DriftThemeDef(
      id: 'midnight',
      name: 'Moonlight Garage',
      tableDark: Color(0xFF232A38),
      tableMid: Color(0xFF35405A),
      tableDeep: Color(0xFF131824),
      accent: Color(0xFF8FA3BF),
      accentLight: Color(0xFFCBD6E8),
      accentDark: Color(0xFF5A6B87),
      ivory: Color(0xFFF0EDE4),
      infield: Color(0xFF1F2B3A),
      road: Color(0xFF2E3644),
      roadEdge: Color(0xFFCBD6E8),
      centerLine: Color(0xFFF0EDE4),
    ),
    DriftThemeDef(
      id: 'denim',
      name: 'Denim Den',
      tableDark: Color(0xFF3E4A63),
      tableMid: Color(0xFF5A6A8C),
      tableDeep: Color(0xFF28303F),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF2EEE4),
      infield: Color(0xFF4E5F7E),
      road: Color(0xFF3A4458),
      roadEdge: Color(0xFFC9A227),
      centerLine: Color(0xFFF2EEE4),
    ),
    DriftThemeDef(
      id: 'forest',
      name: 'Forest Floor',
      tableDark: Color(0xFF2E3B22),
      tableMid: Color(0xFF4A5A34),
      tableDeep: Color(0xFF1A2312),
      accent: Color(0xFFC96A2B),
      accentLight: Color(0xFFF2A65E),
      accentDark: Color(0xFF8A451A),
      ivory: Color(0xFFF3EDDB),
      infield: Color(0xFF1E4D2E),
      road: Color(0xFF4A4438),
      roadEdge: Color(0xFFF3EDDB),
      centerLine: Color(0xFFF3EDDB),
    ),
    DriftThemeDef(
      id: 'desert',
      name: 'Desert Rally',
      tableDark: Color(0xFF8A6A3B),
      tableMid: Color(0xFFB08D54),
      tableDeep: Color(0xFF5E4626),
      accent: Color(0xFF9E3B1F),
      accentLight: Color(0xFFE8764F),
      accentDark: Color(0xFF6E2712),
      ivory: Color(0xFF3F2E14),
      infield: Color(0xFFD9B76A),
      road: Color(0xFF7A6A52),
      roadEdge: Color(0xFF9E3B1F),
      centerLine: Color(0xFFFDF3DC),
    ),
    DriftThemeDef(
      id: 'snow',
      name: 'Snow Day',
      tableDark: Color(0xFF7E93A8),
      tableMid: Color(0xFFA3B9CD),
      tableDeep: Color(0xFF55687C),
      accent: Color(0xFFB8321F),
      accentLight: Color(0xFFE8684A),
      accentDark: Color(0xFF7A1F12),
      ivory: Color(0xFF22303E),
      infield: Color(0xFFE8F0F7),
      road: Color(0xFF8B9BAE),
      roadEdge: Color(0xFFB8321F),
      centerLine: Color(0xFFFFFFFF),
    ),
    DriftThemeDef(
      id: 'carnival',
      name: 'Carnival',
      tableDark: Color(0xFF5A2E1E),
      tableMid: Color(0xFF7C4527),
      tableDeep: Color(0xFF381B10),
      accent: Color(0xFF2E8B8B),
      accentLight: Color(0xFF6FC2C2),
      accentDark: Color(0xFF1D5E5E),
      ivory: Color(0xFFF9F0DE),
      infield: Color(0xFFB8862B),
      road: Color(0xFF6B4A2E),
      roadEdge: Color(0xFF2E8B8B),
      centerLine: Color(0xFFF9F0DE),
    ),
    DriftThemeDef(
      id: 'library',
      name: 'Library Mahogany',
      tableDark: Color(0xFF3B1F14),
      tableMid: Color(0xFF5A2F1C),
      tableDeep: Color(0xFF241009),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      infield: Color(0xFF1E4D3B),
      road: Color(0xFF3E3428),
      roadEdge: Color(0xFFC9A227),
      centerLine: Color(0xFFF5EFE0),
    ),
    DriftThemeDef(
      id: 'pier',
      name: 'Seaside Pier',
      tableDark: Color(0xFF3E5E5A),
      tableMid: Color(0xFF5A8078),
      tableDeep: Color(0xFF27403C),
      accent: Color(0xFFD4A017),
      accentLight: Color(0xFFF2D06B),
      accentDark: Color(0xFF96702A),
      ivory: Color(0xFFF2F0E4),
      infield: Color(0xFF6BA3A0),
      road: Color(0xFF54685F),
      roadEdge: Color(0xFFF2F0E4),
      centerLine: Color(0xFFF2F0E4),
    ),
  ];

  static DriftThemeDef byId(String id, {DriftThemeDef? custom}) {
    if (id == 'custom' && custom != null) { return custom; }
    return all.firstWhere((t) => t.id == id, orElse: () => all.first);
  }

  static bool isProTheme(String id) =>
      !freeThemeIds.contains(id) && id != 'custom';
}

/// Die-cast car liveries. 0-2 = FREE, 3+ = PRO.
class CarStyles {
  static const names = [
    'Classic Red',
    'Ocean Blue',
    'Sunshine Yellow',
    'Forest Racer',
    'Pink Comet',
    'Checkered Champ',
    'Flame Rider',
    'Number Seven',
    'Purple Storm',
  ];
  static const descriptions = [
    'Cherry-red enamel, cream stripes',
    'Deep sea-blue flake, white stripe',
    'School-bus yellow, black chevrons',
    'Racing green, gold pinstripe',
    'Bubblegum pink, silver lightning',
    'Black & white checkerboard roof',
    'Midnight black, orange flames',
    'White body, big lucky 7 roundel',
    'Grape purple, teal swoosh',
  ];

  /// Body paint + stripe paint per style.
  static const bodies = [
    Color(0xFFC22E1E),
    Color(0xFF1E5FB8),
    Color(0xFFF2B01E),
    Color(0xFF1E6B3A),
    Color(0xFFE86AA0),
    Color(0xFF2E2E34),
    Color(0xFF1E1E24),
    Color(0xFFF2F0E4),
    Color(0xFF6B3FA0),
  ];
  static const stripes = [
    Color(0xFFF5EFE0),
    Color(0xFFF5EFE0),
    Color(0xFF2E2E34),
    Color(0xFFD4A017),
    Color(0xFFF5F0E4),
    Color(0xFFF5F0E4),
    Color(0xFFE8762B),
    Color(0xFFC22E1E),
    Color(0xFF3FC2B8),
  ];

  static const freeCount = 3;
  static bool isPro(int index) => index >= freeCount;
}

/// Track edge / line treatments. 0-2 = FREE, 3+ = PRO.
class TrackStyles {
  static const names = [
    'Painted Dashes',
    'Checkered Curbs',
    'Painter\'s Tape',
    'Chalk Lines',
    'Construction Zone',
    'Wooden Fence',
    'Flower Garden',
    'Cork Edge',
  ];
  static const descriptions = [
    'Classic white dashed centerline',
    'Black & white checkered edge blocks',
    'Blue painter\'s tape edges',
    'Chalk-drawn lines on the table',
    'Orange & white striped barriers',
    'Tiny wooden fence posts line the road',
    'Daisy borders around the infield',
    'Natural cork edging strips',
  ];

  static const freeCount = 3;
  static bool isPro(int index) => index >= freeCount;
}
