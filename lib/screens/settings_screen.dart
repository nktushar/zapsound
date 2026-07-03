import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../models/sound_model.dart';
import '../services/audio_service.dart';
import '../services/preferences_service.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_dialog.dart';
import 'sound_picker_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _channel = MethodChannel('com.zapsound.app/charger');

  bool _isDark = true, _isPremium = false, _battFullEnabled = false;
  bool _chargeAnimEnabled = false;
  bool _quietEnabled = false;
  int _quietStart = 22 * 60, _quietEnd = 7 * 60;
  double _volume = 100;
  String _battFullSoundName = 'Ding!';
  String _version = '...';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final dark = await PrefsService.isDarkMode();
    final prem = await PrefsService.isPremium();
    final battFull = await PrefsService.isBatteryFullEnabled();
    final battFullId = await PrefsService.getBatteryFullSound();
    final volume = await PrefsService.getVolume();
    final chargeAnim = await PrefsService.isChargingAnimEnabled();
    final quietEnabled = await PrefsService.isQuietHoursEnabled();
    final quietStart = await PrefsService.getQuietStart();
    final quietEnd = await PrefsService.getQuietEnd();
    final info = await PackageInfo.fromPlatform();
    final battSound = ZapSoundLibrary.all.firstWhere(
      (s) => s.id == battFullId,
      orElse: () => ZapSoundLibrary.all[3],
    );
    if (mounted) {
      setState(() {
        _isDark = dark;
        _isPremium = prem;
        _battFullEnabled = battFull;
        _battFullSoundName = '${battSound.emoji} ${battSound.name}';
        _volume = volume.toDouble();
        _chargeAnimEnabled = chargeAnim;
        _quietEnabled = quietEnabled;
        _quietStart = quietStart;
        _quietEnd = quietEnd;
        _version = info.version;
      });
    }
  }

  Future<void> _toggleChargingAnim(bool v) async {
    setState(() => _chargeAnimEnabled = v);
    await PrefsService.setChargingAnimEnabled(v);
    if (!v) return;
    bool hasPermission = false;
    try {
      hasPermission = await _channel.invokeMethod('hasOverlayPermission') as bool? ?? false;
    } catch (_) {}
    if (hasPermission) {
      // Instant preview so the user sees what they just enabled.
      try { await _channel.invokeMethod('showChargingAnimation'); } catch (_) {}
      return;
    }
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('One more step'),
        content: const Text(
          'To show the charging animation over your lock screen, Android needs '
          'the "Display over other apps" permission.\n\n'
          'Tap Continue and switch it on for ZapSound.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (go == true) {
      try { await _channel.invokeMethod('requestOverlayPermission'); } catch (_) {}
    }
  }

  String _formatMinutes(int m) =>
      TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context);

  Future<void> _pickQuietTime({required bool isStart}) async {
    final current = isStart ? _quietStart : _quietEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: isStart ? 'Quiet hours start' : 'Quiet hours end',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.all(ZapTheme.space4), children: [

        if (_isPremium)
          _PremiumBadge().animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, curve: Curves.easeOut),

        const SizedBox(height: ZapTheme.space4),

        _Section('Sound', [
          Padding(
            padding: const EdgeInsets.fromLTRB(ZapTheme.space4, ZapTheme.space3, ZapTheme.space4, 0),
            child: Row(children: [
              const _IconCircle(Icons.volume_up_rounded),
              const SizedBox(width: ZapTheme.space4),
              const Expanded(
                child: Text('Volume', style: TextStyle(fontSize: ZapTheme.textMd, fontWeight: FontWeight.w600)),
              ),
              Text('${_volume.round()}%',
                  style: const TextStyle(fontSize: ZapTheme.textSm, fontWeight: FontWeight.w700, color: ZapColors.primary)),
            ]),
          ),
          Slider(
            value: _volume,
            min: 0,
            max: 100,
            activeColor: ZapColors.primary,
            onChanged: (v) => setState(() => _volume = v),
            onChangeEnd: (v) async {
              await PrefsService.setVolume(v.round());
              // Play the current plug-in sound so the level can be judged.
              await AudioService.onPlugIn();
            },
          ),
          SwitchListTile(
            secondary: const _IconCircle(Icons.bedtime_outlined),
            title: const Text('Quiet hours', style: TextStyle(fontSize: ZapTheme.textMd)),
            subtitle: const Text('Mute charger sounds at night — the anti-theft alarm still works',
                style: TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary)),
            value: _quietEnabled,
            activeThumbColor: ZapColors.primary,
            onChanged: (v) async {
              setState(() => _quietEnabled = v);
              await PrefsService.setQuietHoursEnabled(v);
            },
          ),
          if (_quietEnabled) ...[
            _Tile(Icons.nights_stay_outlined, 'Starts', _formatMinutes(_quietStart),
                () => _pickQuietTime(isStart: true)),
            _Tile(Icons.wb_sunny_outlined, 'Ends', _formatMinutes(_quietEnd),
                () => _pickQuietTime(isStart: false)),
          ],
        ], delay: 0),

        const SizedBox(height: ZapTheme.space4),

        _Section('Alerts', [
          SwitchListTile(
            secondary: const _IconCircle(Icons.auto_awesome_rounded),
            title: const Text('Charging animation', style: TextStyle(fontSize: ZapTheme.textMd)),
            subtitle: const Text('Full-screen animation when you plug in — works on the lock screen',
                style: TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary)),
            value: _chargeAnimEnabled,
            activeThumbColor: ZapColors.primary,
            onChanged: _toggleChargingAnim,
          ),
          SwitchListTile(
            secondary: const _IconCircle(Icons.battery_full_rounded),
            title: const Text('Battery full alert', style: TextStyle(fontSize: ZapTheme.textMd)),
            subtitle: const Text('Play a sound when charging reaches 100%',
                style: TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary)),
            value: _battFullEnabled,
            activeThumbColor: ZapColors.primary,
            onChanged: (v) async {
              setState(() => _battFullEnabled = v);
              await PrefsService.setBatteryFullEnabled(v);
            },
          ),
          if (_battFullEnabled)
            _Tile(Icons.music_note_rounded, 'Battery full sound', _battFullSoundName, () async {
              final currentId = await PrefsService.getBatteryFullSound();
              if (!mounted) return;
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => SoundPickerScreen(
                  target: SoundTarget.batteryFull,
                  currentId: currentId,
                  isPremium: _isPremium,
                ),
              ));
              _load();
            }),
          if (_isPremium)
            _Tile(Icons.pin_rounded, 'Anti-theft PIN', 'Change the PIN that stops the alarm', () async {
              final pin = await showPinSetupDialog(context);
              if (pin != null) {
                await PrefsService.setAntitheftPin(pin);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN updated.')),
                  );
                }
              }
            }),
        ], delay: 1),

        const SizedBox(height: ZapTheme.space4),

        _Section('Appearance', [
          SwitchListTile(
            secondary: const _IconCircle(Icons.dark_mode_outlined),
            title: const Text('Dark mode', style: TextStyle(fontSize: ZapTheme.textMd)),
            value: _isDark,
            activeThumbColor: ZapColors.primary,
            onChanged: (v) async {
              setState(() => _isDark = v);
              await PrefsService.setDarkMode(v);
              ZapSoundApp.of(context)?.setDark(v);
            },
          ),
        ], delay: 2),

        const SizedBox(height: ZapTheme.space4),

        _Section('Background & Reliability', [
          _Tile(Icons.battery_charging_full_rounded, 'Allow background activity',
              'Required so charger sounds play when ZapSound is closed', () async {
            await _channel.invokeMethod('requestBatteryOptimizationExemption');
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
        ], delay: 3),

        const SizedBox(height: ZapTheme.space4),

        if (!_isPremium) ...[
          _Section('Purchase', [
            _Tile(Icons.restore_rounded, 'Restore purchase', 'Already bought Pro? Get it back here', () async {
              final ok = await PurchaseService.restoreAndCheck();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Pro restored!' : 'No purchase found.')));
                _load();
              }
            }),
          ], delay: 4),
          const SizedBox(height: ZapTheme.space4),
        ],

        _Section('About', [
          _Tile(Icons.info_outline_rounded, 'Version', 'ZapSound $_version', null),
          _Tile(Icons.star_outline_rounded, 'Rate ZapSound', 'Available after release', () {}, disabled: true),
          _Tile(Icons.share_outlined, 'Share with friends', 'Tell someone about ZapSound', () {
            // TODO: add Play Store link after release
            Share.share('Check out ZapSound — it plays a fun sound when you plug in or unplug your charger!');
          }),
          _Tile(Icons.policy_outlined, 'Privacy policy', 'How we handle your data', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const _PrivacyPlaceholderScreen()));
          }),
        ], delay: 5),
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
        gradient: ZapGradients.premium,
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title.toUpperCase(),
          style: const TextStyle(fontSize: ZapTheme.textXs, fontWeight: FontWeight.w700, color: ZapColors.textSecondary, letterSpacing: 1.2)),
      ),
      GlassCard(
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
  final VoidCallback? onTap;
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
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded, size: 18, color: ZapColors.textSecondary),
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
