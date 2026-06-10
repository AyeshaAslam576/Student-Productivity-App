import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/brainup_logo.dart';
import '../viewmodels/auth_viewmodel.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2600), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final auth = context.read<AuthViewModel>();
    if (auth.isAuthenticated) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.accent.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.info.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrainUpLogo(size: 96)
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack),
                const SizedBox(height: 20),
                Text('BrainUp', style: context.text.h1)
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.2, curve: Curves.easeOut),
                const SizedBox(height: 8),
                Text('Study smarter.',
                        style: context.text.bodySmall.copyWith(fontSize: 16))
                    .animate(delay: 500.ms)
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.2, curve: Curves.easeOut),
                const SizedBox(height: 40),
                Container(
                  width: 120,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: colors.surfaceBorder,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: colors.accentGradient,
                      ),
                    )
                        .animate(delay: 700.ms)
                        .custom(
                          duration: 1800.ms,
                          curve: Curves.easeInOut,
                          builder: (context, value, child) => FractionallySizedBox(
                            widthFactor: value,
                            child: child,
                          ),
                        ),
                  ),
                ).animate(delay: 700.ms).fadeIn(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
