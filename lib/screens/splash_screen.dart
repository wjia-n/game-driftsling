import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/garage_themes.dart';
import '../theme/toy_garage.dart';
import 'menu_screen.dart';

/// Launch splash — a SINGLE splash screen with two moments:
/// 1. the WAJIHA company moment (official logo, unaltered), then
/// 2. the game splash: logo + name + animated loading line + credits.
class SplashScreen extends StatefulWidget {
  final DriftAudio audio;
  final DriftSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _company = true;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) { return; }
    setState(() {
      _company = false;
    });
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) { return; }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DriftThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: _company ? Colors.black : theme.tableDeep,
      body: _company ? _companyMoment() : _gameMoment(theme),
    );
  }

  /// The company moment: the official WAJIHA logo, full-screen, unaltered.
  Widget _companyMoment() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        builder: (_, v, _) => Opacity(
          opacity: v,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/wajiha_logo.png',
                width: 170,
                height: 170,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              Text(
                'WAJIHA',
                style: Garage.label(26, theme: DriftThemes.byId('classic')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The game moment: logo + name + animated loading line + credits.
  Widget _gameMoment(DriftThemeDef theme) {
    return TableBackdrop(
      theme: theme,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.accent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    offset: const Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/driftsling_logo.png',
                  fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text('Drift Sling', style: Garage.display(52, theme: theme)),
            const SizedBox(height: 6),
            Text(
              'SLINGSHOT DRIFT RACING',
              style: Garage.label(13, theme: theme),
            ),
            const SizedBox(height: 30),
            // Animated loading line.
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: _loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                            color: theme.accent.withValues(alpha: 0.5)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            _loader.value.clamp(0.02, 1.0).toDouble(),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [
                                theme.accentLight,
                                theme.accent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _loader.value < 1
                          ? 'Warming up the engine…'
                          : 'Ready!',
                      style: Garage.body(13,
                          theme: theme,
                          color: theme.ivory.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: Garage.label(14, theme: theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
