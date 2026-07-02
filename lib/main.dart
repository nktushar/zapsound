import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/audio_service.dart';
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
  unawaited(PurchaseService.restoreSilently());
  final isDark = await PrefsService.isDarkMode();
  final isOnboarded = await PrefsService.isOnboarded();

  // Foreground backup: native side notifies us of charger state changes
  // so the sound can be played via just_audio directly.
  _chargerChannel.setMethodCallHandler((call) async {
    if (!await PrefsService.isEnabled()) return;
    switch (call.method) {
      case 'onChargerConnected':
        await AudioService.onPlugIn();
        break;
      case 'onChargerDisconnected':
        await AudioService.onPlugOut();
        break;
    }
  });

  runApp(ZapSoundApp(isDark: isDark, isOnboarded: isOnboarded));
}

class ZapSoundApp extends StatefulWidget {
  final bool isDark;
  final bool isOnboarded;
  const ZapSoundApp({super.key, required this.isDark, required this.isOnboarded});

  static _ZapSoundAppState? of(BuildContext ctx) =>
      ctx.findAncestorStateOfType<_ZapSoundAppState>();

  @override
  State<ZapSoundApp> createState() => _ZapSoundAppState();
}

class _ZapSoundAppState extends State<ZapSoundApp> {
  late final ValueNotifier<bool> _themeNotifier;
  late bool _isOnboarded;

  @override
  void initState() {
    super.initState();
    _themeNotifier = ValueNotifier(widget.isDark);
    _isOnboarded = widget.isOnboarded;
  }

  void setDark(bool v) => _themeNotifier.value = v;

  @override
  void dispose() {
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _themeNotifier,
      builder: (_, isDark, __) => MaterialApp(
        title: 'ZapSound',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        home: _isOnboarded ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }
}
