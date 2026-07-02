import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../services/preferences_service.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDark = true, _isPremium = false;
  String _version = '...';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final dark = await PrefsService.isDarkMode();
    final prem = await PrefsService.isPremium();
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() { _isDark = dark; _isPremium = prem; _version = info.version; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.all(ZapTheme.space4), children: [

        if (_isPremium)
          _PremiumBadge().animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, curve: Curves.easeOut),

        const SizedBox(height: ZapTheme.space4),

        _Section('Appearance', [
          SwitchListTile(
            secondary: _IconCircle(Icons.dark_mode_outlined),
            title: const Text('Dark mode', style: TextStyle(fontSize: ZapTheme.textMd)),
            value: _isDark,
            activeColor: ZapColors.primary,
            onChanged: (v) async {
              setState(() => _isDark = v);
              await PrefsService.setDarkMode(v);
              ZapSoundApp.of(context)?.setDark(v);
            },
          ),
        ], delay: 0),

        const SizedBox(height: ZapTheme.space4),

        _Section('Background & Reliability', [
          _Tile(Icons.battery_charging_full_rounded, 'Allow background activity',
              'Required so charger sounds play when ZapSound is closed', () async {
            const channel = MethodChannel('com.zapsound.app/charger');
            await channel.invokeMethod('requestBatteryOptimizationExemption');
          }),
          _Tile(Icons.smartphone_rounded, 'Some phones need extra setup',
              'Tap for Xiaomi / Oppo / Vivo / Samsung instructions', () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Extra setup for some phones'),
                content: const Text(
                  'On Xiaomi (MIUI), Oppo (ColorOS), Vivo (FuntouchOS) and some '
                  'Samsung phones, Android\'s standard battery settings are not '
                  'enough. Also open:\n\n'
                  '• Settings → Apps → ZapSound → Battery → "No restrictions" / '
                  '"Allow background activity"\n'
                  '• Settings → Apps → Autostart (or "Auto-launch") → enable ZapSound\n\n'
                  'Without this, the OS may stop ZapSound from detecting the '
                  'charger while the app is closed.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
                ],
              ),
            );
          }),
        ], delay: 1),

        const SizedBox(height: ZapTheme.space4),

        _Section('Purchase', [
          _Tile(Icons.restore_rounded, 'Restore purchase', 'Already bought Pro? Tap here', () async {
            final ok = await PurchaseService.restoreAndCheck();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Pro restored!' : 'No purchase found.')));
              _load();
            }
          }),
        ], delay: 2),

        const SizedBox(height: ZapTheme.space4),

        _Section('About', [
          _Tile(Icons.info_outline_rounded, 'Version', '$_version — ZapSound', () {}),
          _Tile(Icons.star_outline_rounded, 'Rate ZapSound', 'Available after release', () {}, disabled: true),
          _Tile(Icons.share_outlined, 'Share with friends', 'Tell someone about ZapSound', () {
            // TODO: add Play Store link after release
            Share.share('Check out ZapSound — it plays a fun sound when you plug in or unplug your charger!');
          }),
          _Tile(Icons.policy_outlined, 'Privacy policy', 'How we handle your data', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const _PrivacyPlaceholderScreen()));
          }),
        ], delay: 3),
      ]),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapTheme.space4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4A42CC), Color(0xFF6C63FF)]),
        borderRadius: BorderRadius.circular(ZapTheme.radiusLg),
      ),
      child: const Row(children: [
        Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
        SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ZapSound Pro Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: ZapTheme.textMd)),
          Text('Lifetime access unlocked', style: TextStyle(color: Colors.white70, fontSize: ZapTheme.textXs)),
        ]),
        Spacer(),
        Icon(Icons.verified_rounded, color: ZapColors.goldLight, size: 24),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final int delay;
  const _Section(this.title, this.children, {this.delay = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title.toUpperCase(),
          style: const TextStyle(fontSize: ZapTheme.textXs, fontWeight: FontWeight.w700, color: ZapColors.textSecondary, letterSpacing: 1.2)),
      ),
      Container(
        decoration: BoxDecoration(
          color: isDark ? ZapColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(ZapTheme.radiusLg),
          border: Border.all(color: ZapColors.primary.withValues(alpha: 0.1)),
        ),
        child: Column(children: children),
      ),
    ]).animate(delay: Duration(milliseconds: 60 * delay))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.08, duration: 300.ms, curve: Curves.easeOut);
  }
}

class _IconCircle extends StatelessWidget {
  final IconData icon;
  final bool disabled;
  const _IconCircle(this.icon, {this.disabled = false});

  @override
  Widget build(BuildContext context) {
    final color = disabled ? ZapColors.textSecondary : ZapColors.primary;
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool disabled;
  const _Tile(this.icon, this.title, this.subtitle, this.onTap, {this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: ListTile(
        leading: _IconCircle(icon, disabled: disabled),
        title: Text(title, style: const TextStyle(fontSize: ZapTheme.textMd, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: ZapColors.textSecondary),
        onTap: disabled ? null : onTap,
      ),
    );
  }
}

class _PrivacyPlaceholderScreen extends StatelessWidget {
  const _PrivacyPlaceholderScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy Policy')),
    body: const Padding(
      padding: EdgeInsets.all(ZapTheme.space4),
      child: Text(
        'ZapSound does not collect or transmit personal data. All sounds, '
        'recordings, and preferences are stored locally on your device.\n\n'
        'A full hosted privacy policy will be linked here after release.',
        style: TextStyle(fontSize: ZapTheme.textMd),
      ),
    ),
  );
}
