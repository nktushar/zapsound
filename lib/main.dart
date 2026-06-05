import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/purchase_service.dart';
import 'services/preferences_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await PurchaseService.init();
  final isDark = await PrefsService.isDarkMode();
  runApp(ZapSoundApp(isDark: isDark));
}

class ZapSoundApp extends StatefulWidget {
  final bool isDark;
  const ZapSoundApp({super.key, required this.isDark});

  static _ZapSoundAppState? of(BuildContext ctx) =>
      ctx.findAncestorStateOfType<_ZapSoundAppState>();

  @override
  State<ZapSoundApp> createState() => _ZapSoundAppState();
}

class _ZapSoundAppState extends State<ZapSoundApp> {
  late bool _isDark;

  @override
  void initState() { super.initState(); _isDark = widget.isDark; }

  void setDark(bool v) => setState(() => _isDark = v);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZapSound',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
