import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Moments" design language.
///
/// The interface itself is monochrome: ink (near-black / near-white) is the
/// primary color for text, buttons, switches and selection. Color is reserved
/// for meaning — each sound moment owns one tonal family that follows it
/// everywhere (its Home tile, its picker selection, its test ripple):
///
///   charge  (emerald) — plugging in / charging
///   release (coral)   — unplugging
///   full    (blue)    — battery full
///   guard   (violet)  — unplug alarm
///
/// Surfaces are tiered by role rather than one card style: big colored tiles
/// for the two main moments, segmented lists ([ZapGroup]) for secondary
/// options, an inverted ink card for Pro. No borders, shadows or gradients.
///
/// Type: Bricolage Grotesque for display (numbers, titles, sound names),
/// Manrope for body text. Read colors with `context.zap`.

/// One tonal color family: a soft container, readable content on it, and a
/// saturated tone for strokes and icons on neutral surfaces.
@immutable
class ZapHue {
  final Color container;
  final Color onContainer;
  final Color strong;
  const ZapHue(this.container, this.onContainer, this.strong);

  static ZapHue lerp(ZapHue a, ZapHue b, double t) => ZapHue(
        Color.lerp(a.container, b.container, t)!,
        Color.lerp(a.onContainer, b.onContainer, t)!,
        Color.lerp(a.strong, b.strong, t)!,
      );
}

@immutable
class ZapTokens extends ThemeExtension<ZapTokens> {
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color line;
  final Color ink;
  final Color inkMuted;

  /// Content on an [ink]-filled surface (primary buttons, Pro card).
  final Color onInk;
  final Color danger;
  final ZapHue charge;
  final ZapHue release;
  final ZapHue full;
  final ZapHue guard;

  const ZapTokens({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.onInk,
    required this.danger,
    required this.charge,
    required this.release,
    required this.full,
    required this.guard,
  });

  static const light = ZapTokens(
    bg: Color(0xFFF1F1F3),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE5E5EA),
    line: Color(0xFFDCDCE1),
    ink: Color(0xFF131316),
    inkMuted: Color(0xFF64646C),
    onInk: Color(0xFFFFFFFF),
    danger: Color(0xFFD92D3A),
    charge: ZapHue(Color(0xFFC6EFD6), Color(0xFF00391F), Color(0xFF14A05D)),
    release: ZapHue(Color(0xFFFFDCCB), Color(0xFF4F1500), Color(0xFFE8571A)),
    full: ZapHue(Color(0xFFD5E4FF), Color(0xFF00306B), Color(0xFF2C72E4)),
    guard: ZapHue(Color(0xFFE4DCFF), Color(0xFF26136B), Color(0xFF6A4CE0)),
  );

  static const dark = ZapTokens(
    bg: Color(0xFF0D0D0F),
    surface: Color(0xFF1A1A1D),
    surfaceHigh: Color(0xFF27272B),
    line: Color(0xFF2E2E33),
    ink: Color(0xFFF2F2F5),
    inkMuted: Color(0xFF9898A2),
    onInk: Color(0xFF0D0D0F),
    danger: Color(0xFFFF5E66),
    charge: ZapHue(Color(0xFF0F3A26), Color(0xFFA6F0C6), Color(0xFF3FD68A)),
    release: ZapHue(Color(0xFF4A2112), Color(0xFFFFBDA0), Color(0xFFFF8552)),
    full: ZapHue(Color(0xFF13305A), Color(0xFFB4D0FF), Color(0xFF6EA2FF)),
    guard: ZapHue(Color(0xFF2C2160), Color(0xFFCFC2FF), Color(0xFF9C85FF)),
  );

  @override
  ZapTokens copyWith() => this;

  @override
  ZapTokens lerp(ZapTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ZapTokens(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      line: l(line, other.line),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      onInk: l(onInk, other.onInk),
      danger: l(danger, other.danger),
      charge: ZapHue.lerp(charge, other.charge, t),
      release: ZapHue.lerp(release, other.release, t),
      full: ZapHue.lerp(full, other.full, t),
      guard: ZapHue.lerp(guard, other.guard, t),
    );
  }
}

extension ZapContext on BuildContext {
  ZapTokens get zap => Theme.of(this).extension<ZapTokens>() ?? ZapTokens.dark;
}

class ZapTheme {
  // Radii are tiered by hierarchy: tiles > groups > pads > inner corners.
  static const radiusTile = 28.0;
  static const radiusGroup = 24.0;
  static const radiusPad = 20.0;
  static const radiusInner = 6.0;
  static const radiusSm = 12.0;

  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space8 = 32.0;

  static const textXs = 12.5;
  static const textSm = 13.5;
  static const textMd = 15.5;

  static const tabular = [FontFeature.tabularFigures()];

  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 280);
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}

/// Display style (Bricolage Grotesque) for numbers, titles and sound names.
TextStyle zapDisplay(double size, {FontWeight weight = FontWeight.w700, Color? color, double? height}) =>
    GoogleFonts.bricolageGrotesque(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: size >= 28 ? -size * 0.03 : -0.2,
    );

