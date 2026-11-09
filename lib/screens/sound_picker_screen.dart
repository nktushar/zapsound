import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sound_model.dart';
import '../services/preferences_service.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sound_widgets.dart';
import 'premium_screen.dart';
import 'record_sound_screen.dart';

/// Sound library as a grid of sampler pads. Tapping a pad plays it and, if
/// it's available, makes it the sound for this moment straight away (like a
/// ringtone picker) — there's no separate save step. Pro sounds can still be
/// previewed; tapping one shows an unlock bar.
class SoundPickerScreen extends StatefulWidget {
  final SoundTarget target;
  final String currentId;
  final bool isPremium;
  const SoundPickerScreen({super.key, required this.target, required this.currentId, required this.isPremium});

  @override
  State<SoundPickerScreen> createState() => _SoundPickerScreenState();
}

class _SoundPickerScreenState extends State<SoundPickerScreen> {
  late String _selectedId;
  late bool _isPremium;
  String _category = 'All';
  String? _playingId;
  bool _customRecorded = false;
  SoundModel? _lockedPick; // last Pro sound previewed by a free user

  // Custom recordings only exist for the two charger events; the battery-full
  // alert picks from the built-in library.
  bool get _isPlugIn => widget.target == SoundTarget.plugIn;
  bool get _supportsCustom => widget.target != SoundTarget.batteryFull;

