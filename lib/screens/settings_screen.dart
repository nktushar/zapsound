import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/audio_service.dart';
import '../services/preferences_service.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_dialog.dart';
import 'premium_screen.dart';

const _packageId = 'com.zapsound.app';
const _playStoreUrl = 'https://play.google.com/store/apps/details?id=$_packageId';
// Served by GitHub Pages from docs/ on main.
const _privacyPolicyUrl = 'https://nktushar.github.io/zapsound/privacy_policy.html';

const _themeModes = ['system', 'light', 'dark'];

Future<void> _openUrl(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Opens the Play Store app's listing (where the review box is), falling back
/// to the web listing if the Play Store app isn't installed.
Future<void> _rateApp() async {
  try {
    if (await launchUrl(Uri.parse('market://details?id=$_packageId'), mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {}
  await _openUrl(Uri.parse(_playStoreUrl));
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _themeMode = 'system';
  bool _isPremium = false;
  bool _quietEnabled = false;
  bool _restoring = false;
  int _quietStart = 22 * 60, _quietEnd = 7 * 60;
  double _volume = 100;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await PrefsService.getThemeMode();
    final prem = await PrefsService.isPremium();
    final volume = await PrefsService.getVolume();
    final quietEnabled = await PrefsService.isQuietHoursEnabled();
    final quietStart = await PrefsService.getQuietStart();
    final quietEnd = await PrefsService.getQuietEnd();
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _themeMode = mode;
        _isPremium = prem;
        _volume = volume.toDouble();
        _quietEnabled = quietEnabled;
        _quietStart = quietStart;
        _quietEnd = quietEnd;
        _version = info.version;
      });
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _formatMinutes(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context);

  Future<void> _pickQuietTime({required bool isStart}) async {
    final current = isStart ? _quietStart : _quietEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: isStart ? 'Quiet from' : 'Quiet until',
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    if (isStart) {
      await PrefsService.setQuietStart(minutes);
      if (mounted) setState(() => _quietStart = minutes);
    } else {
      await PrefsService.setQuietEnd(minutes);
      if (mounted) setState(() => _quietEnd = minutes);
    }
  }

  Future<void> _setTheme(int i) async {
    final mode = _themeModes[i];
    HapticFeedback.selectionClick();
    setState(() => _themeMode = mode);
    ZapSoundApp.of(context)?.setThemeMode(parseThemeMode(mode));
    await PrefsService.setThemeMode(mode);
  }

  Future<void> _changePin() async {
    final pin = await showPinSetupDialog(context);
    if (pin != null) {
      await PrefsService.setAntitheftPin(pin);
      if (mounted) _toast('PIN changed.');
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final ok = await PurchaseService.restoreAndCheck();
    if (!mounted) return;
    setState(() => _restoring = false);
    _toast(ok ? 'Purchase restored. Pro is unlocked.' : 'No purchase found for this Google account.');
    _load();
  }

  void _showOemHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final z = ctx.zap;
        Widget step(int n, String text) => Padding(
              padding: const EdgeInsets.only(bottom: ZapTheme.space4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: z.ink, shape: BoxShape.circle),
                  child: Text('$n', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: z.onInk)),
                ),
                const SizedBox(width: ZapTheme.space3),
                Expanded(child: Text(text, style: TextStyle(fontSize: 15, height: 1.45, color: z.ink))),
              ]),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(ZapTheme.space6, 0, ZapTheme.space6, ZapTheme.space5),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Keep ZapSound running', style: zapDisplay(26, color: z.ink)),
              const SizedBox(height: ZapTheme.space2),
              Text(
                'Xiaomi, Oppo, Vivo and some Samsung phones close background apps aggressively. '
                'If sounds don\'t play while the app is closed:',
                style: TextStyle(fontSize: 15, height: 1.45, color: z.inkMuted),
              ),
              const SizedBox(height: ZapTheme.space6),
              step(1, 'Open Settings, then Apps, then ZapSound, then Battery. Choose "No restrictions" or "Allow background activity".'),
              step(2, 'Open Settings, then Apps, then Autostart (sometimes called "Auto-launch"). Turn ZapSound on.'),
              step(3, 'Open ZapSound once after restarting your phone.'),
              const SizedBox(height: ZapTheme.space2),
              ZapPrimaryButton(label: 'Done', onPressed: () => Navigator.pop(ctx)),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final sections = <Widget>[
      if (_isPremium)
        Container(
          margin: const EdgeInsets.only(top: ZapTheme.space2),
          padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
          decoration: BoxDecoration(color: z.ink, borderRadius: BorderRadius.circular(ZapTheme.radiusTile)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ZapSound Pro', style: zapDisplay(22, color: z.onInk)),
                const SizedBox(height: 2),
                Text('Lifetime access. Thanks for supporting the app.',
                    style: TextStyle(fontSize: ZapTheme.textSm, color: z.onInk.withValues(alpha: 0.7))),
              ]),
            ),
            Icon(Icons.verified_rounded, color: z.onInk, size: 26),
          ]),
        ),

      const ZapSectionLabel('Sound'),
      ZapGroup(children: [
        ZapItem(
          icon: Icons.volume_up_outlined,
          title: 'Volume',
          trailing: Text('${_volume.round()}%',
              style: TextStyle(
                  fontSize: ZapTheme.textSm,
                  fontWeight: FontWeight.w700,
                  color: z.inkMuted,
                  fontFeatures: ZapTheme.tabular)),
          below: Padding(
            padding: const EdgeInsets.only(top: ZapTheme.space3, left: 44, right: 4),
            child: Slider(
              value: _volume,
              min: 0,
              max: 100,
              padding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _volume = v),
              onChangeEnd: (v) async {
                await PrefsService.setVolume(v.round());
                // Play the current plug-in sound so the level can be judged.
                await AudioService.onPlugIn();
              },
            ),
          ),
        ),
        ZapItem(
          icon: Icons.bedtime_outlined,
          title: 'Quiet hours',
          subtitle: 'Mute charger sounds at night. The unplug alarm still works.',
          trailing: Switch(
            value: _quietEnabled,
            onChanged: (v) async {
              setState(() => _quietEnabled = v);
              await PrefsService.setQuietHoursEnabled(v);
            },
          ),
          below: AnimatedSize(
            duration: ZapTheme.medium,
            curve: ZapTheme.emphasized,
            alignment: Alignment.topCenter,
            child: _quietEnabled
                ? Padding(
                    padding: const EdgeInsets.only(top: 14, left: 44),
                    child: Row(children: [
                      Expanded(
                        child: _TimeBox(
                            label: 'From', value: _formatMinutes(_quietStart), onTap: () => _pickQuietTime(isStart: true)),
                      ),
                      const SizedBox(width: ZapTheme.space2),
                      Expanded(
                        child: _TimeBox(
                            label: 'Until', value: _formatMinutes(_quietEnd), onTap: () => _pickQuietTime(isStart: false)),
                      ),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ]),

      if (_isPremium) ...[
        const ZapSectionLabel('Unplug alarm'),
        ZapGroup(children: [
          ZapItem(
            icon: Icons.pin_outlined,
            title: 'Change PIN',
            subtitle: 'The 4-digit code that stops the siren',
            chevron: true,
            onTap: _changePin,
          ),
        ]),
      ],

      const ZapSectionLabel('Appearance'),
      ZapGroup(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(ZapTheme.space5, 16, ZapTheme.space4, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Theme', style: TextStyle(fontSize: ZapTheme.textMd, fontWeight: FontWeight.w600, color: z.ink)),
            const SizedBox(height: ZapTheme.space3),
            ZapSegmented(
              options: const ['System', 'Light', 'Dark'],
              index: _themeModes.indexOf(_themeMode).clamp(0, 2),
              onChanged: _setTheme,
            ),
          ]),
        ),
      ]),

      const ZapSectionLabel('Background'),
      ZapGroup(children: [
        ZapItem(
          icon: Icons.battery_saver_outlined,
          title: 'Allow background activity',
          subtitle: 'Needed for sounds to play while the app is closed',
          chevron: true,
          onTap: () async {
            const channel = MethodChannel('com.zapsound.app/charger');
            await channel.invokeMethod('requestBatteryOptimizationExemption');
          },
        ),
        ZapItem(
          icon: Icons.help_outline_rounded,
          title: 'Sounds not playing?',
          subtitle: 'Extra steps for Xiaomi, Oppo, Vivo and Samsung',
          chevron: true,
          onTap: _showOemHelp,
        ),
      ]),

      if (!_isPremium) ...[
        const ZapSectionLabel('Purchase'),
        ZapGroup(children: [
          ZapItem(
            icon: Icons.bolt_rounded,
            title: 'Get ZapSound Pro',
            subtitle: 'Every sound, your recordings and the unplug alarm',
            chevron: true,
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
              _load();
            },
          ),
          ZapItem(
            icon: Icons.restore_rounded,
            title: 'Restore purchase',
            subtitle: 'Already bought Pro on this Google account',
            trailing: _restoring
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _restoring ? null : _restore,
          ),
        ]),
      ],

      const ZapSectionLabel('About'),
      ZapGroup(children: [
        const ZapItem(icon: Icons.star_outline_rounded, title: 'Rate ZapSound', chevron: true, onTap: _rateApp),
        ZapItem(
          icon: Icons.share_outlined,
          title: 'Share with a friend',
          chevron: true,
          onTap: () => Share.share('ZapSound plays a sound when you plug in or unplug your charger. $_playStoreUrl'),
        ),
        ZapItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy policy',
          chevron: true,
          onTap: () => _openUrl(Uri.parse(_privacyPolicyUrl)),
        ),
      ]),
      const SizedBox(height: ZapTheme.space6),
      Center(
        child: Text(_version.isEmpty ? 'ZapSound' : 'ZapSound $_version',
            style: TextStyle(fontSize: ZapTheme.textXs, color: z.inkMuted)),
      ),
    ];

    return Scaffold(
      body: CustomScrollView(slivers: [
        const SliverAppBar.large(title: Text('Settings')),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(ZapTheme.space4, 0, ZapTheme.space4, ZapTheme.space8 + bottomInset),
          sliver: SliverList.list(children: sections),
        ),
      ]),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _TimeBox({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    return Material(
      color: z.surfaceHigh,
      borderRadius: BorderRadius.circular(ZapTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZapTheme.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: ZapTheme.textXs, color: z.inkMuted)),
            const SizedBox(height: 2),
            Text(value,
                style: zapDisplay(19, weight: FontWeight.w600, color: z.ink).copyWith(fontFeatures: ZapTheme.tabular)),
          ]),
        ),
      ),
    );
  }
}
