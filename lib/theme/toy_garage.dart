import 'package:flutter/material.dart';
import 'garage_themes.dart';

/// Toy Garage — the design system for Drift Sling.
/// Playroom-table warmth: real wood, painted track lines, die-cast metal,
/// felt and chalk. Chunky, pressable, readable. No neon, no cyberpunk.
class Garage {
  static TextStyle display(double size, {Color? color, DriftThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        color: color ?? theme?.accentLight ?? const Color(0xFFE8684A),
        letterSpacing: 0.8,
        shadows: const [
          Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4),
        ],
      );

  static TextStyle body(double size, {Color? color, DriftThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme?.ivory ?? const Color(0xFFF7EEDC),
        height: 1.35,
      );

  static TextStyle label(double size, {Color? color, DriftThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? theme?.accentLight ?? const Color(0xFFE8684A),
        letterSpacing: 0.8,
      );

  static ThemeData theme([DriftThemeDef? t]) {
    t ??= DriftThemes.byId('classic');
    final lightIvory = t.id == 'sunny' || t.id == 'desert' || t.id == 'snow';
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.tableDark,
      colorScheme: ColorScheme(
        brightness: lightIvory ? Brightness.light : Brightness.dark,
        primary: t.accent,
        onPrimary: t.ivory,
        secondary: t.accentLight,
        onSecondary: t.tableDeep,
        surface: t.tableMid,
        onSurface: t.ivory,
        error: t.accent,
        onError: t.ivory,
      ),
      textTheme: TextTheme(
        displayLarge: display(34, theme: t),
        displayMedium: display(26, theme: t),
        titleLarge: display(22, theme: t),
        bodyLarge: body(16, theme: t),
        bodyMedium: body(14, theme: t),
        labelLarge: label(14, theme: t),
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.tableMid),
    );
  }
}

/// Wooden playroom-table background with grain and a warm vignette.
class TableBackdrop extends StatelessWidget {
  final Widget child;
  final DriftThemeDef? theme;
  const TableBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? DriftThemes.byId('classic');
    return Container(
      decoration: BoxDecoration(color: t.tableDark),
      child: CustomPaint(
        painter: _TableGrainPainter(t),
        child: child,
      ),
    );
  }
}

class _TableGrainPainter extends CustomPainter {
  final DriftThemeDef t;
  _TableGrainPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final vignette = RadialGradient(
      center: const Alignment(0, -0.25),
      radius: 1.15,
      colors: [
        t.tableMid.withValues(alpha: 0.5),
        t.tableDark.withValues(alpha: 0.0),
        Colors.black.withValues(alpha: 0.45),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = vignette.createShader(Offset.zero & size),
    );
    final grain = Paint()
      ..color = t.tableDeep.withValues(alpha: 0.18)
      ..strokeWidth = 2.5;
    for (int i = 0; i < 12; i++) {
      final y = size.height * (i + 0.5) / 12;
      final wobble = (i % 3 - 1) * 10.0;
      canvas.drawLine(
        Offset(0, y + wobble),
        Offset(size.width, y - wobble),
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A chunky die-cast style button with painted trim — looks pressable.
class GarageButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double width;
  final double fontSize;
  final DriftThemeDef? theme;

  const GarageButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 240,
    this.fontSize = 19,
    this.theme,
  });

  @override
  State<GarageButton> createState() => _GarageButtonState();
}

class _GarageButtonState extends State<GarageButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? DriftThemes.byId('classic');
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 15),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? [t.accentLight, t.accent, t.accentDark]
                : [
                    t.tableDeep.withValues(alpha: 0.7),
                    t.tableDeep.withValues(alpha: 0.5)
                  ],
          ),
          border: Border.all(
              color: enabled ? t.ivory.withValues(alpha: 0.7) : t.tableDeep,
              width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: _pressed ? 0.05 : 0.25),
              offset: const Offset(0, -2),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              offset: Offset(0, _pressed ? 2 : 6),
              blurRadius: _pressed ? 4 : 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: Garage.display(widget.fontSize,
              theme: t,
              color: enabled
                  ? t.ivory
                  : t.ivory.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}

/// A painted wooden plaque for titles.
class GaragePlaque extends StatelessWidget {
  final String title;
  final String? subtitle;
  final DriftThemeDef? theme;
  const GaragePlaque({super.key, required this.title, this.subtitle, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? DriftThemes.byId('classic');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.tableDeep, t.tableDark],
        ),
        border: Border.all(color: t.accent, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              offset: const Offset(0, 6),
              blurRadius: 12),
          BoxShadow(
              color: t.accentLight.withValues(alpha: 0.6),
              offset: const Offset(0, -1),
              blurRadius: 1),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: Garage.display(30, theme: t),
              textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: Garage.body(14,
                    theme: t, color: t.ivory.withValues(alpha: 0.75)),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// A chunky lever toggle for settings.
class GarageToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final DriftThemeDef? theme;
  const GarageToggle(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? DriftThemes.byId('classic');
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 64,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: value ? t.accentDark : t.tableDeep,
          border: Border.all(color: t.accent, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 3),
                blurRadius: 5),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.accentLight, t.accent, t.accentDark],
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A painted-wood volume slider on a metal rail.
class PaintedSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final DriftThemeDef? theme;
  const PaintedSlider(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? DriftThemes.byId('classic');
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: t.accent,
        inactiveTrackColor: t.tableDeep,
        thumbShape: _PaintedThumb(t),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

class _PaintedThumb extends SliderComponentShape {
  final DriftThemeDef t;
  const _PaintedThumb(this.t);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(26, 26);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    canvas.drawCircle(
        center + const Offset(0, 2),
        12,
        Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawCircle(
        center,
        11,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            radius: 1.0,
            colors: [t.accentLight, t.accent, t.accentDark],
          ).createShader(Rect.fromCircle(center: center, radius: 11)));
  }
}

/// Small helper: a labeled settings row.
class GarageRow extends StatelessWidget {
  final String label;
  final Widget control;
  final DriftThemeDef? theme;
  const GarageRow(
      {super.key, required this.label, required this.control, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? DriftThemes.byId('classic');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: t.tableDeep.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: t.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Garage.body(16, theme: t))),
          control,
        ],
      ),
    );
  }
}
