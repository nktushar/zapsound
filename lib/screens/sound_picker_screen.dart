import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/sound_model.dart';
import '../services/preferences_service.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import 'premium_screen.dart';
import 'record_sound_screen.dart';

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
  bool _customRecorded = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentId;
    _loadCustomRecorded();
  }

  Future<void> _loadCustomRecorded() async {
    final path = widget.isPlugIn ? await PrefsService.getCustomIn() : await PrefsService.getCustomOut();
    if (mounted) setState(() => _customRecorded = path != null);
  }

  List<SoundModel> get _filtered {
    final base = _category == 'All'
        ? ZapSoundLibrary.all
        : ZapSoundLibrary.all.where((s) => s.category == _category).toList();
    final sorted = [...base];
    sorted.sort((a, b) => a.id == 'custom' ? -1 : (b.id == 'custom' ? 1 : 0));
    return sorted;
  }

  Future<void> _preview(SoundModel s) async {
    if (s.id == 'custom') {
      final path = widget.isPlugIn ? await PrefsService.getCustomIn() : await PrefsService.getCustomOut();
      if (path == null) return;
      setState(() => _playingId = s.id);
      await AudioService.playFile(path);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _playingId = null);
      return;
    }
    if (s.assetPath.isEmpty) return;
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
    if (s.id == 'custom') {
      if (!_customRecorded) {
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => RecordSoundScreen(isPlugIn: widget.isPlugIn)),
        );
        if (saved == true && mounted) Navigator.pop(context);
        return;
      }
      // Already recorded: behave like any other row — select and close.
    }
    setState(() => _selectedId = s.id);
    if (widget.isPlugIn) await PrefsService.setPlugIn(s.id);
    else await PrefsService.setPlugOut(s.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _reRecord() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RecordSoundScreen(isPlugIn: widget.isPlugIn)),
    );
    if (saved == true) await _loadCustomRecorded();
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
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    scale: sel ? 1.0 : 0.94,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: sel
                            ? const LinearGradient(colors: [Color(0xFF4A42CC), ZapColors.primary])
                            : null,
                        color: sel ? null : (isDark ? ZapColors.surfaceDark : Colors.white),
                        borderRadius: BorderRadius.circular(ZapTheme.radiusFull),
                        border: Border.all(color: sel ? ZapColors.primary : ZapColors.primary.withValues(alpha: 0.2)),
                        boxShadow: sel
                            ? [BoxShadow(color: ZapColors.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                            : null,
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
                      gradient: selected
                          ? LinearGradient(
                              colors: [ZapColors.primary.withValues(alpha: 0.18), ZapColors.primary.withValues(alpha: 0.08)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            )
                          : null,
                      color: selected ? null : (isDark ? ZapColors.surfaceDark : Colors.white),
                      borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                      border: Border.all(
                        color: selected ? ZapColors.primary : ZapColors.primary.withValues(alpha: 0.1),
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
                              : ZapColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                        ),
                        child: Center(
                          child: Opacity(
                            opacity: (s.id == 'custom' && !locked && !_customRecorded) ? 0.35 : 1.0,
                            child: Text(s.emoji, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                      ),
                      const SizedBox(width: ZapTheme.space3),

                      // Name + category
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              s.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: ZapTheme.textMd),
                            ),
                          ),
                          if (s.isPremium) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.bolt_rounded, size: 13, color: ZapColors.gold),
                          ],
                          if (s.id == 'custom' && !locked && _customRecorded) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ZapColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(ZapTheme.radiusFull),
                              ),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.check_circle_rounded, size: 11, color: ZapColors.success),
                                SizedBox(width: 3),
                                Text('Recorded', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ZapColors.success)),
                              ]),
                            ),
                          ],
                        ]),
                        Text(
                          s.id == 'custom' && !locked && !_customRecorded ? 'Tap to record' : s.category,
                          style: const TextStyle(fontSize: ZapTheme.textXs, color: ZapColors.textSecondary),
                        ),
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
                                color: playing ? ZapColors.primary : ZapColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                              ),
                              child: Icon(
                                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                color: playing ? Colors.white : ZapColors.primary,
                                size: 20,
                              ),
                            ),
                          )
                        else if (s.id == 'custom' && !locked && _customRecorded)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            GestureDetector(
                              onTap: () => _preview(s),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  color: playing ? ZapColors.primary : ZapColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                                ),
                                child: Icon(
                                  playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                  color: playing ? Colors.white : ZapColors.primary,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _reRecord,
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: ZapColors.gold.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                                ),
                                child: const Icon(Icons.fiber_manual_record, color: ZapColors.gold, size: 16),
                              ),
                            ),
                          ])
                        else if (s.id == 'custom' && !locked)
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: (isDark ? ZapColors.surfaceDark2 : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(ZapTheme.radiusMd),
                            ),
                            child: Icon(Icons.mic_rounded, color: ZapColors.primary.withValues(alpha: 0.4), size: 20),
                          ),

                        if (locked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ZapColors.gold.withValues(alpha: 0.1),
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
              ).animate(delay: Duration(milliseconds: i * 40))
                  .fadeIn(duration: 250.ms)
                  .slideY(begin: 0.08, duration: 250.ms, curve: Curves.easeOut);
            },
          ),
        ),
      ]),
    );
  }
}
