import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZapColors {
  static const primary      = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFF9D97FF);
  static const accent       = Color(0xFFFFD60A);
  static const bgDark       = Color(0xFF0F0E17);
  static const surfaceDark  = Color(0xFF1A1926);
  static const surfaceDark2 = Color(0xFF252338);
  static const bgLight      = Color(0xFFF5F4FF);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textSecondary= Color(0xFF9B9AB0);
  static const success      = Color(0xFF2DD4A7);
  static const gold         = Color(0xFFFFB300);
  static const goldLight    = Color(0xFFFFD60A);
}

class ZapTheme {
  static const radiusSm   = 8.0;
  static const radiusMd   = 12.0;
  static const radiusLg   = 16.0;
  static const radiusXl   = 24.0;
  static const radiusFull = 100.0;
  static const space2  = 8.0;
  static const space3  = 12.0;
  static const space4  = 16.0;
  static const space5  = 20.0;
  static const space6  = 24.0;
  static const space8  = 32.0;
  static const space10 = 40.0;
  static const textXs  = 11.0;
  static const textSm  = 13.0;
  static const textMd  = 15.0;
  static const textLg  = 17.0;
  static const textXl  = 20.0;
  static const text2xl = 24.0;
}

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: ZapColors.primary, brightness: Brightness.dark).copyWith(
      background: ZapColors.bgDark,
      surface: ZapColors.surfaceDark,
      primary: ZapColors.primary,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    scaffoldBackgroundColor: ZapColors.bgDark,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZapTheme.radiusLg)),
      color: ZapColors.surfaceDark,
    ),
    appBarTheme: const AppBarTheme(backgroundColor: ZapColors.bgDark, elevation: 0, centerTitle: true),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: ZapColors.primary, brightness: Brightness.light),
    textTheme: GoogleFonts.poppinsTextTheme(),
    scaffoldBackgroundColor: ZapColors.bgLight,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZapTheme.radiusLg)),
      color: ZapColors.surfaceLight,
    ),
    appBarTheme: const AppBarTheme(backgroundColor: ZapColors.bgLight, elevation: 0, centerTitle: true),
  );
}
