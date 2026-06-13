import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final dark = await PrefsService.isDarkMode();
    final prem = await PrefsService.isPremium();
    if (mounted) setState(() { _isDark = dark; _isPremium = prem; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.all(ZapTheme.space4), children: [

        if (_isPremium)
          _PremiumBadge(),

        const SizedBox(height: ZapTheme.space4),

        _Section('Appearance', [
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined, size: 20),
            title: const Text('Dark mode', style: TextStyle(fontSize: ZapTheme.textMd)),
            value: _isDark,
            activeColor: ZapColors.primary,
            onChanged: (v) async {
              setState(() => _isDark = v);
              await PrefsService.setDarkMode(v);
              ZapSoundApp.of(context)?.setDark(v);
            },
          ),
        ]),

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
        ]),

        const SizedBox(height: ZapTheme.space4),

        _Section('Purchase', [
          _Tile(Icons.restore_rounded, 'Restore purchase', 'Already bought Pro? Tap here', () async {
            await PurchaseService.restore();
            final ok = await PrefsService.isPremium();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Pro restored!' : 'No purchase found.')));
              _load();
            }
          }),
        ]),

        const SizedBox(height: ZapTheme.space4),

        _Section('About', [
          _Tile(Icons.info_outline_rounded,  'Version',         '1.0.0 — ZapSound',              () {}),
          _Tile(Icons.star_outline_rounded,  'Rate ZapSound',   'Takes 10 seconds, means a lot', () {}),
          _Tile(Icons.share_outlined,        'Share with friends','Tell someone about ZapSound',  () {}),
          _Tile(Icons.policy_outlined,       'Privacy policy',   'How we handle your data',      () {}),
        ]),
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
  const _Section(this.title, this.children);

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
          border: Border.all(color: ZapColors.primary.withOpacity(0.1)),
        ),
        child: Column(children: children),
      ),
    ]);
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _Tile(this.icon, this.title, this.subtitle, this.onTap);

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, size: 20, color: ZapColors.primary),
    title: Text(title, style: const TextStyle(fontSize: ZapTheme.textMd)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary)),
    trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: ZapColors.textSecondary),
    onTap: onTap,
  );
}
