import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/garage_themes.dart';
import '../theme/toy_garage.dart';
import 'pro_screen.dart';

/// Settings — Toy Garage edition, theme-aware.
class SettingsScreen extends StatefulWidget {
  final DriftAudio audio;
  final DriftSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StoreService _store = StoreService();

  DriftThemeDef get _t =>
      DriftThemes.byId(widget.settings.themeId, custom: widget.settings.customTheme);

  @override
  void initState() {
    super.initState();
    _store.init().then((_) {
      if (mounted) { setState(() {}); }
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) { return; }
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
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final audio = widget.audio;
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
              audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: Garage.display(22, theme: t)),
          centerTitle: true,
        ),
        body: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Sound', t),
                GarageRow(
                  theme: t,
                  label: 'Music',
                  control: GarageToggle(
                    theme: t,
                    value: s.musicOn,
                    onChanged: (v) async {
                      audio.click();
                      await s.setMusic(v);
                      audio.configure(
                          musicOn: s.musicOn,
                          sfxOn: s.sfxOn,
                          volume: s.volume);
                      if (v) {
                        audio.startMenuMusic();
                      } else {
                        audio.stopMusic();
                      }
                    },
                  ),
                ),
                GarageRow(
                  theme: t,
                  label: 'Sound effects',
                  control: GarageToggle(
                    theme: t,
                    value: s.sfxOn,
                    onChanged: (v) async {
                      await s.setSfx(v);
                      audio.configure(
                          musicOn: s.musicOn,
                          sfxOn: s.sfxOn,
                          volume: s.volume);
                      if (v) { audio.click(); }
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Text('Volume', style: Garage.body(16, theme: t)),
                PaintedSlider(
                  theme: t,
                  value: s.volume,
                  onChanged: (v) async {
                    await s.setVolume(v);
                    audio.configure(
                        musicOn: s.musicOn,
                        sfxOn: s.sfxOn,
                        volume: s.volume);
                  },
                ),
                const SizedBox(height: 10),
                _SectionTitle('Drift Sling PRO', t),
                GarageRow(
                  theme: t,
                  label: s.isPro ? 'PRO active ✦' : 'Unlock PRO',
                  control: GestureDetector(
                    onTap: () {
                      audio.click();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProScreen(
                          audio: audio,
                          settings: s,
                          store: _store,
                        ),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: s.isPro
                            ? t.accent.withValues(alpha: 0.85)
                            : Colors.black.withValues(alpha: 0.3),
                        border: Border.all(
                            color: t.accentLight, width: 2),
                      ),
                      child: Text(
                        s.isPro ? '✦ PRO' : 'View',
                        style: Garage.label(13,
                            theme: t,
                            color: s.isPro ? t.tableDeep : t.ivory),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _SectionTitle('Driver', t),
                GarageRow(
                  theme: t,
                  label: 'Driver name',
                  control: GestureDetector(
                    onTap: () {
                      audio.click();
                      final ctrl =
                          TextEditingController(text: s.playerName);
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
                              children: [
                                Text('Driver name',
                                    style: Garage.display(22, theme: t)),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: ctrl,
                                  autofocus: true,
                                  maxLength: 16,
                                  // Persist on EVERY keystroke (never only on
                                  // keyboard-done); Save commits on tap.
                                  onChanged: (v) => s.setPlayerName(v),
                                  style: Garage.body(18, theme: t),
                                  decoration: InputDecoration(
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: t.accent, width: 2),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: t.accentLight, width: 2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GarageButton(
                                  label: 'Save',
                                  theme: t,
                                  width: 200,
                                  onTap: () {
                                    audio.click();
                                    s.setPlayerName(ctrl.text);
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    child: Text('${s.playerName}  ✏️',
                        style: Garage.label(14, theme: t)),
                  ),
                ),
                const SizedBox(height: 10),
                _SectionTitle('Appearance', t),
                GarageRow(
                  theme: t,
                  label: 'Theme',
                  control: Text(
                    DriftThemes.byId(s.themeId, custom: s.customTheme).name,
                    style: Garage.label(14, theme: t),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final th in DriftThemes.all)
                      GestureDetector(
                        onTap: () async {
                          audio.click();
                          final locked = DriftThemes.isProTheme(th.id) &&
                              !s.isPro;
                          if (locked) {
                            await Navigator.of(context)
                                .push(MaterialPageRoute(
                              builder: (_) => ProScreen(
                                audio: audio,
                                settings: s,
                                store: _store,
                              ),
                            ));
                            return;
                          }
                          await s.setTheme(th.id);
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 44,
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
                                style: Garage.label(8, theme: th),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (DriftThemes.isProTheme(th.id) &&
                                !s.isPro)
                              Container(
                                width: 64,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(8),
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
                const SizedBox(height: 12),
                Text('Car paint', style: Garage.body(16, theme: t)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0; i < CarStyles.names.length; i++)
                      _MiniChip(
                        theme: t,
                        label:
                            '${CarStyles.isPro(i) && !s.isPro ? '🔒 ' : ''}${CarStyles.names[i]}',
                        selected: s.carStyle == i,
                        onTap: () async {
                          audio.click();
                          if (CarStyles.isPro(i) && !s.isPro) {
                            await Navigator.of(context)
                                .push(MaterialPageRoute(
                              builder: (_) => ProScreen(
                                audio: audio,
                                settings: s,
                                store: _store,
                              ),
                            ));
                            return;
                          }
                          await s.setCarStyle(i);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Track style', style: Garage.body(16, theme: t)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0; i < TrackStyles.names.length; i++)
                      _MiniChip(
                        theme: t,
                        label:
                            '${TrackStyles.isPro(i) && !s.isPro ? '🔒 ' : ''}${TrackStyles.names[i]}',
                        selected: s.trackStyle == i,
                        onTap: () async {
                          audio.click();
                          if (TrackStyles.isPro(i) && !s.isPro) {
                            await Navigator.of(context)
                                .push(MaterialPageRoute(
                              builder: (_) => ProScreen(
                                audio: audio,
                                settings: s,
                                store: _store,
                              ),
                            ));
                            return;
                          }
                          await s.setTrackStyle(i);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _SectionTitle('Support', t),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: t.tableDeep.withValues(alpha: 0.65),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Drift Sling is 100% free. Tips keep the garage open!',
                        style: Garage.body(14, theme: t),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Builder(builder: (_) {
                        final tips = [
                          _store.coffeeProduct,
                          _store.chocolateProduct,
                        ].whereType<ProductDetails>().toList();
                        if (!_store.storeReady) {
                          return Text(
                            _store.error ?? 'Loading…',
                            style: Garage.body(13,
                                theme: t,
                                color:
                                    t.ivory.withValues(alpha: 0.6)),
                            textAlign: TextAlign.center,
                          );
                        }
                        if (tips.isEmpty) {
                          return Text('Tips coming soon.',
                              style: Garage.body(13,
                                  theme: t,
                                  color: t.ivory
                                      .withValues(alpha: 0.6)));
                        }
                        return Wrap(
                          spacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final p in tips)
                              _MiniChip(
                                theme: t,
                                label: p.id == StoreService.chocolateId
                                    ? '🍫 ${p.price}'
                                    : '☕ ${p.price}',
                                selected: false,
                                onTap: () {
                                  audio.click();
                                  _store.buyTip(p);
                                },
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _SectionTitle('About', t),
                Text(
                  'Drift Sling — Toy Garage edition.\nVersion 2.0.0 • Made with ♥ by WAJIHA',
                  style: Garage.body(13,
                      theme: t,
                      color: t.ivory.withValues(alpha: 0.65)),
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

class _SectionTitle extends StatelessWidget {
  final String text;
  final DriftThemeDef theme;
  const _SectionTitle(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(text, style: Garage.display(19, theme: theme)),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final DriftThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MiniChip(
      {required this.theme,
      required this.label,
      required this.selected,
      required this.onTap});

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
