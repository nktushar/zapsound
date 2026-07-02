import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Electric Glass" design language: dark-first, OLED near-black background,
/// electric violet → cyan brand gradient, translucent glass surfaces.
class ZapColors {
  static const primary      = Color(0xFF7C5CFF); // electric violet
  static const primaryLight = Color(0xFFA48CFF);
  static const cyan         = Color(0xFF4CC9FF); // gradient end
  static const accent       = Color(0xFFFFD60A);
  static const bgDark       = Color(0xFF050508); // OLED near-black
  static const surfaceDark  = Color(0xFF12121C);
  static const surfaceDark2 = Color(0xFF1C1C2A);
  static const bgLight      = Color(0xFFF4F3FB);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textSecondary= Color(0xFF9B9AB0);
  static const success      = Color(0xFF2DD4A7);
  static const gold         = Color(0xFFFFB300);
  static const goldLight    = Color(0xFFFFD60A);
}

class ZapGradients {
  /// Primary brand gradient (analogous violet → cyan).
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ZapColors.primary, ZapColors.cyan],
  );

  /// Hero / paywall backdrop: deep violet through brand colors.
  static const premium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1B7A), Color(0xFF5A42E0), Color(0xFF7C5CFF), Color(0xFF4CC9FF)],
  );

  static const gold = LinearGradient(
    colors: [ZapColors.gold, ZapColors.goldLight],
  );
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

/// Frosted translucent card used across screens. In dark mode a white-tinted
/// glass over the near-black background; in light mode a soft white card.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final VoidCallback? onTap;
  final Gradient? borderGradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = ZapTheme.radiusLg,
    this.onTap,
    this.borderGradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.10) : ZapColors.primary.withValues(alpha: 0.12),
            ),
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Soft violet/cyan radial glows placed behind screen content (OLED-friendly).
class AuraBackground extends StatelessWidget {
  const AuraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? 0.16 : 0.10;
    return IgnorePointer(
      child: Stack(children: [
        Positioned(
          top: -120, left: -100,
          child: _blob(ZapColors.primary.withValues(alpha: base), 340),
        ),
        Positioned(
          bottom: -140, right: -120,
          child: _blob(ZapColors.cyan.withValues(alpha: base * 0.8), 380),
        ),
      ]),
    );
  }

  Widget _blob(Color color, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: ZapColors.primary, brightness: Brightness.dark).copyWith(
      surface: ZapColors.surfaceDark,
      primary: ZapColors.primary,
      secondary: ZapColors.cyan,
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
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
    colorScheme: ColorScheme.fromSeed(seedColor: ZapColors.primary, brightness: Brightness.light).copyWith(
      secondary: ZapColors.cyan,
    ),
    textTheme: GoogleFonts.outfitTextTheme(),
    scaffoldBackgroundColor: ZapColors.bgLight,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZapTheme.radiusLg)),
      color: ZapColors.surfaceLight,
    ),
    appBarTheme: const AppBarTheme(backgroundColor: ZapColors.bgLight, elevation: 0, centerTitle: true),
  );
}
