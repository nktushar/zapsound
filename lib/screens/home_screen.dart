import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sound_model.dart';
import '../services/preferences_service.dart';
import '../services/audio_service.dart';
import '../services/battery_service.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/sound_widgets.dart';
import 'sound_picker_screen.dart';
import 'premium_screen.dart';
import 'settings_screen.dart';

const double _kDial = 232;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _plugInId = 's1';
  String _plugOutId = 's2';
  String _battFullId = 's4';
  bool _battFullEnabled = false;
  bool _isPremium = false;
  // Simulated charger state while a tap-to-test is playing; null = show the
  // real battery state. Must win over _batt, which is non-null on Android.
  bool? _testCharging;
  int _testSeq = 0;
  bool _isEnabled = true;
  bool _antitheftArmed = false;
  String _price = '\$2.99';
  SoundTarget? _previewing; // tile whose sound is currently previewing
  BatteryStatus? _batt;
  Timer? _battTimer;
  // Drives the pulse that travels through lit ticks while charging.
  late final AnimationController _flowCtrl;
  // Ripple fired by tap-to-test; colored by the moment being tested.
  late final AnimationController _burstCtrl;
  bool _burstPlugIn = true;

  @override
  void initState() {
    super.initState();
    _flowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _burstCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _load();
    _loadBattery();
    _battTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadBattery());
    BatteryService.chargerEvents.addListener(_loadBattery);
  }

  Future<void> _load() async {
    final inId = await PrefsService.getPlugIn();
    final outId = await PrefsService.getPlugOut();
    final prem = await PrefsService.isPremium();
    final enabled = await PrefsService.isEnabled();
    final armed = await PrefsService.isAntitheftArmed();
    final battFull = await PrefsService.isBatteryFullEnabled();
    final battFullId = await PrefsService.getBatteryFullSound();
    if (mounted) {
      setState(() {
        _plugInId = inId;
        _plugOutId = outId;
        _isPremium = prem;
        _isEnabled = enabled;
        _antitheftArmed = armed;
        _battFullEnabled = battFull;
        _battFullId = battFullId;
      });
    }
    if (!prem) {
      final product = await PurchaseService.getProduct();
      if (product != null && mounted) setState(() => _price = product.price);
    }
  }

  Future<void> _loadBattery() async {
    final batt = await BatteryService.getStatus();
    if (!mounted) return;
    setState(() => _batt = batt);
    _syncFlow();
  }

  void _syncFlow() {
    if (_showCharging) {
      if (!_flowCtrl.isAnimating) _flowCtrl.repeat();
    } else {
      _flowCtrl.stop();
    }
  }

  SoundModel _sound(String id) =>
      ZapSoundLibrary.all.firstWhere((s) => s.id == id, orElse: () => ZapSoundLibrary.all.first);

  bool get _showCharging => _testCharging ?? _batt?.isPluggedIn ?? false;

  Future<void> _testCharge() async {
    HapticFeedback.mediumImpact();
    final plugIn = !_showCharging;
    final seq = ++_testSeq;
    setState(() {
      _testCharging = plugIn;
      _burstPlugIn = plugIn;
    });
    _syncFlow();
    _burstCtrl.forward(from: 0);
    if (plugIn) {
      await AudioService.onPlugIn();
    } else {
      await AudioService.onPlugOut();
    }
    // Hold the simulated state briefly, then fall back to the real one —
    // unless another tap started a newer test meanwhile.
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted && seq == _testSeq) {
      setState(() => _testCharging = null);
      _syncFlow();
    }
  }

  Future<void> _previewTile(SoundTarget t) async {
    if (_previewing == t) {
      await AudioService.stop();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _previewing = t);
    if (t == SoundTarget.plugIn) {
      await AudioService.onPlugIn();
    } else {
      await AudioService.onPlugOut();
    }
    if (mounted && _previewing == t) setState(() => _previewing = null);
  }

  Future<void> _toggleEnabled(bool v) async {
    HapticFeedback.selectionClick();
    setState(() => _isEnabled = v);
    await PrefsService.setEnabled(v);
  }

  Future<void> _toggleBatteryFull(bool v) async {
    HapticFeedback.selectionClick();
    setState(() => _battFullEnabled = v);
    await PrefsService.setBatteryFullEnabled(v);
  }

  Future<void> _openPremium() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
    _load();
  }

  Future<void> _toggleAntitheft(bool v) async {
    if (!_isPremium) {
      await _openPremium();
      return;
    }
    HapticFeedback.selectionClick();
    if (v) {
      var pin = await PrefsService.getAntitheftPin();
      if (pin == null) {
        if (!mounted) return;
        pin = await showPinSetupDialog(context);
        if (pin == null) return;
        await PrefsService.setAntitheftPin(pin);
      }
      await PrefsService.setAntitheftArmed(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alarm armed. Unplugging now sounds the siren.')),
        );
      }
      if (!await BatteryService.canUseFullScreenIntent() && mounted) {
        await _askFullScreenPermission();
      }
    } else {
      await PrefsService.setAntitheftArmed(false);
    }
    if (mounted) setState(() => _antitheftArmed = v);
  }

  /// Without the full-screen-intent permission the siren still sounds, but
  /// the PIN screen only appears as a notification instead of over the lock
  /// screen.
  Future<void> _askFullScreenPermission() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Show the PIN pad on the lock screen?'),
        content: const Text(
          'Allow full-screen notifications so the PIN pad appears over your lock screen when the alarm goes off.\n\n'
          'Without it the siren still sounds, but you have to tap the notification to stop it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open settings')),
        ],
      ),
    );
    if (open == true) await BatteryService.openFullScreenIntentSettings();
  }

  Future<void> _goToPicker(SoundTarget target) async {
    if (_previewing != null) await AudioService.stop();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SoundPickerScreen(
          target: target,
          currentId: switch (target) {
            SoundTarget.plugIn => _plugInId,
            SoundTarget.plugOut => _plugOutId,
            SoundTarget.batteryFull => _battFullId,
          },
          isPremium: _isPremium,
        ),
      ),
    );
    _load();
  }

  @override
  void dispose() {
    BatteryService.chargerEvents.removeListener(_loadBattery);
    _battTimer?.cancel();
    _flowCtrl.dispose();
    _burstCtrl.dispose();
    super.dispose();
  }

  String get _stateLine {
    if (_testCharging != null) return _testCharging! ? 'Testing plug-in sound' : 'Testing unplug sound';
    final b = _batt;
    if (b == null || b.level < 0) return 'Battery status unavailable';
    if (b.isPluggedIn) {
      final state = b.level >= 100 ? 'Fully charged' : 'Charging';
      return b.plugType.isEmpty ? state : '$state via ${b.plugType}';
    }
    return 'On battery';
  }

  @override
  Widget build(BuildContext context) {
    final z = context.zap;

    return Scaffold(
      // The fixed hero layout shouldn't squash when a dialog keyboard opens.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        titleSpacing: ZapTheme.space5,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: z.ink, borderRadius: BorderRadius.circular(9)),
            child: Icon(Icons.bolt_rounded, size: 19, color: z.onInk),
          ),
          const SizedBox(width: 10),
          Text('ZapSound', style: zapDisplay(23, weight: FontWeight.w800, color: z.ink)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapTheme.space3),
            child: IconButton.filled(
              tooltip: 'Settings',
              style: IconButton.styleFrom(backgroundColor: z.surface, foregroundColor: z.ink),
              icon: const Icon(Icons.settings_outlined, size: 22),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                _load();
              },
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(ZapTheme.space4, 0, ZapTheme.space4, ZapTheme.space8),
        children: [
          _buildDial(z),
          const SizedBox(height: ZapTheme.space6),

          // Main moments, governed by the master switch in their header.
          Padding(
            padding: const EdgeInsets.fromLTRB(ZapTheme.space1, 0, 0, ZapTheme.space3),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Charger sounds', style: zapDisplay(22, color: z.ink)),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: ZapTheme.fast,
                    layoutBuilder: (c, p) => Stack(alignment: Alignment.topLeft, children: [...p, if (c != null) c]),
                    child: Text(
                      _isEnabled ? 'Playing even when the app is closed' : 'Paused. Nothing will play.',
                      key: ValueKey(_isEnabled),
                      style: TextStyle(fontSize: ZapTheme.textSm, color: z.inkMuted),
                    ),
                  ),
                ]),
              ),
              Switch(value: _isEnabled, onChanged: _toggleEnabled),
            ]),
          ),
          SizedBox(
            height: 184,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: _MomentTile(
                  label: 'When plugged in',
                  icon: Icons.power_rounded,
                  hue: z.charge,
                  sound: _sound(_plugInId),
                  enabled: _isEnabled,
                  playing: _previewing == SoundTarget.plugIn,
                  onPreview: () => _previewTile(SoundTarget.plugIn),
                  onTap: () => _goToPicker(SoundTarget.plugIn),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MomentTile(
                  label: 'When unplugged',
                  icon: Icons.power_off_rounded,
                  hue: z.release,
                  sound: _sound(_plugOutId),
                  enabled: _isEnabled,
                  playing: _previewing == SoundTarget.plugOut,
                  onPreview: () => _previewTile(SoundTarget.plugOut),
                  onTap: () => _goToPicker(SoundTarget.plugOut),
                ),
              ),
            ]),
          ),

          const ZapSectionLabel('More alerts'),
          ZapGroup(
            colors: [null, _antitheftArmed ? z.guard.container : null],
            children: [
              ZapItem(
                icon: Icons.battery_full_rounded,
                hue: z.full,
                title: 'Battery full',
                subtitle: _battFullEnabled
                    ? 'Plays ${_sound(_battFullId).name} at 100%'
                    : 'Play a sound when charging finishes',
                trailing: SplitSwitch(value: _battFullEnabled, onChanged: _toggleBatteryFull),
                onTap: () => _goToPicker(SoundTarget.batteryFull),
              ),
              ZapItem(
                icon: _antitheftArmed ? Icons.shield_rounded : Icons.shield_outlined,
                hue: z.guard,
                title: 'Unplug alarm',
                titleColor: _antitheftArmed ? z.guard.onContainer : null,
                hueFilled: _antitheftArmed,
                subtitle: _antitheftArmed
                    ? 'Armed. The siren plays until your PIN is entered.'
                    : 'Sound a siren if someone takes your phone off the charger',
                trailing: _isPremium ? Switch(value: _antitheftArmed, onChanged: _toggleAntitheft) : const ProTag(),
                onTap: () => _toggleAntitheft(!_antitheftArmed),
              ),
            ],
          ),

          if (!_isPremium) ...[
            const SizedBox(height: ZapTheme.space6),
            _ProCard(price: _price, onTap: _openPremium),
          ],
        ],
      ),
    );
  }

  Widget _buildDial(ZapTokens z) {
    final charging = _showCharging;
    final level = _batt?.level ?? -1;
    final known = level >= 0;
    final low = known && level <= 15 && !charging;
    final lit = low ? z.danger : (charging ? z.charge.strong : z.ink);

    return Column(children: [
      const SizedBox(height: ZapTheme.space2),
      Semantics(
        button: true,
        label: known ? 'Battery $level percent. Tap to test your sounds.' : 'Tap to test your sounds.',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Hit area is clipped to the dial's circle: the box corners lie
          // visually outside it, so a plain onTap would fire there too.
          onTapUp: (d) {
            const c = Offset(_kDial / 2, _kDial / 2);
            if ((d.localPosition - c).distance <= _kDial / 2) _testCharge();
          },
          child: SizedBox(
            width: _kDial,
            height: _kDial,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: known ? level / 100 : 0),
              duration: const Duration(milliseconds: 900),
              curve: ZapTheme.emphasized,
              builder: (_, progress, __) => AnimatedBuilder(
                animation: Listenable.merge([_flowCtrl, _burstCtrl]),
                builder: (_, __) => CustomPaint(
                  painter: _DialPainter(
                    progress: progress,
                    lit: lit,
                    unlit: z.surfaceHigh,
                    flow: charging ? _flowCtrl.value : null,
                    burst: _burstCtrl.isAnimating ? _burstCtrl.value : null,
                    burstColor: _burstPlugIn ? z.charge.strong : z.release.strong,
                  ),
                  child: Center(child: _dialCenter(z, level, known, charging)),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: ZapTheme.space1),
      Text('Tap the dial to test', style: TextStyle(fontSize: ZapTheme.textXs, color: z.inkMuted)),
    ]);
  }

  Widget _dialCenter(ZapTokens z, int level, bool known, bool charging) {
    final temp = _batt?.temperature ?? -1;
    final accent = charging ? z.charge.strong : z.inkMuted;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          known ? '$level' : '—',
          style: zapDisplay(68, weight: FontWeight.w700, color: z.ink, height: 1.0)
              .copyWith(fontFeatures: ZapTheme.tabular),
        ),
        if (known)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2),
            child: Text('%', style: zapDisplay(22, weight: FontWeight.w600, color: z.inkMuted)),
          ),
      ]),
      const SizedBox(height: 6),
      AnimatedSwitcher(
        duration: ZapTheme.medium,
        child: Row(
          key: ValueKey(_stateLine),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (charging) ...[Icon(Icons.bolt_rounded, size: 16, color: accent), const SizedBox(width: 2)],
            Text(_stateLine,
                style: TextStyle(fontSize: ZapTheme.textSm, fontWeight: FontWeight.w700, color: accent)),
          ],
        ),
      ),
      if (temp > 0) ...[
        const SizedBox(height: 2),
        Text('${temp.toStringAsFixed(1)} °C',
            style: TextStyle(fontSize: ZapTheme.textXs, color: z.inkMuted, fontFeatures: ZapTheme.tabular)),
      ],
    ]);
  }
}

