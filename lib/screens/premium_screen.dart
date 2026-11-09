import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sound_model.dart';
import '../services/audio_service.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sound_widgets.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _loading = false, _restoring = false;
  String _price = '\$2.99';
  String? _playingId;
  StreamSubscription<PurchaseEvent>? _purchaseSub;

  // A taste of the Pro library, mixed across categories.
  static const _sampleIds = ['p26', 'p7', 'p44', 'p3', 'p92', 'p67', 'p2', 'p133', 'p112', 'p16', 'p142', 'p19'];

  @override
  void initState() {
    super.initState();
    _loadPrice();
    _purchaseSub = PurchaseService.events.listen(_onPurchaseEvent);
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    if (_playingId != null) AudioService.stop();
    super.dispose();
  }

  Future<void> _loadPrice() async {
    final p = await PurchaseService.getProduct();
    if (p != null && mounted) setState(() => _price = p.price);
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _preview(SoundModel s) async {
    if (_playingId == s.id) {
      await AudioService.stop();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _playingId = s.id);
    await AudioService.playAsset(s.assetPath);
    if (mounted && _playingId == s.id) setState(() => _playingId = null);
  }

  // Only react while a buy is in flight; restore has its own feedback.
  void _onPurchaseEvent(PurchaseEvent e) {
    if (!mounted || !_loading) return;
    setState(() => _loading = false);
    switch (e.outcome) {
      case PurchaseOutcome.purchased:
        _toast('Pro unlocked. Enjoy every sound.');
        Navigator.pop(context, true);
      case PurchaseOutcome.pending:
        _toast('Payment pending. Pro unlocks automatically when it completes.');
      case PurchaseOutcome.canceled:
        break;
      case PurchaseOutcome.error:
        _toast('Purchase didn\'t go through${e.message != null ? ' (${e.message})' : ''}. Try again.');
    }
  }

  Future<void> _buy() async {
    setState(() => _loading = true);
    BuyStart start;
    try {
      start = await PurchaseService.buy();
    } catch (_) {
      start = BuyStart.failed;
    }
    if (!mounted) return;
    switch (start) {
      case BuyStart.launched:
        return; // outcome arrives via _onPurchaseEvent
      case BuyStart.alreadyOwned:
        setState(() => _loading = false);
        _toast('You already own Pro. It\'s been restored.');
        Navigator.pop(context, true);
      case BuyStart.storeUnavailable:
        setState(() => _loading = false);
        _toast('Google Play isn\'t reachable. Check your connection and try again.');
      case BuyStart.failed:
        setState(() => _loading = false);
        _toast('Couldn\'t open Google Play. Try again.');
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final ok = await PurchaseService.restoreAndCheck();
    if (mounted) {
      setState(() => _restoring = false);
      _toast(ok ? 'Purchase restored. Pro is unlocked.' : 'No purchase found for this Google account.');
      if (ok) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    final total = ZapSoundLibrary.all.where((s) => s.id != 'custom').length;
    final samples = [
      for (final id in _sampleIds) ZapSoundLibrary.all.firstWhere((s) => s.id == id),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(ZapTheme.space5, 0, ZapTheme.space5, ZapTheme.space6),
            children: [
              Text('ZapSound Pro', style: zapDisplay(40, weight: FontWeight.w800, color: z.ink, height: 1.05)),
              const SizedBox(height: ZapTheme.space2),
              Text(
                'Pay once and keep everything. No subscription.',
                style: TextStyle(fontSize: ZapTheme.textMd, color: z.inkMuted, height: 1.5),
              ),
              const SizedBox(height: ZapTheme.space6),

              // Hear before you buy.
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in samples)
                  _SoundChip(
                    sound: s,
                    hue: hueForCategory(z, s.category),
                    playing: _playingId == s.id,
                    onTap: () => _preview(s),
                  ),
              ]),
              const SizedBox(height: ZapTheme.space2),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Tap any sound to hear it', style: TextStyle(fontSize: ZapTheme.textXs, color: z.inkMuted)),
              ),

              const ZapSectionLabel('What you get'),
              ZapGroup(children: [
                ZapItem(
                  icon: Icons.library_music_outlined,
                  hue: z.charge,
                  title: 'All $total sounds',
                  subtitle: 'Funny, retro, sci-fi and chill packs',
                ),
                ZapItem(
                  icon: Icons.mic_none_rounded,
                  hue: z.release,
                  title: 'Record your own',
                  subtitle: 'Use your voice for plugging in or unplugging',
                ),
                ZapItem(
                  icon: Icons.shield_outlined,
                  hue: z.guard,
                  title: 'Unplug alarm',
                  subtitle: 'A loud siren and PIN lock if someone takes your phone off the charger',
                ),
                ZapItem(
                  icon: Icons.auto_awesome_outlined,
                  hue: z.full,
                  title: 'Future sound packs',
                  subtitle: 'New sounds are included at no extra cost',
                ),
              ]),
            ],
          ),
        ),

        // Sticky purchase bar
        Container(
          color: z.bg,
          padding: const EdgeInsets.fromLTRB(ZapTheme.space5, ZapTheme.space3, ZapTheme.space5, ZapTheme.space1),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ZapPrimaryButton(label: 'Unlock Pro for $_price', loading: _loading, onPressed: _buy),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('One-time purchase through Google Play.',
                    style: TextStyle(fontSize: ZapTheme.textXs, color: z.inkMuted)),
                TextButton(
                  onPressed: _restoring ? null : _restore,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: ZapTheme.textXs, fontWeight: FontWeight.w800),
                  ),
                  child: Text(_restoring ? 'Restoring…' : 'Restore'),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SoundChip extends StatelessWidget {
  final SoundModel sound;
  final ZapHue hue;
  final bool playing;
  final VoidCallback onTap;
  const _SoundChip({required this.sound, required this.hue, required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Play ${sound.name}',
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.94,
        child: AnimatedContainer(
          duration: ZapTheme.fast,
          padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
          decoration: BoxDecoration(
            color: playing ? hue.onContainer : hue.container,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 16,
              height: 16,
              child: playing
                  ? EqualizerBars(color: hue.container, size: 14)
                  : Icon(Icons.play_arrow_rounded, size: 16, color: hue.onContainer),
            ),
            const SizedBox(width: 6),
            Text(sound.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: playing ? hue.container : hue.onContainer,
                )),
          ]),
        ),
      ),
    );
  }
}