  static final _custom = ZapSoundLibrary.all.firstWhere((s) => s.id == 'custom');

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentId;
    _isPremium = widget.isPremium;
    _loadCustomRecorded();
  }

  @override
  void dispose() {
    if (_playingId != null) AudioService.stop();
    super.dispose();
  }

  Future<void> _loadCustomRecorded() async {
    if (!_supportsCustom) return;
    final path = _isPlugIn ? await PrefsService.getCustomIn() : await PrefsService.getCustomOut();
    if (mounted) setState(() => _customRecorded = path != null);
  }

  List<String> get _categories => ZapSoundLibrary.categories.where((c) => c != 'Custom').toList();

  /// Library sounds (no custom) for the active filter, grouped by category,
  /// free sounds first inside each group.
  Map<String, List<SoundModel>> get _groups {
    final out = <String, List<SoundModel>>{};
    for (final s in ZapSoundLibrary.all) {
      if (s.id == 'custom') continue;
      if (_category != 'All' && s.category != _category) continue;
      out.putIfAbsent(s.category, () => []).add(s);
    }
    for (final list in out.values) {
      list.sort((a, b) => (a.isPremium ? 1 : 0) - (b.isPremium ? 1 : 0));
    }
    return {for (final c in _categories) if (out.containsKey(c)) c: out[c]!};
  }

  String get _title => switch (widget.target) {
        SoundTarget.plugIn => 'When plugged in',
        SoundTarget.plugOut => 'When unplugged',
        SoundTarget.batteryFull => 'Battery full',
      };

  Future<void> _play(SoundModel s) async {
    if (s.id == 'custom') {
      final path = _isPlugIn ? await PrefsService.getCustomIn() : await PrefsService.getCustomOut();
      if (path == null) return;
      setState(() => _playingId = s.id);
      await AudioService.playFile(path);
    } else {
      if (s.assetPath.isEmpty) return;
      setState(() => _playingId = s.id);
      await AudioService.playAsset(s.assetPath);
    }
    // A newer preview may have started meanwhile; only clear our own.
    if (mounted && _playingId == s.id) setState(() => _playingId = null);
  }

  Future<void> _save(SoundModel s) async {
    setState(() => _selectedId = s.id);
    switch (widget.target) {
      case SoundTarget.plugIn:
        await PrefsService.setPlugIn(s.id);
        await PrefsService.setPlugInFile(s.fileName);
        break;
      case SoundTarget.plugOut:
        await PrefsService.setPlugOut(s.id);
        await PrefsService.setPlugOutFile(s.fileName);
        break;
      case SoundTarget.batteryFull:
        await PrefsService.setBatteryFullSound(s.id, s.fileName);
        break;
    }
  }

  Future<void> _onPad(SoundModel s) async {
    if (_playingId == s.id) {
      // Stopping resolves the awaiting play(), which clears the state.
      await AudioService.stop();
      return;
    }
    HapticFeedback.selectionClick();
    final locked = s.isPremium && !_isPremium;
    setState(() => _lockedPick = locked ? s : null);
    if (!locked) await _save(s);
    await _play(s);
  }

  Future<void> _onCustom() async {
    if (!_isPremium) return _openPremium();
    if (!_customRecorded) return _record();
    await _onPad(_custom);
  }

  Future<void> _openPremium() async {
    if (_playingId != null) await AudioService.stop();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
    final prem = await PrefsService.isPremium();
    if (mounted) {
      setState(() {
        _isPremium = prem;
        if (prem) _lockedPick = null;
      });
    }
  }

  Future<void> _record() async {
    if (_playingId != null) await AudioService.stop();
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RecordSoundScreen(isPlugIn: _isPlugIn)),
    );
    if (saved == true) {
      // RecordSoundScreen already persisted it as this moment's sound.
      await _loadCustomRecorded();
      if (mounted) setState(() => _selectedId = 'custom');
    }
  }

  Future<void> _removeRecording() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your recording?'),
        content: const Text('The recording is removed from this phone. You can record a new one anytime.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: context.zap.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final path = _isPlugIn ? await PrefsService.getCustomIn() : await PrefsService.getCustomOut();
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    if (_isPlugIn) {
      await PrefsService.clearCustomIn();
      if (_selectedId == 'custom') {
        await PrefsService.setPlugIn('s1');
        await PrefsService.setPlugInFile('power_up');
        _selectedId = 's1';
      }
    } else {
      await PrefsService.clearCustomOut();
      if (_selectedId == 'custom') {
        await PrefsService.setPlugOut('s2');
        await PrefsService.setPlugOutFile('coin');
        _selectedId = 's2';
      }
    }
    await _loadCustomRecorded();
  }

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    final hue = hueForTarget(z, widget.target);
    final groups = _groups;
    final showCustom = _supportsCustom && _category == 'All';
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar.large(title: Text(_title)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(ZapTheme.space4, 0, ZapTheme.space4, ZapTheme.space2),
            child: Text(
              'Tap a sound to hear it. It\'s used right away.',
              style: TextStyle(fontSize: ZapTheme.textSm, color: z.inkMuted),
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedHeader(
            height: 60,
            color: z.bg,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space4, vertical: 10),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: ZapTheme.space2),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                return _FilterChip(
                  label: cat,
                  selected: cat == _category,
                  onTap: () => setState(() => _category = cat),
                );
              },
            ),
          ),
        ),
        if (showCustom) ...[
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: ZapTheme.space4),
            sliver: SliverToBoxAdapter(child: ZapSectionLabel('Your recording')),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space4),
            sliver: SliverToBoxAdapter(child: _buildCustomPad(hue)),
          ),
        ],
        for (final entry in groups.entries) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space4),
            sliver: SliverToBoxAdapter(child: ZapSectionLabel(entry.key)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space4),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 96,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final s = entry.value[i];
                  return SoundPad(
                    name: s.name,
                    icon: categoryIcon(s.category),
                    hue: hue,
                    selected: s.id == _selectedId,
                    playing: s.id == _playingId,
                    locked: s.isPremium && !_isPremium,
                    onTap: () => _onPad(s),
                  );
                },
                childCount: entry.value.length,
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: ZapTheme.space8 + bottomInset)),
      ]),
      bottomNavigationBar: AnimatedSwitcher(
        duration: ZapTheme.medium,
        switchInCurve: ZapTheme.emphasized,
        transitionBuilder: (c, a) => SizeTransition(
          sizeFactor: a,
          alignment: Alignment.topCenter,
          child: FadeTransition(opacity: a, child: c),
        ),
        child: _lockedPick == null ? const SizedBox.shrink() : _buildUnlockBar(z, _lockedPick!),
      ),
    );
  }

  Widget _buildUnlockBar(ZapTokens z, SoundModel s) {
    return SafeArea(
      key: ValueKey(s.id),
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(ZapTheme.space3, 0, ZapTheme.space3, ZapTheme.space3),
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
        decoration: BoxDecoration(color: z.ink, borderRadius: BorderRadius.circular(ZapTheme.radiusGroup)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${s.name} is a Pro sound',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: ZapTheme.textMd, fontWeight: FontWeight.w700, color: z.onInk)),
              Text('Unlock every sound with one purchase',
                  style: TextStyle(fontSize: ZapTheme.textXs, color: z.onInk.withValues(alpha: 0.7))),
            ]),
          ),
          const SizedBox(width: ZapTheme.space2),
          FilledButton(
            onPressed: _openPremium,
            style: FilledButton.styleFrom(backgroundColor: z.onInk, foregroundColor: z.ink),
            child: const Text('Unlock'),
          ),
        ]),
      ),
    );
  }

  Widget _buildCustomPad(ZapHue hue) {
    final z = context.zap;
    final selected = _selectedId == 'custom';
    final playing = _playingId == 'custom';
    final ready = _isPremium && _customRecorded;
    final fg = selected ? hue.onContainer : z.ink;

    return Pressable(
      onTap: _onCustom,
      child: AnimatedContainer(
        duration: ZapTheme.medium,
        curve: ZapTheme.emphasized,
        height: 76,
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
        decoration: BoxDecoration(
          color: selected ? hue.container : z.surface,
          borderRadius: BorderRadius.circular(ZapTheme.radiusPad),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: selected ? hue.onContainer : hue.container, shape: BoxShape.circle),
            child: Center(
              child: playing
                  ? EqualizerBars(color: selected ? hue.container : hue.onContainer, size: 16)
                  : Icon(Icons.mic_rounded, size: 20, color: selected ? hue.container : hue.onContainer),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ready ? 'My recording' : 'Record your own',
                  style: zapDisplay(17, weight: FontWeight.w600, color: fg)),
              Text(
                ready ? 'Saved on this phone' : 'Your voice or any sound around you',
                style: TextStyle(fontSize: ZapTheme.textXs, color: selected ? fg.withValues(alpha: 0.7) : z.inkMuted),
              ),
            ]),
          ),
          if (!_isPremium)
            const Padding(padding: EdgeInsets.only(right: 8), child: ProTag())
          else if (!ready)
            Icon(Icons.chevron_right_rounded, color: z.inkMuted)
          else
            PopupMenuButton<String>(
              tooltip: 'Recording options',
              icon: Icon(Icons.more_vert_rounded, color: fg),
              onSelected: (v) => v == 'redo' ? _record() : _removeRecording(),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'redo', child: Text('Record again')),
                PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: z.danger))),
              ],
            ),
        ]),
      ),
    );
  }
}

class _PinnedHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Color color;
  final Widget child;
  _PinnedHeader({required this.height, required this.color, required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: color, child: child);

  @override
  bool shouldRebuild(_PinnedHeader old) => true;
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ZapTheme.fast,
          curve: ZapTheme.emphasized,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? z.ink : z.surface,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: ZapTheme.textSm,
                fontWeight: FontWeight.w700,
                color: selected ? z.onInk : z.ink,
              )),
        ),
      ),
    );
  }
}