/// Scales its child down slightly while pressed — tactile feedback for tiles
/// and pads. Taps on nested buttons still go to those buttons.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.pressedScale = 0.97});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Segmented list: each child sits on its own surface; the group's outer
/// corners are large, the joins between items small, separated by a 2 px gap.
class ZapGroup extends StatelessWidget {
  final List<Widget> children;

  /// Optional per-item background (null = surface). Same length as children.
  final List<Color?>? colors;

  const ZapGroup({super.key, required this.children, this.colors});

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    final n = children.length;
    const big = Radius.circular(ZapTheme.radiusGroup);
    const small = Radius.circular(ZapTheme.radiusInner);
    return Column(children: [
      for (var i = 0; i < n; i++) ...[
        if (i > 0) const SizedBox(height: 2),
        Material(
          color: colors?[i] ?? z.surface,
          clipBehavior: Clip.antiAlias,
          animationDuration: ZapTheme.medium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: i == 0 ? big : small,
              bottom: i == n - 1 ? big : small,
            ),
          ),
          child: children[i],
        ),
      ],
    ]);
  }
}

/// Row inside a [ZapGroup]. Leading is either a plain [icon] or, when [hue]
/// is given, the icon on a circle of that moment's color.
class ZapItem extends StatelessWidget {
  final IconData? icon;
  final ZapHue? hue;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;
  final bool chevron;
  final Color? titleColor;

  /// Inverts the hue circle (strong fill) — for rows sitting on their hue's
  /// container color, where the normal circle would disappear.
  final bool hueFilled;

  const ZapItem({
    super.key,
    this.icon,
    this.hue,
    required this.title,
    this.subtitle,
    this.trailing,
    this.below,
    this.onTap,
    this.chevron = false,
    this.titleColor,
    this.hueFilled = false,
  });

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    Widget? lead;
    if (icon != null) {
      lead = hue == null
          ? SizedBox(width: 28, child: Icon(icon, size: 22, color: z.inkMuted))
          : AnimatedContainer(
              duration: ZapTheme.medium,
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: hueFilled ? hue!.onContainer : hue!.container, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: hueFilled ? hue!.container : hue!.onContainer),
            );
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            ZapTheme.space5, hue != null ? 14 : 16, trailing is Switch ? 14 : ZapTheme.space4, hue != null ? 14 : 16),
        child: Column(children: [
          Row(children: [
            if (lead != null) ...[lead, const SizedBox(width: ZapTheme.space4)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(
                        fontSize: ZapTheme.textMd, fontWeight: FontWeight.w600, color: titleColor ?? z.ink)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: ZapTheme.fast,
                    layoutBuilder: (c, p) => Stack(alignment: Alignment.topLeft, children: [...p, if (c != null) c]),
                    child: Text(subtitle!,
                        key: ValueKey(subtitle),
                        style: TextStyle(fontSize: ZapTheme.textSm, color: z.inkMuted, height: 1.35)),
                  ),
                ],
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: ZapTheme.space3), trailing!],
            if (chevron) ...[
              const SizedBox(width: ZapTheme.space1),
              Icon(Icons.chevron_right_rounded, size: 22, color: z.inkMuted),
            ],
          ]),
          if (below != null) below!,
        ]),
      ),
    );
  }
}

/// A switch with a hairline separator before it — the Android "split" row:
/// the row body opens details, the switch toggles.
class SplitSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const SplitSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 1, height: 32, color: context.zap.line),
      const SizedBox(width: ZapTheme.space3),
      Switch(value: value, onChanged: onChanged),
    ]);
  }
}

class ZapSectionLabel extends StatelessWidget {
  final String text;
  const ZapSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(ZapTheme.space1, ZapTheme.space8, ZapTheme.space1, ZapTheme.space3),
      child: Text(text, style: zapDisplay(18, color: context.zap.ink)),
    );
  }
}

/// "Pro" marker for locked features.
class ProTag extends StatelessWidget {
  const ProTag({super.key});

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(color: z.ink, borderRadius: BorderRadius.circular(100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bolt_rounded, size: 13, color: z.onInk),
        const SizedBox(width: 2),
        Text('Pro', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: z.onInk, height: 1.1)),
      ]),
    );
  }
}

/// Full-width primary button: ink pill, optional spinner.
class ZapPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const ZapPrimaryButton({super.key, required this.label, this.onPressed, this.loading = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: z.ink,
          foregroundColor: z.onInk,
          disabledBackgroundColor: z.ink.withValues(alpha: 0.7),
          disabledForegroundColor: z.onInk,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: AnimatedSwitcher(
          duration: ZapTheme.fast,
          child: loading
              ? SizedBox(
                  key: const ValueKey('l'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: z.onInk),
                )
              : Row(key: ValueKey(label), mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                  Text(label),
                ]),
        ),
      ),
    );
  }
}

