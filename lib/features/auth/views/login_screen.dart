import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_text_field.dart';
import '../../../core/utils/validators.dart';
import '../viewmodels/auth_viewmodel.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<AuthViewModel>();
    final ok = await vm.signIn(_emailCtrl.text.trim(), _passCtrl.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(vm.error ?? 'Sign in failed'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Accent blur blob
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accent.withValues(alpha: 0.06),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    // Logo
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.accentGradient,
                          ),
                          child: const Icon(Icons.psychology_rounded,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Text('BrainUp', style: AppTextStyles.h3),
                      ],
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 40),
                    Text('Welcome back', style: AppTextStyles.h2)
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1),
                    const SizedBox(height: 6),
                    Text('Sign in to continue your journey',
                            style: AppTextStyles.bodySmall)
                        .animate(delay: 150.ms)
                        .fadeIn(duration: 400.ms),
                    const SizedBox(height: 36),
                    BrainUpTextField(
                      label: 'Email',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: AppValidators.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                      textInputAction: TextInputAction.next,
                    ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 14),
                    BrainUpTextField(
                      label: 'Password',
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      validator: AppValidators.password,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signIn(),
                    ).animate(delay: 250.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPassword(),
                        child: Text('Forgot password?',
                            style: AppTextStyles.accentText),
                      ),
                    ).animate(delay: 300.ms).fadeIn(),
                    const SizedBox(height: 24),
                    BrainUpButton(
                      label: 'Sign In',
                      onTap: vm.isLoading ? null : _signIn,
                      isLoading: vm.isLoading,
                    )
                        .animate(delay: 350.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1),
                    const SizedBox(height: 28),
                    // Divider
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(color: AppColors.surfaceBorder)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or continue with',
                              style: AppTextStyles.caption),
                        ),
                        const Expanded(
                            child: Divider(color: AppColors.surfaceBorder)),
                      ],
                    ).animate(delay: 400.ms).fadeIn(),
                    const SizedBox(height: 20),
                    // Google Sign-in button
                    const _GoogleSignInButton()
                        .animate(delay: 450.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1),
                    const SizedBox(height: 32),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Don't have an account? ",
                              style: AppTextStyles.bodySmall),
                          GestureDetector(
                            onTap: () => context.go('/signup'),
                            child: Text('Sign Up',
                                style: AppTextStyles.accentText),
                          ),
                        ],
                      ),
                    ).animate(delay: 500.ms).fadeIn(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPassword() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: BrainUpTextField(
          label: 'Email',
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.email_outlined),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final vm = context.read<AuthViewModel>();
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);
              final sent = await vm.resetPassword(ctrl.text.trim());
              navigator.pop();
              messenger.showSnackBar(SnackBar(
                content: Text(
                  sent ? 'Password reset email sent' : 'Failed to send reset email',
                ),
              ));
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

class _GoogleSignInButton extends StatefulWidget {
  const _GoogleSignInButton();

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _loading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    final vm = context.read<AuthViewModel>();
    final ok = await vm.signInWithGoogle();
    if (!ok && mounted && vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(vm.error!),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: _loading ? null : _handleGoogleSignIn,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent),
                )
              else ...[
                // Google 'G' icon using coloured letters
                _GoogleGIcon(),
                const SizedBox(width: 12),
                Text(
                  'Sign in with Google',
                  style: AppTextStyles.button.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal coloured 'G' that resembles the Google logo without external SVG.
class _GoogleGIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Draw coloured arc segments
    final segments = [
      (0.0, 90.0, const Color(0xFF4285F4)),    // blue
      (90.0, 90.0, const Color(0xFF34A853)),   // green
      (180.0, 90.0, const Color(0xFFFBBC05)),  // yellow
      (270.0, 90.0, const Color(0xFFEA4335)),  // red
    ];

    for (final (start, sweep, color) in segments) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 1.5),
        start * 3.14159 / 180,
        sweep * 3.14159 / 180,
        false,
        paint,
      );
    }

    // White horizontal bar for the 'G' crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(c.dx, c.dy),
      Offset(c.dx + r - 1.5, c.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_GoogleGPainter oldDelegate) => false;
}

