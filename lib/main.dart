import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/garage_themes.dart';
import 'theme/toy_garage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = DriftSettings();
  await settings.load();
  final audio = DriftAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(DriftSlingApp(settings: settings, audio: audio));
}

class DriftSlingApp extends StatefulWidget {
  final DriftSettings settings;
  final DriftAudio audio;
  const DriftSlingApp({super.key, required this.settings, required this.audio});

  @override
  State<DriftSlingApp> createState() => _DriftSlingAppState();
}

class _DriftSlingAppState extends State<DriftSlingApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; game screens additionally freeze their engines.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => MaterialApp(
        title: 'Drift Sling',
        debugShowCheckedModeBanner: false,
        theme: Garage.theme(DriftThemes.byId(widget.settings.themeId,
            custom: widget.settings.customTheme)),
        home: SplashScreen(audio: widget.audio, settings: widget.settings),
      ),
    );
  }
}