/// Pill segmented control with a sliding ink thumb.
class ZapSegmented extends StatelessWidget {
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;

  const ZapSegmented({super.key, required this.options, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: z.surfaceHigh, borderRadius: BorderRadius.circular(100)),
      child: LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth / options.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: ZapTheme.medium,
            curve: ZapTheme.emphasized,
            left: index * w,
            width: w,
            top: 0,
            bottom: 0,
            child: DecoratedBox(decoration: BoxDecoration(color: z.ink, borderRadius: BorderRadius.circular(100))),
          ),
          Row(children: [
            for (var i = 0; i < options.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: ZapTheme.fast,
                        style: TextStyle(
                          fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                          fontSize: ZapTheme.textSm,
                          fontWeight: FontWeight.w700,
                          color: i == index ? z.onInk : z.ink,
                        ),
                        child: Text(options[i]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// Shared-axis style route transition: incoming page fades in while sliding a
/// short distance from the right; the outgoing page drifts left.
class _ZapPageTransitionsBuilder extends PageTransitionsBuilder {
  const _ZapPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final inCurve = CurvedAnimation(parent: animation, curve: ZapTheme.emphasized, reverseCurve: Curves.easeInCubic);
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: ZapTheme.emphasized);
    return SlideTransition(
      position: Tween(begin: Offset.zero, end: const Offset(-0.06, 0)).animate(outCurve),
      child: SlideTransition(
        position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(inCurve),
        child: FadeTransition(
          opacity: Tween(begin: 0.0, end: 1.0)
              .animate(CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.7, curve: Curves.easeOut))),
          child: child,
        ),
      ),
    );
  }
}

class AppTheme {
  static ThemeData _build(Brightness brightness) {
    final z = brightness == Brightness.dark ? ZapTokens.dark : ZapTokens.light;
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final body = GoogleFonts.manropeTextTheme(base.textTheme).apply(bodyColor: z.ink, displayColor: z.ink);
    // Display roles (incl. large app-bar titles) use Bricolage Grotesque.
    final textTheme = body.copyWith(
      headlineLarge: zapDisplay(34, color: z.ink),
      headlineMedium: zapDisplay(32, color: z.ink),
      headlineSmall: zapDisplay(26, color: z.ink),
      titleLarge: zapDisplay(22, color: z.ink),
    );

    final scheme = ColorScheme(
      brightness: brightness,
      primary: z.ink,
      onPrimary: z.onInk,
      secondary: z.ink,
      onSecondary: z.onInk,
      error: z.danger,
      onError: Colors.white,
      surface: z.surface,
      onSurface: z.ink,
      onSurfaceVariant: z.inkMuted,
      surfaceContainerLowest: z.surface,
      surfaceContainerLow: z.surface,
      surfaceContainer: z.surface,
      surfaceContainerHigh: z.surface,
      surfaceContainerHighest: z.surfaceHigh,
      outline: z.line,
      outlineVariant: z.line,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: z.bg,
      canvasColor: z.bg,
      textTheme: textTheme,
      extensions: [z],
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: z.ink.withValues(alpha: 0.06),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _ZapPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: z.bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        foregroundColor: z.ink,
        systemOverlayStyle: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? z.onInk : z.inkMuted),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? z.ink : z.surfaceHigh),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.transparent : z.line),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: z.ink,
        inactiveTrackColor: z.surfaceHigh,
        thumbColor: z.ink,
        overlayColor: z.ink.withValues(alpha: 0.08),
        trackHeight: 6,
        // ignore: deprecated_member_use
        year2023: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: z.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZapTheme.radiusTile)),
        titleTextStyle: zapDisplay(22, color: z.ink),
        contentTextStyle: body.bodyMedium?.copyWith(color: z.inkMuted, height: 1.5, fontSize: 14.5),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: z.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: z.line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(ZapTheme.radiusTile)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: z.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZapTheme.radiusSm + 4)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: z.ink,
        contentTextStyle: body.bodyMedium?.copyWith(color: z.onInk, fontWeight: FontWeight.w600),
        actionTextColor: z.onInk,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZapTheme.radiusPad)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: z.ink,
          foregroundColor: z.onInk,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: z.ink,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: z.ink)),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: z.surface,
        dialHandColor: z.ink,
        dialBackgroundColor: z.surfaceHigh,
        hourMinuteColor: z.surfaceHigh,
        dayPeriodColor: z.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZapTheme.radiusTile)),
      ),
      dividerTheme: DividerThemeData(color: z.line, thickness: 1, space: 1),
      // ignore: deprecated_member_use
      progressIndicatorTheme: ProgressIndicatorThemeData(color: z.ink, year2023: false),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: z.ink,
        selectionHandleColor: z.ink,
        selectionColor: z.ink.withValues(alpha: 0.15),
      ),
    );
  }

  static final ThemeData darkTheme = _build(Brightness.dark);
  static final ThemeData lightTheme = _build(Brightness.light);
}
