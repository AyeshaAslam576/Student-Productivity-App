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

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _uniCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _uniCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<AuthViewModel>();
    final ok = await vm.signUp(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
      university: _uniCtrl.text.trim().isEmpty ? null : _uniCtrl.text.trim(),
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(vm.error ?? 'Sign up failed'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _signUpWithGoogle() async {
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
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.info.withValues(alpha: 0.06),
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
                    const SizedBox(height: 16),
                    // Back button
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.textPrimary),
                      padding: EdgeInsets.zero,
                    ).animate().fadeIn(),
                    const SizedBox(height: 24),
                    Text('Create Account', style: AppTextStyles.h2)
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1),
                    const SizedBox(height: 6),
                    Text('Join thousands of students using BrainUp',
                            style: AppTextStyles.bodySmall)
                        .animate(delay: 150.ms)
                        .fadeIn(duration: 400.ms),
                    const SizedBox(height: 32),
                    BrainUpTextField(
                      label: 'Full Name',
                      controller: _nameCtrl,
                      validator: AppValidators.name,
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      textInputAction: TextInputAction.next,
                    ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 14),
                    BrainUpTextField(
                      label: 'Email',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: AppValidators.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                      textInputAction: TextInputAction.next,
                    ).animate(delay: 240.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 14),
                    BrainUpTextField(
                      label: 'University (optional)',
                      controller: _uniCtrl,
                      prefixIcon: const Icon(Icons.school_outlined),
                      textInputAction: TextInputAction.next,
                    ).animate(delay: 280.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
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
                      textInputAction: TextInputAction.next,
                    ).animate(delay: 320.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 14),
                    BrainUpTextField(
                      label: 'Confirm Password',
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      validator: (v) =>
                          AppValidators.confirmPassword(v, _passCtrl.text),
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signUp(),
                    ).animate(delay: 360.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 32),
                    BrainUpButton(
                      label: 'Create Account',
                      onTap: vm.isLoading ? null : _signUp,
                      isLoading: vm.isLoading,
                      icon: const Icon(Icons.rocket_launch_rounded,
                          color: Colors.white, size: 18),
                    ).animate(delay: 400.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 20),
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
                    ).animate(delay: 430.ms).fadeIn(),
                    const SizedBox(height: 16),
                    _SignupGoogleButton(onTap: vm.isLoading ? null : _signUpWithGoogle)
                        .animate(delay: 460.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1),
                    const SizedBox(height: 24),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Already have an account? ',
                              style: AppTextStyles.bodySmall),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text('Sign In',
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
}

class _SignupGoogleButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _SignupGoogleButton({required this.onTap});

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
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CustomPaint(painter: _GoogleGPainter()),
              ),
              const SizedBox(width: 12),
              Text(
                'Sign up with Google',
                style: AppTextStyles.button.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final segments = [
      (0.0, 90.0, const Color(0xFF4285F4)),
      (90.0, 90.0, const Color(0xFF34A853)),
      (180.0, 90.0, const Color(0xFFFBBC05)),
      (270.0, 90.0, const Color(0xFFEA4335)),
    ];
    for (final (start, sweep, color) in segments) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 1.5),
        start * 3.14159 / 180,
        sweep * 3.14159 / 180,
        false,
        Paint()
          ..color = color
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
    }
    canvas.drawLine(
      Offset(c.dx, c.dy),
      Offset(c.dx + r - 1.5, c.dy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GoogleGPainter oldDelegate) => false;
}
