import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/sound_model.dart';
import '../services/preferences_service.dart';
import '../services/audio_service.dart';
import '../services/battery_service.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_dialog.dart';
import 'sound_picker_screen.dart';
import 'premium_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _plugInId  = 's1';
  String _plugOutId = 's2';
  bool   _isPremium = false;
  bool   _isCharging = false;
  bool   _isEnabled = true;
  bool   _antitheftArmed = false;
  String _price = '\$2.99';
  BatteryStatus? _batt;
  Timer? _battTimer;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _load();
    _loadBattery();
    _battTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadBattery());
    BatteryService.chargerEvents.addListener(_loadBattery);
  }

  Future<void> _load() async {
    final inId  = await PrefsService.getPlugIn();
    final outId = await PrefsService.getPlugOut();
    final prem  = await PrefsService.isPremium();
    final enabled = await PrefsService.isEnabled();
    final armed = await PrefsService.isAntitheftArmed();
    if (mounted) setState(() { _plugInId = inId; _plugOutId = outId; _isPremium = prem; _isEnabled = enabled; _antitheftArmed = armed; });
    if (!prem) {
      final product = await PurchaseService.getProduct();
      if (product != null && mounted) setState(() => _price = product.price);
    }
  }

  Future<void> _loadBattery() async {
    final batt = await BatteryService.getStatus();
    if (mounted) setState(() => _batt = batt);
  }

  SoundModel _sound(String id) =>
      ZapSoundLibrary.all.firstWhere((s) => s.id == id, orElse: () => ZapSoundLibrary.all.first);

  void _testCharge() async {
    HapticFeedback.mediumImpact();
    setState(() => _isCharging = !_isCharging);
    if (_isCharging) {
      await AudioService.onPlugIn();
    } else {
      await AudioService.onPlugOut();
    }
  }

  void _toggleEnabled(bool v) async {
    setState(() => _isEnabled = v);
    await PrefsService.setEnabled(v);
  }

  Future<void> _toggleAntitheft(bool v) async {
    if (!_isPremium) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
      _load();
      return;
    }
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
          const SnackBar(content: Text('Armed — unplugging will sound the alarm.')),
        );
      }
    } else {
      await PrefsService.setAntitheftArmed(false);
    }
    if (mounted) setState(() => _antitheftArmed = v);
  }

  void _goToPicker(bool isPlugIn) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SoundPickerScreen(
        target: isPlugIn ? SoundTarget.plugIn : SoundTarget.plugOut,
        currentId: isPlugIn ? _plugInId : _plugOutId,
        isPremium: _isPremium,
      ),
    )).then((_) => _load());
  }

  @override
  void dispose() {
    BatteryService.chargerEvents.removeListener(_loadBattery);
    _battTimer?.cancel();
    _glowCtrl.dispose();
    super.dispose();
  }

  String get _batteryLine {
    final b = _batt;
    if (b == null || b.level < 0) return 'Plug in your charger to hear sounds automatically';
    final parts = <String>['${b.level}%'];
    if (b.isPluggedIn) {
      final state = b.level >= 100 ? 'Fully charged' : 'Charging';
      parts.add('$state · ${b.plugType}');
    } else {
      parts.add('On battery');
    }
    if (b.temperature > 0) parts.add('${b.temperature.toStringAsFixed(1)}°C');
    return parts.join('   ·   ');
  }

  @override
  Widget build(BuildContext context) {
    final plugIn  = _sound(_plugInId);
    final plugOut = _sound(_plugOutId);
    final charging = _batt?.isPluggedIn ?? _isCharging;

    return Scaffold(
      // The fixed hero/cards layout shouldn't squash when a dialog keyboard opens.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.bolt_rounded, color: ZapColors.primary, size: 18),
          const SizedBox(width: 6),
          Text('ZapSound',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              foreground: Paint()..shader = const LinearGradient(
                colors: [ZapColors.primary, ZapColors.cyan],
              ).createShader(const Rect.fromLTWH(0, 0, 120, 20)),
            ),
          ),
        ]),
        actions: [
          if (!_isPremium)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen())).then((_) => _load()),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: ZapGradients.gold,
                  borderRadius: BorderRadius.circular(ZapTheme.radiusFull),
                ),
                child: const Row(children: [
                  Icon(Icons.bolt_rounded, size: 14, color: Colors.black),
                  SizedBox(width: 3),
                  Text('PRO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
                ]),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _load()),
          ),
        ],
      ),

      body: Stack(children: [
        const AuraBackground(),
        SafeArea(child: Column(children: [
          const SizedBox(height: 12),

          // Master enable/disable toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space5),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space4, vertical: ZapTheme.space2),
              child: Row(children: [
                Icon(
                  _isEnabled ? Icons.bolt_rounded : Icons.bolt_outlined,
                  color: _isEnabled ? ZapColors.primary : ZapColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: ZapTheme.space3),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ZapSound', style: TextStyle(fontSize: ZapTheme.textMd, fontWeight: FontWeight.w700)),
                  Text(
                    _isEnabled ? 'Active — charger sounds will play' : 'Paused — charger sounds are off',
                    style: const TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary),
                  ),
                ])),
                Switch(
                  value: _isEnabled,
                  activeThumbColor: ZapColors.primary,
                  onChanged: _toggleEnabled,
                ),
              ]),
            ),
          ).animate().fadeIn(duration: 300.ms),

          const Spacer(),

          // Battery ring hero with the zap test button inside
          GestureDetector(
            onTap: _testCharge,
            child: AnimatedBuilder(
              animation: _glowCtrl,
              builder: (_, __) => SizedBox(
                width: 224, height: 224,
                child: Stack(alignment: Alignment.center, children: [
                  CustomPaint(
                    size: const Size(224, 224),
                    painter: _BatteryRingPainter(
                      progress: (_batt?.level ?? -1) >= 0 ? _batt!.level / 100 : 0,
                      charging: charging,
                      glow: _glowCtrl.value,
                    ),
                  ),
                  Container(
                    width: 158, height: 158,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      boxShadow: charging ? [
                        BoxShadow(
                          color: ZapColors.primary.withValues(alpha: 0.25 + 0.2 * _glowCtrl.value),
                          blurRadius: 34 + 12 * _glowCtrl.value,
                          spreadRadius: 4,
                        ),
                      ] : [],
                    ),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          charging ? Icons.bolt_rounded : Icons.power_rounded,
                          size: 46,
                          color: charging ? ZapColors.primary : ZapColors.textSecondary,
                        )
                            .animate(target: charging ? 1 : 0)
                            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.1, 1.1)),
                        const SizedBox(height: 4),
                        if ((_batt?.level ?? -1) >= 0)
                          Text('${_batt!.level}%',
                              style: const TextStyle(fontSize: ZapTheme.textXl, fontWeight: FontWeight.w800))
                        else
                          Text(
                            _isCharging ? 'Charging!' : 'Tap to test',
                            style: TextStyle(
                              fontSize: ZapTheme.textSm,
                              color: _isCharging ? ZapColors.primary : ZapColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

          const SizedBox(height: 10),
          Text(
            _batteryLine,
            style: const TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap the ring to test your sounds',
            style: TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary),
            textAlign: TextAlign.center,
          ),

          const Spacer(),

          // Sound selector cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space5),
            child: Column(children: [
              _SoundCard(
                label: 'Plug-in sound',
                fromIcon: Icons.power_rounded,
                toIcon: Icons.bolt_rounded,
                sound: plugIn,
                onTap: () => _goToPicker(true),
              ).animate().slideX(begin: -0.08, duration: 400.ms, delay: 100.ms, curve: Curves.easeOut),
              const SizedBox(height: ZapTheme.space3),
              _SoundCard(
                label: 'Unplug sound',
                fromIcon: Icons.bolt_rounded,
                toIcon: Icons.power_rounded,
                sound: plugOut,
                onTap: () => _goToPicker(false),
              ).animate().slideX(begin: 0.08, duration: 400.ms, delay: 180.ms, curve: Curves.easeOut),
              const SizedBox(height: ZapTheme.space3),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space4, vertical: ZapTheme.space2),
                child: Row(children: [
                  Icon(
                    _antitheftArmed ? Icons.gpp_good_rounded : Icons.shield_outlined,
                    color: _antitheftArmed ? ZapColors.success : ZapColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: ZapTheme.space3),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('Anti-theft alarm', style: TextStyle(fontSize: ZapTheme.textMd, fontWeight: FontWeight.w700)),
                      if (!_isPremium) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.bolt_rounded, size: 14, color: ZapColors.gold),
                      ],
                    ]),
                    Text(
                      _antitheftArmed ? 'Armed — siren + PIN if unplugged' : 'Siren if someone unplugs your phone',
                      style: const TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary),
                    ),
                  ])),
                  Switch(
                    value: _antitheftArmed,
                    activeThumbColor: ZapColors.success,
                    onChanged: _toggleAntitheft,
                  ),
                ]),
              ).animate().slideX(begin: -0.08, duration: 400.ms, delay: 260.ms, curve: Curves.easeOut),
            ]),
          ),

          const SizedBox(height: ZapTheme.space4),

          // Premium banner
          if (!_isPremium)
            Padding(
              padding: const EdgeInsets.fromLTRB(ZapTheme.space5, 0, ZapTheme.space5, ZapTheme.space5),
              child: _PremiumBanner(
                price: _price,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen())).then((_) => _load()),
              ),
            ).animate().slideY(begin: 0.3, duration: 400.ms, delay: 300.ms, curve: Curves.easeOut)
          else
            const SizedBox(height: ZapTheme.space5),
        ])),
      ]),
    );
  }
}

