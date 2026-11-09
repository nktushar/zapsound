import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sound_widgets.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _PageData(
      title: 'Hear when your phone starts charging',
      body: 'ZapSound plays a short sound the moment you plug in or unplug, so you know the cable actually connected.',
      visual: _Visual.moments,
    ),
    _PageData(
      title: 'Tap a sound to hear it',
      body: 'Pick from the library or record your own. Whatever you tap is used right away.',
      visual: _Visual.pads,
    ),
    _PageData(
      title: 'Works with the app closed',
      body: 'Android will ask for a couple of permissions next. Allow them so ZapSound keeps listening in the background.',
      visual: _Visual.background,
    ),
  ];

  bool get _isLast => _page == _pages.length - 1;

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 420), curve: ZapTheme.emphasized);
    }
  }

  Future<void> _finish() async {
    await PrefsService.setOnboarded(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.0).animate(CurvedAnimation(parent: animation, curve: ZapTheme.emphasized)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // Step bar + skip
          Padding(
            padding: const EdgeInsets.fromLTRB(ZapTheme.space5, ZapTheme.space3, ZapTheme.space2, 0),
            child: Row(children: [
              for (var i = 0; i < _pages.length; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: ZapTheme.medium,
                    curve: ZapTheme.emphasized,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _page ? z.ink : z.surfaceHigh,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i < _pages.length - 1) const SizedBox(width: 6),
              ],
              const SizedBox(width: ZapTheme.space2),
              AnimatedOpacity(
                opacity: _isLast ? 0 : 1,
                duration: ZapTheme.fast,
                child: TextButton(
                  onPressed: _isLast ? null : _finish,
                  style: TextButton.styleFrom(foregroundColor: z.inkMuted),
                  child: const Text('Skip'),
                ),
              ),
            ]),
          ),

          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _OnboardingPage(data: _pages[i], controller: _controller, index: i),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(ZapTheme.space5, 0, ZapTheme.space5, ZapTheme.space5),
            child: ZapPrimaryButton(label: _isLast ? 'Get started' : 'Continue', onPressed: _next),
          ),
        ]),
      ),
    );
  }
}

enum _Visual { moments, pads, background }

class _PageData {
  final String title;
  final String body;
  final _Visual visual;
  const _PageData({required this.title, required this.body, required this.visual});
}

class _OnboardingPage extends StatelessWidget {
  final _PageData data;
  final PageController controller;
  final int index;
  const _OnboardingPage({required this.data, required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    // Parallax: the visual moves slower than the page, text slightly faster.
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final page = controller.hasClients && controller.position.haveDimensions
            ? (controller.page ?? controller.initialPage.toDouble())
            : 0.0;
        final delta = (index - page).clamp(-1.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Transform.translate(
                offset: Offset(-delta * 60, 0),
                child: Opacity(
                  opacity: (1 - delta.abs()).clamp(0.0, 1.0),
                  child: Center(child: _buildVisual(context)),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(delta * 30, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data.title, style: zapDisplay(34, weight: FontWeight.w800, color: z.ink, height: 1.05)),
                const SizedBox(height: ZapTheme.space3),
                Text(data.body, style: TextStyle(fontSize: ZapTheme.textMd, height: 1.5, color: z.inkMuted)),
                const SizedBox(height: ZapTheme.space8),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildVisual(BuildContext context) {
    final z = context.zap;
    switch (data.visual) {
      case _Visual.moments:
        return SizedBox(
          width: 300,
          height: 240,
          child: Stack(children: [
            Positioned(
              left: 0,
              top: 10,
              child: Transform.rotate(
                angle: -0.08,
                child: _MiniTile(hue: z.charge, icon: Icons.power_rounded, label: 'When plugged in', name: 'Power Up'),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Transform.rotate(
                angle: 0.07,
                child: _MiniTile(
                    hue: z.release, icon: Icons.power_off_rounded, label: 'When unplugged', name: 'Coin Collect'),
              ),
            ),
          ]),
        );
      case _Visual.pads:
        final names = ['Power Up', 'Ding!', 'Level Up!', 'Lightsaber', 'Marimba', 'Airhorn'];
        return SizedBox(
          width: 320,
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [
              for (var i = 0; i < names.length; i++)
                IgnorePointer(
                  child: SoundPad(
                    name: names[i],
                    icon: Icons.music_note_rounded,
                    hue: z.charge,
                    selected: i == 0,
                    playing: i == 3,
                    locked: i >= 2,
                    onTap: () {},
                  ),
                ),
            ],
          ),
        );
      case _Visual.background:
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: ZapGroup(children: [
            ZapItem(
              icon: Icons.notifications_none_rounded,
              hue: z.full,
              title: 'Allow notifications',
              subtitle: 'A quiet notification keeps ZapSound running',
            ),
            ZapItem(
              icon: Icons.battery_saver_outlined,
              hue: z.charge,
              title: 'Allow background activity',
              subtitle: 'So Android doesn\'t pause it to save battery',
            ),
            ZapItem(
              icon: Icons.mic_none_rounded,
              hue: z.release,
              title: 'Allow microphone',
              subtitle: 'Only used when you record your own sound',
            ),
          ]),
        );
    }
  }
}

class _MiniTile extends StatelessWidget {
  final ZapHue hue;
  final IconData icon;
  final String label, name;
  const _MiniTile({required this.hue, required this.icon, required this.label, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 168,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      decoration: BoxDecoration(color: hue.container, borderRadius: BorderRadius.circular(ZapTheme.radiusTile)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 24, color: hue.onContainer),
          const Spacer(),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: hue.onContainer, shape: BoxShape.circle),
            child: Icon(Icons.play_arrow_rounded, size: 22, color: hue.container),
          ),
        ]),
        const Spacer(),
        Text(label,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: hue.onContainer.withValues(alpha: 0.75))),
        const SizedBox(height: 2),
        Text(name, style: zapDisplay(22, color: hue.onContainer, height: 1.05)),
      ]),
    );
  }
}
