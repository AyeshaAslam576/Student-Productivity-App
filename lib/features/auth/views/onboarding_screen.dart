import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brainup_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  List<_OnboardingPage> _buildPages(BuildContext context) {
    final colors = context.colors;
    return [
      _OnboardingPage(
        icon: Icons.dashboard_rounded,
        iconColor: colors.accent,
        title: 'Your academic life,\norganized',
        body: 'Manage tasks, timetables, and deadlines all in one beautiful place.',
      ),
      _OnboardingPage(
        icon: Icons.auto_awesome_rounded,
        iconColor: colors.info,
        title: 'AI tools built\nfor students',
        body: 'Summarize lectures, check grammar, and chat with your AI study assistant.',
      ),
      _OnboardingPage(
        icon: Icons.show_chart_rounded,
        iconColor: colors.success,
        title: 'Track grades.\nOwn your future.',
        body: 'Calculate your CGPA, monitor attendance, and stay ahead of every deadline.',
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next(int pagesLength) {
    if (_page < pagesLength - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pages = _buildPages(context);
    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  colors.accent.withValues(alpha: 0.05),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: pages.length,
                    itemBuilder: (_, i) => pages[i],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding, 0, AppSpacing.screenPadding, 40),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(pages.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _page ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? colors.accent
                                  : colors.textMuted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),
                      BrainUpButton(
                        label: _page == pages.length - 1 ? 'Get Started' : 'Next',
                        onTap: () => _next(pages.length),
                        icon: Icon(
                          _page == pages.length - 1
                              ? Icons.rocket_launch_rounded
                              : Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text('Skip', style: context.text.bodySmall),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.08),
              border: Border.all(color: iconColor.withValues(alpha: 0.15), width: 1),
            ),
            child: Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 64, color: iconColor),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
          const SizedBox(height: 48),
          Text(
            title,
            style: context.text.h2,
            textAlign: TextAlign.center,
          )
              .animate(delay: 150.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1),
          const SizedBox(height: 16),
          Text(
            body,
            style: context.text.bodySmall.copyWith(
              fontSize: 15,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          )
              .animate(delay: 250.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1),
        ],
      ),
    );
  }
}
