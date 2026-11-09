import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/audio_service.dart';
import 'services/battery_service.dart';
import 'services/purchase_service.dart';
import 'services/preferences_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

const _chargerChannel = MethodChannel('com.zapsound.app/charger');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await PurchaseService.init();
  unawaited(PurchaseService.syncWithStore());
  final themeMode = parseThemeMode(await PrefsService.getThemeMode());
  final isOnboarded = await PrefsService.isOnboarded();

  // Foreground backup: native side notifies us of charger state changes
  // so the sound can be played via just_audio directly.
  _chargerChannel.setMethodCallHandler((call) async {
    BatteryService.chargerEvents.value++;
    if (!await PrefsService.isEnabled()) return;
    if (await PrefsService.isQuietNow()) return;
    switch (call.method) {
      case 'onChargerConnected':
        await AudioService.onPlugIn();
        break;
      case 'onChargerDisconnected':
        // When anti-theft is armed the native siren handles this event.
        if (await PrefsService.isAntitheftArmed()) return;
        await AudioService.onPlugOut();
        break;
    }
  });

  runApp(ZapSoundApp(themeMode: themeMode, isOnboarded: isOnboarded));
}

ThemeMode parseThemeMode(String v) => switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

class ZapSoundApp extends StatefulWidget {
  final ThemeMode themeMode;
  final bool isOnboarded;
  const ZapSoundApp({super.key, required this.themeMode, required this.isOnboarded});

  static _ZapSoundAppState? of(BuildContext ctx) =>
      ctx.findAncestorStateOfType<_ZapSoundAppState>();

  @override
  State<ZapSoundApp> createState() => _ZapSoundAppState();
}

class _ZapSoundAppState extends State<ZapSoundApp> {
  late final ValueNotifier<ThemeMode> _themeNotifier;
  late bool _isOnboarded;

  @override
  void initState() {
    super.initState();
    _themeNotifier = ValueNotifier(widget.themeMode);
    _isOnboarded = widget.isOnboarded;
  }

  void setThemeMode(ThemeMode m) => _themeNotifier.value = m;

  @override
  void dispose() {
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'ZapSound',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        home: _isOnboarded ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }
}
