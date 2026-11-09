import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/sound_model.dart';
import '../theme/app_theme.dart';

/// Icon for a sound category — one consistent icon set instead of emoji.
IconData categoryIcon(String category) => switch (category) {
      'Classic' => Icons.notifications_none_rounded,
      'Funny' => Icons.sentiment_satisfied_alt_rounded,
      'Gaming' => Icons.sports_esports_outlined,
      'Sci-Fi' => Icons.rocket_launch_outlined,
      'Retro' => Icons.videogame_asset_outlined,
      'Chill' => Icons.spa_outlined,
      'Custom' => Icons.mic_none_rounded,
      _ => Icons.music_note_rounded,
    };

/// Tonal family for a sound moment.
ZapHue hueForTarget(ZapTokens z, SoundTarget t) => switch (t) {
      SoundTarget.plugIn => z.charge,
      SoundTarget.plugOut => z.release,
      SoundTarget.batteryFull => z.full,
    };

/// Decorative hue per category (paywall sound chips).
ZapHue hueForCategory(ZapTokens z, String category) => switch (category) {
      'Funny' => z.release,
      'Sci-Fi' || 'Classic' => z.full,
      'Retro' || 'Gaming' => z.guard,
      _ => z.charge,
    };

/// Three bouncing bars shown while a sound is playing.
class EqualizerBars extends StatefulWidget {
  final Color color;
  final double size;
  const EqualizerBars({super.key, required this.color, this.size = 18});

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final barW = s / 5;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: barW,
                height: s * (0.3 + 0.7 * (math.sin((_c.value + i * 0.27) * 2 * math.pi) * 0.5 + 0.5)),
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(barW / 2)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Round play/stop toggle. [fg]/[bg] default to ink on transparent (outlined).
class PlayButton extends StatelessWidget {
  final bool playing;
  final VoidCallback? onPressed;
  final double size;
  final Color? fill;
  final Color? iconColor;

  const PlayButton({super.key, required this.playing, this.onPressed, this.size = 44, this.fill, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    final bg = fill ?? (playing ? z.ink : Colors.transparent);
    final fg = iconColor ?? (playing ? z.onInk : z.ink);
    return Semantics(
      button: true,
      label: playing ? 'Stop preview' : 'Play preview',
      child: Pressable(
        onTap: onPressed,
        pressedScale: 0.9,
        child: AnimatedContainer(
          duration: ZapTheme.fast,
          curve: ZapTheme.emphasized,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: fill == null && !playing ? Border.all(color: z.line, width: 1.5) : null,
          ),
          child: AnimatedSwitcher(
            duration: ZapTheme.fast,
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(
              playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              key: ValueKey(playing),
              size: size * 0.5,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sampler-style pad used in the sound picker: tap to hear and choose.
/// Selected pads fill with the moment's [hue].
class SoundPad extends StatelessWidget {
  final String name;
  final IconData icon;
  final ZapHue hue;
  final bool selected;
  final bool playing;
  final bool locked;
  final VoidCallback onTap;

  const SoundPad({
    super.key,
    required this.name,
    required this.icon,
    required this.hue,
    required this.selected,
    required this.playing,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    final fg = selected ? hue.onContainer : z.ink;
    final sub = selected ? hue.onContainer.withValues(alpha: 0.7) : z.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: '$name${locked ? ', Pro sound' : ''}',
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ZapTheme.medium,
          curve: ZapTheme.emphasized,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected ? hue.container : z.surface,
            borderRadius: BorderRadius.circular(ZapTheme.radiusPad),
          ),
          // Ring while previewing an unselected pad; foreground so it doesn't shift layout.
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZapTheme.radiusPad),
            border: Border.all(color: playing && !selected ? hue.strong : Colors.transparent, width: 2),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AnimatedSwitcher(
                duration: ZapTheme.fast,
                child: playing
                    ? EqualizerBars(key: const ValueKey('eq'), color: selected ? hue.onContainer : hue.strong)
                    : Icon(icon, key: const ValueKey('ic'), size: 20, color: sub),
              ),
              const Spacer(),
              if (locked)
                Icon(Icons.lock_outline_rounded, size: 17, color: z.inkMuted)
              else
                AnimatedScale(
                  duration: ZapTheme.fast,
                  curve: Curves.easeOutBack,
                  scale: selected ? 1 : 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: hue.onContainer, shape: BoxShape.circle),
                    child: Icon(Icons.check_rounded, size: 15, color: hue.container),
                  ),
                ),
            ]),
            const Spacer(),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: zapDisplay(17, weight: FontWeight.w600, color: fg),
            ),
          ]),
        ),
      ),
    );
  }
}
