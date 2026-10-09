import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/drift_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/garage_themes.dart';
import '../theme/toy_garage.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu — Toy Garage edition.
/// Logo, PLAY, mode / difficulty / circuit pickers, car & track style
/// pickers, renameable driver profile, tip jar, settings, share.
class MenuScreen extends StatefulWidget {
  final DriftAudio audio;
  final DriftSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();

  DriftSettings get _s => widget.settings;
  DriftThemeDef get _t =>
      DriftThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) { setState(() {}); }
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) { return; }
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Garage.body(15, theme: _t)),
        backgroundColor: _t.tableDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    super.dispose();
  }

  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {
      // Review UI unavailable on this device/build: stay silent, no fake UI.
    }
  }

  void _share() {
    widget.audio.click();
    Share.share(
      'Drift Sling — slingshot your toy car, drift the playroom table! 🏎️💨\n'
      'https://play.google.com/store/apps/details?id=com.gameswajiha.driftsling',
    );
  }

  void _play() {
    widget.audio.gameStart();
    final engine = DriftEngine(
      mode: DriftMode.values[DriftSettings.gameModes.indexOf(_s.mode)],
      circuit: _s.circuit,
      difficulty: _s.difficulty,
    );
    // App-scoped music: the game screen switches to the game track on entry;
    // we switch back to menu music on return.
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => GameScreen(
        engine: engine,
        audio: widget.audio,
        settings: _s,
      ),
    ))
        .then((_) {
      if (mounted) { widget.audio.startMenuMusic(); }
    });
  }

  void _openPro() {
    widget.audio.click();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: widget.audio,
        settings: _s,
        store: _store,
      ),
    ));
  }

  void _renameDriver() {
    final ctrl = TextEditingController(text: _s.playerName);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _t.tableMid,
            border: Border.all(color: _t.accent, width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Driver name', style: Garage.display(22, theme: _t)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 16,
                // Persist on EVERY keystroke (never only on keyboard-done);
                // the Save button below commits on focus loss/explicit tap.
                onChanged: (v) => _s.setPlayerName(v),
                style: Garage.body(18, theme: _t),
                decoration: InputDecoration(
                  hintText: 'Speedster',
                  hintStyle: Garage.body(16,
                      theme: _t,
                      color: _t.ivory.withValues(alpha: 0.4)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _t.accent, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _t.accentLight, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GarageButton(
                label: 'Save',
                theme: _t,
                width: 200,
                onTap: () {
                  widget.audio.click();
                  _s.setPlayerName(ctrl.text);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = _s;
    return TableBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Logo.
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/driftsling_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 14),
                  Text('Drift Sling', style: Garage.display(46, theme: t)),
                  Text('SLINGSHOT DRIFT RACING',
                      style: Garage.label(12, theme: t)),
                  const SizedBox(height: 6),
                  // Driver chip.
                  GestureDetector(
                    onTap: _renameDriver,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black.withValues(alpha: 0.3),
                        border: Border.all(
                            color: t.accent.withValues(alpha: 0.6)),
                      ),
                      child: Text('🏎️ ${s.playerName}  ✏️',
                          style: Garage.label(13, theme: t)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  GarageButton(
                      label: '▶  Race!', onTap: _play, theme: t, width: 260),
                  const SizedBox(height: 12),
                  // PRO banner.
                  GestureDetector(
                    onTap: _openPro,
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [
                          t.accent.withValues(alpha: 0.9),
                          t.accentDark,
                        ]),
                        border:
                            Border.all(color: t.accentLight, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        s.isPro ? '✦  PRO ACTIVE' : '✦  Get PRO',
                        style: Garage.label(17,
                            theme: t, color: t.ivory),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle('Race mode', t),
                  _ChipRow<String>(
                    theme: t,
                    options: DriftSettings.gameModes,
                    labels: DriftSettings.gameModeNames,
                    selected: s.mode,
                    onTap: (m) {
                      widget.audio.click();
                      s.setMode(m);
                    },
                  ),
                  Text(
                    s.mode == 'trial'
                        ? '2 laps, fastest time wins. Drift for bonus points!'
                        : s.mode == 'attack'
                            ? '75 seconds — drift and grab coins for the top score!'
                            : 'No clock, no pressure. Pure drifting joy.',
                    style: Garage.body(13,
                        theme: t,
                        color: t.ivory.withValues(alpha: 0.7)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle('Difficulty', t),
                  _ChipRow<int>(
                    theme: t,
                    options: const [0, 1, 2],
                    labels: const {
                      0: 'Sunday Cruise',
                      1: 'Track Racer',
                      2: 'Champion 🔒',
                    },
                    selected: s.difficulty,
                    onTap: (d) {
                      widget.audio.click();
                      if (d == 2 && !s.isPro) {
                        _openPro();
                        return;
                      }
                      s.setDifficulty(d);
                    },
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle('Circuit', t),
                  _ChipRow<int>(
                    theme: t,
                    options: const [0, 1, 2],
                    labels: const {
                      0: 'Sunny Speedway',
                      1: 'Wiggly Circuit',
                      2: 'Spaghetti Bowl',
                    },
                    selected: s.circuit,
                    onTap: (c) {
                      widget.audio.click();
                      s.setCircuit(c);
                    },
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle('Your car', t),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (int i = 0; i < CarStyles.names.length; i++)
                        _CarSwatch(
                          theme: t,
                          body: CarStyles.bodies[i],
                          stripe: CarStyles.stripes[i],
                          name: CarStyles.names[i],
                          locked: CarStyles.isPro(i) && !s.isPro,
                          selected: s.carStyle == i,
                          onTap: () {
                            widget.audio.click();
                            if (CarStyles.isPro(i) && !s.isPro) {
                              _openPro();
                              return;
                            }
                            s.setCarStyle(i);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle('Track style', t),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (int i = 0; i < TrackStyles.names.length; i++)
                        _MiniChip(
                          theme: t,
                          label:
                              '${TrackStyles.isPro(i) && !s.isPro ? '🔒 ' : ''}${TrackStyles.names[i]}',
                          selected: s.trackStyle == i,
                          onTap: () {
                            widget.audio.click();
                            if (TrackStyles.isPro(i) && !s.isPro) {
                              _openPro();
                              return;
                            }
                            s.setTrackStyle(i);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle('Playroom theme', t),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final th in DriftThemes.all)
                        GestureDetector(
                          onTap: () {
                            widget.audio.click();
                            if (DriftThemes.isProTheme(th.id) && !s.isPro) {
                              _openPro();
                              return;
                            }
                            s.setTheme(th.id);
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 76,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(colors: [
                                    th.tableMid,
                                    th.accent,
                                  ]),
                                  border: Border.all(
                                    color: s.themeId == th.id
                                        ? th.accentLight
                                        : th.accent.withValues(alpha: 0.3),
                                    width: s.themeId == th.id ? 3 : 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  th.name.split(' ').first,
                                  style: Garage.label(9, theme: th),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if (DriftThemes.isProTheme(th.id) && !s.isPro)
                                Container(
                                  width: 76,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.black
                                        .withValues(alpha: 0.55),
                                  ),
                                  child: Icon(Icons.lock,
                                      color: t.accentLight, size: 18),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      widget.audio.click();
                      if (!s.isPro) {
                        _openPro();
                        return;
                      }
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CustomThemeScreen(
                          audio: widget.audio,
                          settings: s,
                        ),
                      ));
                    },
                    child: Text(
                      s.isPro
                          ? '🎨  Open custom theme creator'
                          : '🎨  Custom theme creator (PRO)',
                      style: Garage.label(13, theme: t),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Best stats.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: t.tableDeep.withValues(alpha: 0.65),
                      border: Border.all(
                          color: t.accent.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Text('🏆  Garage records',
                            style: Garage.label(14, theme: t)),
                        const SizedBox(height: 6),
                        Text(
                          'Best score: ${s.bestScore}   •   Most coins: ${s.bestCoins} 🪙\n'
                          'Races: ${s.gamesPlayed}',
                          style: Garage.body(13, theme: t),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Bottom actions.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _IconAction(
                        theme: t,
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () {
                          widget.audio.click();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              audio: widget.audio,
                              settings: s,
                            ),
                          ));
                        },
                      ),
                      const SizedBox(width: 18),
                      _IconAction(
                        theme: t,
                        icon: Icons.share,
                        label: 'Share',
                        onTap: _share,
                      ),
                      const SizedBox(width: 18),
                      _IconAction(
                        theme: t,
                        icon: Icons.star_rate,
                        label: 'Rate',
                        onTap: _requestReview,
                      ),
                      const SizedBox(width: 18),
                      _IconAction(
                        theme: t,
                        icon: Icons.help_outline,
                        label: 'How to',
                        onTap: () {
                          widget.audio.click();
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: t.tableMid,
                                  border: Border.all(
                                      color: t.accent, width: 2.5),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('How to play',
                                        style:
                                            Garage.display(22, theme: t)),
                                    const SizedBox(height: 10),
                                    Text(
                                      '• Pull BACK on your car and release to slingshot-launch it.\n'
                                      '• While rolling, drag anywhere to steer.\n'
                                      '• Slide sideways at speed to DRIFT — chain drifts for big points!\n'
                                      '• Pass every checkered flag in order.\n'
                                      '• Time Trial: 2 laps, beat your best.\n'
                                      '• Drift Attack: 75 seconds, top score wins.\n'
                                      '• Grab coins 🪙 for bonus points.\n'
                                      '• Stalled? Just pull back on the car again!',
                                      style: Garage.body(14, theme: t),
                                    ),
                                    const SizedBox(height: 12),
                                    Center(
                                      child: GarageButton(
                                        label: 'Got it!',
                                        theme: t,
                                        width: 180,
                                        onTap: () {
                                          widget.audio.click();
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Tip jar preview.
                  Builder(builder: (_) {
                    final tips = [
                      _store.coffeeProduct,
                      _store.chocolateProduct,
                    ].whereType<ProductDetails>().toList();
                    if (!_store.storeReady || tips.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Wrap(
                      spacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final p in tips)
                          GestureDetector(
                            onTap: () {
                              widget.audio.click();
                              _store.buyTip(p);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color:
                                    Colors.black.withValues(alpha: 0.3),
                                border: Border.all(
                                    color: t.accent.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                p.id == StoreService.chocolateId
                                    ? '🍫 Tip ${p.price}'
                                    : '☕ Tip ${p.price}',
                                style: Garage.label(13, theme: t),
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _SectionTitle extends StatelessWidget {
  final String text;
  final DriftThemeDef theme;
  const _SectionTitle(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Garage.display(19, theme: theme)),
    );
  }
}

class _ChipRow<T> extends StatelessWidget {
  final DriftThemeDef theme;
  final List<T> options;
  final Map<T, String> labels;
  final T selected;
  final ValueChanged<T> onTap;
  const _ChipRow({
    required this.theme,
    required this.options,
    required this.labels,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final o in options)
          _MiniChip(
            theme: theme,
            label: labels[o] ?? '$o',
            selected: selected == o,
            onTap: () => onTap(o),
          ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final DriftThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MiniChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? theme.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.3),
          border: Border.all(
            color: selected
                ? theme.accentLight
                : theme.accent.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: Garage.label(13,
              theme: theme,
              color: selected ? theme.ivory : theme.ivory),
        ),
      ),
    );
  }
}

class _CarSwatch extends StatelessWidget {
  final DriftThemeDef theme;
  final Color body;
  final Color stripe;
  final String name;
  final bool locked;
  final bool selected;
  final VoidCallback onTap;
  const _CarSwatch({
    required this.theme,
    required this.body,
    required this.stripe,
    required this.name,
    required this.locked,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 92,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black.withValues(alpha: 0.3),
              border: Border.all(
                color: selected
                    ? theme.accentLight
                    : theme.accent.withValues(alpha: 0.4),
                width: selected ? 2.5 : 1.5,
              ),
            ),
            child: Column(
              children: [
                // Top-down mini car.
                SizedBox(
                  width: 44,
                  height: 26,
                  child: CustomPaint(
                    painter: _MiniCarPainter(body: body, stripe: stripe),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${locked ? '🔒 ' : ''}$name',
                  style: Garage.label(9, theme: theme),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (locked)
            Container(
              width: 92,
              height: 78,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.45),
              ),
              child: Icon(Icons.lock,
                  color: theme.accentLight, size: 20),
            ),
        ],
      ),
    );
  }
}

class _MiniCarPainter extends CustomPainter {
  final Color body;
  final Color stripe;
  _MiniCarPainter({required this.body, required this.stripe});

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(7));
    canvas.drawRRect(r, Paint()..color = body);
    canvas.drawRect(
        Rect.fromLTWH(0, size.height / 2 - 2.5, size.width, 5),
        Paint()..color = stripe);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.42, 5, size.width * 0.26,
                size.height - 10),
            const Radius.circular(3)),
        Paint()..color = const Color(0xFFBFD9E8));
  }

  @override
  bool shouldRepaint(covariant _MiniCarPainter old) => false;
}

class _IconAction extends StatelessWidget {
  final DriftThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _IconAction({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.tableMid, theme.tableDeep],
              ),
              border: Border.all(color: theme.accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: theme.accentLight, size: 26),
          ),
          const SizedBox(height: 4),
          Text(label, style: Garage.label(11, theme: theme)),
        ],
      ),
    );
  }
}
