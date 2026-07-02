import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
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
      icon: Icons.bolt_rounded,
      title: 'Welcome to ZapSound',
      subtitle: 'Your charger just got a personality',
    ),
    _PageData(
      icon: Icons.music_note_rounded,
      title: 'Pick your sounds',
      subtitle: '50+ funny sounds for plug and unplug',
    ),
    _PageData(
      icon: Icons.power_rounded,
      title: 'Works automatically',
      subtitle: 'Just plug in your charger and enjoy',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await PrefsService.setOnboarded(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: ZapTheme.space4, top: ZapTheme.space3),
                child: AnimatedOpacity(
                  opacity: isLast ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: isLast ? null : _finish,
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: ZapColors.textSecondary, fontSize: ZapTheme.textSm),
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _OnboardingPage(
                  data: _pages[i],
                  isDark: isDark,
                ),
              ),
            ),

            // Dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? ZapColors.primary
                        : ZapColors.primary.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(ZapTheme.radiusFull),
                  ),
                ),
              ),
            ),

            const SizedBox(height: ZapTheme.space6),

            // Action button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space5),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZapColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ZapTheme.radiusLg),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      isLast ? 'Get Started' : 'Next',
                      key: ValueKey(isLast),
                      style: const TextStyle(
                        fontSize: ZapTheme.textMd,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: ZapTheme.space8),
          ],
        ),
      ),
    );
  }
}

class _PageData {
  final IconData icon;
  final String title;
  final String subtitle;
  const _PageData({required this.icon, required this.title, required this.subtitle});
}

class _OnboardingPage extends StatelessWidget {
  final _PageData data;
  final bool isDark;
  const _OnboardingPage({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZapTheme.space8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji blob
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ZapColors.primary.withOpacity(0.12),
              border: Border.all(
                color: ZapColors.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                data.icon,
                size: 60,
                color: ZapColors.primary,
              ),
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1.0, 1.0),
                duration: 550.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 300.ms),

          const SizedBox(height: ZapTheme.space8),

          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: ZapTheme.text2xl,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          )
              .animate()
              .fadeIn(delay: 150.ms, duration: 400.ms)
              .slideY(begin: 0.2, end: 0, delay: 150.ms, duration: 400.ms, curve: Curves.easeOut),

          const SizedBox(height: ZapTheme.space3),

          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: ZapTheme.textMd,
              color: ZapColors.textSecondary,
              height: 1.5,
            ),
          )
              .animate()
              .fadeIn(delay: 260.ms, duration: 400.ms)
              .slideY(begin: 0.2, end: 0, delay: 260.ms, duration: 400.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }
}