class _BatteryRingPainter extends CustomPainter {
  final double progress; // 0–1 battery level
  final bool charging;
  final double glow; // 0–1 pulse

  _BatteryRingPainter({required this.progress, required this.charging, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const stroke = 10.0;
    const start = -math.pi / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = ZapColors.textSecondary.withValues(alpha: 0.15);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        transform: const GradientRotation(start),
        colors: [
          ZapColors.primary,
          ZapColors.cyan,
          charging ? ZapColors.cyan.withValues(alpha: 0.7 + 0.3 * glow) : ZapColors.cyan,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_BatteryRingPainter old) =>
      old.progress != progress || old.charging != charging || old.glow != glow;
}

class _SoundCard extends StatelessWidget {
  final String label;
  final IconData fromIcon, toIcon;
  final SoundModel sound;
  final VoidCallback onTap;
  const _SoundCard({required this.label, required this.fromIcon, required this.toIcon, required this.sound, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(ZapTheme.space4),
      child: Row(children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(fromIcon, size: 18, color: ZapColors.textSecondary),
          const Icon(Icons.arrow_forward_rounded, size: 14, color: ZapColors.textSecondary),
          Icon(toIcon, size: 18, color: ZapColors.textSecondary),
        ]),
        const SizedBox(width: ZapTheme.space3),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary)),
          const SizedBox(height: 3),
          Row(children: [
            Text(sound.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(sound.name, style: const TextStyle(fontSize: ZapTheme.textMd, fontWeight: FontWeight.w700)),
            if (sound.isPremium) ...[
              const SizedBox(width: 6),
              const Icon(Icons.bolt_rounded, size: 14, color: ZapColors.gold),
            ],
          ]),
        ])),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ZapColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
          ),
          child: const Icon(Icons.chevron_right_rounded, color: ZapColors.primary, size: 20),
        ),
      ]),
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  final String price;
  final VoidCallback onTap;
  const _PremiumBanner({required this.price, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(ZapTheme.space4),
        decoration: BoxDecoration(
          gradient: ZapGradients.premium,
          borderRadius: BorderRadius.circular(ZapTheme.radiusLg),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(ZapTheme.radiusMd)),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: ZapTheme.space3),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ZapSound Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: ZapTheme.textMd)),
            Text('30+ sounds · Record your own · No ads', style: TextStyle(color: Colors.white70, fontSize: ZapTheme.textXs)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: ZapGradients.gold,
              borderRadius: BorderRadius.circular(ZapTheme.radiusFull),
            ),
            child: Text(price, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: ZapTheme.textSm)),
          ),
        ]),
      ),
    );
  }
}