/// Instrument-style battery gauge: a ring of tick marks lit up to the battery
/// level. While charging, a brighter pulse travels through the lit ticks like
/// current through a wire. [burst] (0→1) draws one expanding ring for
/// tap-to-test feedback.
class _DialPainter extends CustomPainter {
  final double progress;
  final Color lit;
  final Color unlit;
  final double? flow;
  final double? burst;
  final Color burstColor;

  static const _ticks = 60;

  _DialPainter({
    required this.progress,
    required this.lit,
    required this.unlit,
    required this.flow,
    required this.burst,
    required this.burstColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2 - 6;
    const len = 15.0;
    final litCount = (progress * _ticks).round();

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.5;

    for (var i = 0; i < _ticks; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / _ticks;
      final dir = Offset(math.cos(a), math.sin(a));
      final isLit = i < litCount;
      var color = isLit ? lit : unlit;
      if (isLit && flow != null && litCount > 0) {
        // Distance (in ticks) behind the travelling pulse head.
        final head = flow! * litCount;
        var d = head - i;
        if (d < 0) d += litCount;
        final glow = (1 - d / 8).clamp(0.0, 1.0);
        color = Color.lerp(lit.withValues(alpha: 0.45), lit, glow)!;
      }
      paint.color = color;
      canvas.drawLine(c + dir * (outer - len), c + dir * outer, paint);
    }

    final b = burst;
    if (b != null) {
      final e = Curves.easeOutCubic.transform(b);
      canvas.drawCircle(
        c,
        outer - len - 10 + 26 * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 5 * (1 - b)
          ..color = burstColor.withValues(alpha: 0.7 * (1 - b)),
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter o) =>
      o.progress != progress ||
      o.lit != lit ||
      o.unlit != unlit ||
      o.flow != flow ||
      o.burst != burst ||
      o.burstColor != burstColor;
}

/// Big colored tile for one charger moment. Tap = change sound,
/// play button = preview. Turns neutral while charger sounds are off.
class _MomentTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final ZapHue hue;
  final SoundModel sound;
  final bool enabled;
  final bool playing;
  final VoidCallback onPreview;
  final VoidCallback onTap;

  const _MomentTile({
    required this.label,
    required this.icon,
    required this.hue,
    required this.sound,
    required this.enabled,
    required this.playing,
    required this.onPreview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    final bg = enabled ? hue.container : z.surface;
    final fg = enabled ? hue.onContainer : z.inkMuted;
    return Semantics(
      button: true,
      label: '$label: ${sound.name}. Tap to change.',
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ZapTheme.medium,
          curve: ZapTheme.emphasized,
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 18),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(ZapTheme.radiusTile)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 4), child: Icon(icon, size: 26, color: fg)),
              const Spacer(),
              PlayButton(
                playing: playing,
                onPressed: onPreview,
                size: 46,
                fill: fg,
                iconColor: bg,
              ),
            ]),
            const Spacer(),
            Row(children: [
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: ZapTheme.textSm,
                        fontWeight: FontWeight.w600,
                        color: fg.withValues(alpha: 0.75))),
              ),
              if (playing) ...[const SizedBox(width: 6), EqualizerBars(color: fg, size: 12)],
            ]),
            const SizedBox(height: 4),
            Text(
              sound.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: zapDisplay(24, color: fg, height: 1.05),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Inverted ink card advertising Pro. The four dots are the moment colors —
/// "everything unlocked".
class _ProCard extends StatelessWidget {
  final String price;
  final VoidCallback onTap;
  const _ProCard({required this.price, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 20, 20),
        decoration: BoxDecoration(color: z.ink, borderRadius: BorderRadius.circular(ZapTheme.radiusTile)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('ZapSound Pro', style: zapDisplay(24, color: z.onInk))),
            for (final h in [z.charge, z.release, z.full, z.guard])
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(color: h.strong, shape: BoxShape.circle),
              ),
          ]),
          const SizedBox(height: 6),
          Text(
            '${ZapSoundLibrary.all.where((s) => s.isPremium && s.id != 'custom').length} more sounds, your own recordings and the unplug alarm. One payment, no subscription.',
            style: TextStyle(fontSize: ZapTheme.textSm, height: 1.45, color: z.onInk.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: ZapTheme.space4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(color: z.onInk, borderRadius: BorderRadius.circular(100)),
            child: Text('Unlock for $price',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: z.ink)),
          ),
        ]),
      ),
    );
  }
}
