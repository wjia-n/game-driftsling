import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/garage_themes.dart';
import '../theme/toy_garage.dart';

/// PRO: custom theme creator — paint your own playroom. Live preview,
/// persisted per color.
class CustomThemeScreen extends StatefulWidget {
  final DriftAudio audio;
  final DriftSettings settings;

  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  DriftThemeDef get _t => DriftThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  // Curated playroom-friendly palette choices.
  static const List<Color> palette = [
    Color(0xFF4A2F1B), Color(0xFF6B4426), Color(0xFF2C1A0E),
    Color(0xFF54251A), Color(0xFF7A3A24), Color(0xFF331208),
    Color(0xFFB98A4E), Color(0xFFD2A867), Color(0xFF8F6335),
    Color(0xFF232A38), Color(0xFF35405A), Color(0xFF131824),
    Color(0xFF2E3B22), Color(0xFF4A5A34), Color(0xFF1A2312),
    Color(0xFFB8321F), Color(0xFFE8684A), Color(0xFF7A1F12),
    Color(0xFFD4A017), Color(0xFFF2D06B), Color(0xFF96702A),
    Color(0xFF2E7FB8), Color(0xFF7AC0E8), Color(0xFF1D5A86),
    Color(0xFFF7EEDC), Color(0xFFFFF8EA), Color(0xFF3A2A16),
    Color(0xFF3E6B3A), Color(0xFF274D33), Color(0xFF2E5A44),
    Color(0xFF5B5B60), Color(0xFF424248), Color(0xFF2E2E34),
    Color(0xFF6BA3A0), Color(0xFFE8762B), Color(0xFFE86AA0),
  ];

  static const rows = [
    ('Table dark', 'tableDark'),
    ('Table mid', 'tableMid'),
    ('Table deep', 'tableDeep'),
    ('Accent', 'accent'),
    ('Accent light', 'accentLight'),
    ('Accent dark', 'accentDark'),
    ('Text', 'ivory'),
    ('Infield', 'infield'),
    ('Road', 'road'),
    ('Road edge', 'roadEdge'),
    ('Center line', 'centerLine'),
  ];

  Future<void> _pick(String key, String label) async {
    final s = widget.settings;
    final current = Color(s.customColors[key]!);
    final chosen = await showDialog<Color>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [
              _t.tableMid,
              _t.tableDeep,
            ]),
            border: Border.all(color: _t.accent, width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pick $label', style: Garage.display(20, theme: _t)),
              const SizedBox(height: 14),
              SizedBox(
                width: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: palette.length,
                  itemBuilder: (_, i) {
                    final c = palette[i];
                    final selected = c.value == current.value;
                    return GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        Navigator.of(context).pop(c);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                            color: selected
                                ? _t.accentLight
                                : Colors.black.withValues(alpha: 0.4),
                            width: selected ? 3 : 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              GarageButton(
                label: 'Cancel',
                width: 160,
                fontSize: 15,
                theme: _t,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && mounted) {
      widget.audio.click();
      await s.setCustomColor(key, chosen.value);
      // Selecting a custom color auto-applies the custom theme.
      await s.setTheme('custom');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final preview = s.customTheme;
    return TableBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title:
              Text('Theme creator', style: Garage.display(22, theme: t)),
          centerTitle: true,
        ),
        body: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // Live preview: mini track.
                Container(
                  height: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: preview.tableDeep,
                    border: Border.all(color: preview.accent, width: 2),
                  ),
                  child: CustomPaint(
                    painter: _MiniTrackPainter(theme: preview),
                    child: Container(),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    widget.audio.click();
                    await s.resetCustomColors();
                    await s.setTheme('custom');
                    setState(() {});
                  },
                  child: Text('Reset to Playroom Classic',
                      style: Garage.label(13, theme: t)),
                ),
                const SizedBox(height: 4),
                for (final r in rows)
                  GarageRow(
                    theme: t,
                    label: r.$1,
                    control: GestureDetector(
                      onTap: () => _pick(r.$2, r.$1),
                      child: Container(
                        width: 44,
                        height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Color(s.customColors[r.$2]!),
                          border: Border.all(
                              color: t.accentLight, width: 2),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTrackPainter extends CustomPainter {
  final DriftThemeDef theme;
  _MiniTrackPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final rx = size.width * 0.36, ry = size.height * 0.3;
    final loop = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(cx, cy), width: rx * 2, height: ry * 2));
    canvas.drawPath(
        loop,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 30
          ..color = theme.roadEdge);
    canvas.drawPath(
        loop,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24
          ..color = theme.road);
    // Mini car.
    canvas.save();
    canvas.translate(cx + rx * 0.7, cy);
    canvas.rotate(0.5);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-16, -9, 32, 18),
            const Radius.circular(7)),
        Paint()..color = theme.accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MiniTrackPainter old) => false;
}
