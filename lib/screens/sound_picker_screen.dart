import 'package:flutter/material.dart';
import '../models/sound_model.dart';
import '../services/preferences_service.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import 'premium_screen.dart';

class SoundPickerScreen extends StatefulWidget {
  final bool isPlugIn;
  final String currentId;
  final bool isPremium;
  const SoundPickerScreen({super.key, required this.isPlugIn, required this.currentId, required this.isPremium});

  @override
  State<SoundPickerScreen> createState() => _SoundPickerScreenState();
}

class _SoundPickerScreenState extends State<SoundPickerScreen> {
  late String _selectedId;
  String _category = 'All';
  String? _playingId;

  @override
  void initState() { super.initState(); _selectedId = widget.currentId; }

  List<SoundModel> get _filtered =>
      _category == 'All' ? ZapSoundLibrary.all : ZapSoundLibrary.all.where((s) => s.category == _category).toList();

  Future<void> _preview(SoundModel s) async {
    if (s.assetPath.isEmpty) return; // 'custom' has no bundled asset to preview here
    setState(() => _playingId = s.id);
    await AudioService.playAsset(s.assetPath);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _playingId = null);
  }

  Future<void> _select(SoundModel s) async {
    if (s.isPremium && !widget.isPremium) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
      return;
    }
    setState(() => _selectedId = s.id);
    if (widget.isPlugIn) await PrefsService.setPlugIn(s.id);
    else await PrefsService.setPlugOut(s.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPlugIn ? 'Plug-in Sound' : 'Unplug Sound',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: Column(children: [
        // Category chips
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space4, vertical: 8),
            children: ZapSoundLibrary.categories.map((cat) {
              final sel = cat == _category;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? ZapColors.primary : (isDark ? ZapColors.surfaceDark : Colors.white),
                      borderRadius: BorderRadius.circular(ZapTheme.radiusFull),
                      border: Border.all(color: sel ? ZapColors.primary : ZapColors.primary.withOpacity(0.2)),
                    ),
                    child: Text(cat,
                      style: TextStyle(
                        fontSize: ZapTheme.textSm,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : ZapColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space4),
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final s = _filtered[i];
              final selected = s.id == _selectedId;
              final locked   = s.isPremium && !widget.isPremium;
              final playing  = _playingId == s.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _select(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(ZapTheme.space3),
                    decoration: BoxDecoration(
                      color: selected
                          ? ZapColors.primary.withOpacity(0.12)
                          : (isDark ? ZapColors.surfaceDark : Colors.white),
                      borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                      border: Border.all(
                        color: selected ? ZapColors.primary : ZapColors.primary.withOpacity(0.1),
                        width: selected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Row(children: [
                      // Emoji in circle
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: locked
                              ? (isDark ? ZapColors.surfaceDark2 : Colors.grey.shade100)
                              : ZapColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                        ),
                        child: Center(child: Text(s.emoji, style: const TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: ZapTheme.space3),

                      // Name + category
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: ZapTheme.textMd)),
                          if (s.isPremium) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.bolt_rounded, size: 13, color: ZapColors.gold),
                          ],
                        ]),
                        Text(s.category, style: const TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary)),
                      ])),

                      // Action button
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        if (s.assetPath.isNotEmpty)
                          GestureDetector(
                            onTap: () => _preview(s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: playing ? ZapColors.primary : ZapColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                              ),
                              child: Icon(
                                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                color: playing ? Colors.white : ZapColors.primary,
                                size: 20,
                              ),
                            ),
                          ),

                        if (locked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ZapColors.gold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                            ),
                            child: const Icon(Icons.lock_rounded, size: 16, color: ZapColors.gold),
                          ),
                        ] else ...[
                          const SizedBox(width: 10),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: selected ? 1.0 : 0.0,
                            child: const Icon(Icons.check_circle_rounded, color: ZapColors.primary, size: 22),
                          ),
                        ],
                      ]),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
