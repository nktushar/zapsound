import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _loading = false, _restoring = false;
  String _price = '\$2.99';
@override
  void initState() { super.initState(); _loadPrice(); }
Future<void> _loadPrice() async {
    final p = await PurchaseService.getProduct();
    if (p != null && mounted) setState(() => _price = p.price);
  }
Future<void> _buy() async {
    setState(() => _loading = true);
    try {
      await PurchaseService.buy();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase failed. Try again.')));
    }
    if (mounted) setState(() => _loading = false);
  }
Future<void> _restore() async {
    setState(() => _restoring = true);
    final ok = await PurchaseService.restoreAndCheck();
    if (mounted) {
      setState(() => _restoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Premium restored!' : 'No purchase found.')));
      if (ok) Navigator.pop(context);
    }
  }
static const _features = [
    (Icons.shield_rounded, 'Anti-theft alarm', 'Loud siren + PIN lock if someone unplugs your phone'),
    (Icons.bolt_rounded, '25+ premium sounds', 'Funny, retro, sci-fi & chill packs'),
    (Icons.mic_rounded, 'Record your own sounds', 'Your voice, any sound you like'),
    (Icons.card_giftcard_rounded, 'All future sound packs free', 'Every new release included'),
    (Icons.all_inclusive_rounded, 'Lifetime access', 'Pay once, yours forever — no subscription'),
  ];
@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const AuraBackground(),
        SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(ZapTheme.space5),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: ZapTheme.space6),
              decoration: BoxDecoration(
                gradient: ZapGradients.premium,
                borderRadius: BorderRadius.circular(ZapTheme.radiusXl),
                boxShadow: [
                  BoxShadow(color: ZapColors.primary.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(children: [
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 52)
                    .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                const SizedBox(height: 12),
                const Text('ZapSound Pro',
                    style: TextStyle(color: Colors.white, fontSize: ZapTheme.text2xl, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(ZapTheme.radiusFull),
                  ),
                  child: const Text('Pay once · Yours forever',
                      style: TextStyle(color: Colors.white70, fontSize: ZapTheme.textSm)),
                ),
              ]),
            ),
Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space5),
              child: Column(
                children: _features.asMap().entries.map((e) =>
                  _FeatureRow(icon: e.value.$1, title: e.value.$2, subtitle: e.value.$3, delay: e.key * 70)
                ).toList(),
              ),
            ),

const SizedBox(height: ZapTheme.space8),
Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space5),
              child: Column(children: [
                Container(
                  width: double.infinity, height: 58,
                  decoration: BoxDecoration(
                    gradient: ZapGradients.brand,
                    borderRadius: BorderRadius.circular(ZapTheme.radiusLg),
                    boxShadow: [
                      BoxShadow(color: ZapColors.primary.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _loading ? null : _buy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZapTheme.radiusLg)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Text('Unlock ZapSound Pro — $_price',
                            style: const TextStyle(fontSize: ZapTheme.textMd, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _restoring ? null : _restore,
                  child: _restoring
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Restore purchase',
                          style: TextStyle(color: ZapColors.textSecondary, fontSize: ZapTheme.textSm)),
                ),
                const SizedBox(height: 6),
                const Text('Secure payment via Google Play',
                    style: TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary)),
              ]),
            ),

            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 16, color: ZapColors.textSecondary),
              label: const Text('Maybe later',
                  style: TextStyle(color: ZapColors.textSecondary, fontSize: ZapTheme.textSm)),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
      ]),
    );
  }
}
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final int delay;
  const _FeatureRow({required this.icon, required this.title, required this.subtitle, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapTheme.space3),
      child: GlassCard(
        padding: const EdgeInsets.all(ZapTheme.space3),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ZapColors.primary.withValues(alpha: 0.20),
                  ZapColors.cyan.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
            ),
            child: Center(child: Icon(icon, color: ZapColors.primary, size: 22)),
          ),
          const SizedBox(width: ZapTheme.space3),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: ZapTheme.textMd)),
            Text(subtitle, style: const TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary)),
          ])),
          const Icon(Icons.check_circle_rounded, color: ZapColors.success, size: 20),
        ]),
      ),
    ).animate().slideX(begin: 0.1, duration: 350.ms, delay: Duration(milliseconds: delay), curve: Curves.easeOut);
  }
}
