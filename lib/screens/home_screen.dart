import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/sound_model.dart';
import '../services/preferences_service.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
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
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _load();
  }

  Future<void> _load() async {
    final inId  = await PrefsService.getPlugIn();
    final outId = await PrefsService.getPlugOut();
    final prem  = await PrefsService.isPremium();
    final enabled = await PrefsService.isEnabled();
    if (mounted) setState(() { _plugInId = inId; _plugOutId = outId; _isPremium = prem; _isEnabled = enabled; });
  }

  SoundModel _sound(String id) =>
      ZapSoundLibrary.all.firstWhere((s) => s.id == id, orElse: () => ZapSoundLibrary.all.first);

  void _testCharge() async {
    setState(() => _isCharging = !_isCharging);
    if (_isCharging) await AudioService.onPlugIn();
    else await AudioService.onPlugOut();
  }

  void _toggleEnabled(bool v) async {
    setState(() => _isEnabled = v);
    await PrefsService.setEnabled(v);
  }

  void _goToPicker(bool isPlugIn) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SoundPickerScreen(
        isPlugIn: isPlugIn,
        currentId: isPlugIn ? _plugInId : _plugOutId,
        isPremium: _isPremium,
      ),
    )).then((_) => _load());
  }

  @override
  void dispose() { _glowCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plugIn  = _sound(_plugInId);
    final plugOut = _sound(_plugOutId);

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.bolt_rounded, color: ZapColors.primary, size: 18),
          const SizedBox(width: 6),
          Text('ZapSound',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              foreground: Paint()..shader = const LinearGradient(
                colors: [ZapColors.primary, ZapColors.primaryLight],
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
                  gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFFD60A)]),
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

      body: SafeArea(child: Column(children: [
        const SizedBox(height: 20),

        // Master enable/disable toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space4, vertical: ZapTheme.space3),
            decoration: BoxDecoration(
              color: isDark ? ZapColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(ZapTheme.radiusLg),
              border: Border.all(color: ZapColors.primary.withOpacity(0.15)),
            ),
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
                  style: TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary),
                ),
              ])),
              Switch(
                value: _isEnabled,
                activeColor: ZapColors.primary,
                onChanged: _toggleEnabled,
              ),
            ]),
          ),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 16),

        // Central zap button
        GestureDetector(
          onTap: _testCharge,
          child: AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, child) => Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? ZapColors.surfaceDark : Colors.white,
                border: Border.all(
                  color: _isCharging
                      ? ZapColors.primary.withOpacity(0.6 + 0.4 * _glowCtrl.value)
                      : ZapColors.primary.withOpacity(0.2),
                  width: _isCharging ? 3 : 1.5,
                ),
                boxShadow: _isCharging ? [
                  BoxShadow(
                    color: ZapColors.primary.withOpacity(0.3 + 0.2 * _glowCtrl.value),
                    blurRadius: 30 + 10 * _glowCtrl.value,
                    spreadRadius: 5,
                  ),
                ] : [],
              ),
              child: child,
            ),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _isCharging ? Icons.bolt_rounded : Icons.power_rounded,
                  size: 52,
                  color: _isCharging ? ZapColors.primary : ZapColors.textSecondary,
                )
                    .animate(target: _isCharging ? 1 : 0)
                    .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.1, 1.1)),
                const SizedBox(height: 6),
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
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

        const SizedBox(height: 8),
        Text(
          'Plug in your charger to hear sounds automatically',
          style: TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

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
          ]),
        ),

        const Spacer(),

        // Premium banner
        if (!_isPremium)
          Padding(
            padding: const EdgeInsets.fromLTRB(ZapTheme.space5, 0, ZapTheme.space5, ZapTheme.space5),
            child: _PremiumBanner(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen())).then((_) => _load()),
            ),
          ).animate().slideY(begin: 0.3, duration: 400.ms, delay: 300.ms, curve: Curves.easeOut),
      ])),
    );
  }
}

class _SoundCard extends StatelessWidget {
  final String label;
  final IconData fromIcon, toIcon;
  final SoundModel sound;
  final VoidCallback onTap;
  const _SoundCard({required this.label, required this.fromIcon, required this.toIcon, required this.sound, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? ZapColors.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(ZapTheme.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZapTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(ZapTheme.space4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZapTheme.radiusLg),
            border: Border.all(color: ZapColors.primary.withOpacity(0.15)),
          ),
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
                color: ZapColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
              ),
              child: const Icon(Icons.chevron_right_rounded, color: ZapColors.primary, size: 20),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(ZapTheme.space4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A42CC), Color(0xFF6C63FF), Color(0xFF9D6FFF)],
          ),
          borderRadius: BorderRadius.circular(ZapTheme.radiusLg),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(ZapTheme.radiusMd)),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: ZapTheme.space3),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ZapSound Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: ZapTheme.textMd)),
            Text('50+ sounds · Record your own · No ads', style: TextStyle(color: Colors.white70, fontSize: ZapTheme.textXs)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [ZapColors.gold, ZapColors.goldLight]),
              borderRadius: BorderRadius.circular(ZapTheme.radiusFull),
            ),
            child: const Text('\$2.99', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: ZapTheme.textSm)),
          ),
        ]),
      ),
    );
  }
}
