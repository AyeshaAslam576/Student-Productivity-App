import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/local_storage_service.dart';
import '../../../core/services/theme_provider.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brainup_card.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_logo.dart';
import '../../../core/widgets/brainup_text_field.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../tasks/viewmodels/task_viewmodel.dart';
import '../../cgpa/viewmodels/cgpa_viewmodel.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingPhoto = false;
  bool _lectureNotifs = true;
  bool _taskNotifs = true;
  bool _studyNotifs = false;

  @override
  void initState() {
    super.initState();
    _loadNotifPrefs();
  }

  Future<void> _loadNotifPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _lectureNotifs = prefs.getBool('notif_lectures') ?? true;
        _taskNotifs = prefs.getBool('notif_tasks') ?? true;
        _studyNotifs = prefs.getBool('notif_study') ?? false;
      });
    }
  }

  Future<void> _showPhotoOptions() async {
    final auth = context.read<AuthViewModel>();
    final user = auth.user;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
            24, 12, 24, MediaQuery.of(ctx).padding.bottom + 32),
        decoration: BoxDecoration(
          color: ctx.colors.surfaceCard,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 28),
              decoration: BoxDecoration(
                color: ctx.colors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Current photo preview ──────────────────────────────────
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: user?.photoBase64 == null
                    ? ctx.colors.accentGradient
                    : null,
                color: user?.photoBase64 != null
                    ? ctx.colors.surfaceBorder
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: ctx.colors.accent.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: user?.photoBase64 != null
                  ? Image.memory(
                      Uint8List.fromList(
                        LocalStorageService.base64ToBytes(user!.photoBase64!),
                      ),
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        user?.initials ?? '?',
                        style: ctx.text.h2.copyWith(
                          color: Colors.white,
                          fontSize: 38,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Text(user?.name ?? 'Profile Photo', style: ctx.text.h4),
            const SizedBox(height: 4),
            Text(
              user?.photoBase64 != null
                  ? 'Tap an option below to update your photo'
                  : 'No photo set — add one below',
              style: ctx.text.caption.copyWith(color: ctx.colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // ── Options ───────────────────────────────────────────────
            _PhotoOptionTile(
              icon: Icons.camera_alt_rounded,
              label: 'Take Photo',
              color: ctx.colors.accent,
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
            _PhotoOptionTile(
              icon: Icons.photo_library_rounded,
              label: 'Choose from Gallery',
              color: ctx.colors.accent,
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (user?.photoBase64 != null) ...[
              const SizedBox(height: 10),
              _PhotoOptionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Remove Photo',
                color: ctx.colors.error,
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _uploadingPhoto = true);
                  try {
                    final profileVm = context.read<ProfileViewModel>();
                    final updated = auth.user!.copyWith(photoBase64: null);
                    await profileVm.updateProfile(updated);
                    auth.setUser(updated);
                    await auth.reloadUser();
                  } finally {
                    if (mounted) setState(() => _uploadingPhoto = false);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final file = File(picked.path);
      final base64 = await LocalStorageService.imageToBase64(file);
      if (!mounted) return;
      final auth = context.read<AuthViewModel>();
      final profileVm = context.read<ProfileViewModel>();
      final updated = auth.user!.copyWith(photoBase64: base64);
      await profileVm.updateProfile(updated);
      auth.setUser(updated);
      await auth.reloadUser();
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final taskVm = context.watch<TaskViewModel>();
    final cgpaVm = context.watch<CgpaViewModel>();
    final homeVm = context.watch<HomeViewModel>();
    final user = auth.user;
    final isEmailUser = auth.isEmailPasswordUser;

    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: ListView(
          children: [
            // ─── Header ───
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Avatar with photo picker
                  GestureDetector(
                    onTap: _uploadingPhoto ? null : _showPhotoOptions,
                    child: Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: user?.photoBase64 == null
                                ? colors.accentGradient
                                : null,
                            color: user?.photoBase64 != null
                                ? colors.surfaceCard
                                : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _uploadingPhoto
                              ? Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.accent,
                                  ),
                                )
                              : user?.photoBase64 != null
                                  ? Image.memory(
                                      Uint8List.fromList(
                                        LocalStorageService.base64ToBytes(
                                            user!.photoBase64!),
                                      ),
                                      key: ValueKey(user.photoBase64),
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    )
                                  : Center(
                                      child: Text(
                                        user?.initials ?? '?',
                                        style: context.text.h2
                                            .copyWith(color: Colors.white),
                                      ),
                                    ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: colors.surface, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).scale(
                      begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
                  const SizedBox(height: 14),
                  Text(user?.name ?? 'Student', style: context.text.h3)
                      .animate(delay: 100.ms).fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: 4),
                  Text(user?.university ?? 'University',
                          style: context.text.bodySmall)
                      .animate(delay: 140.ms).fadeIn(),
                  Text(user?.email ?? '', style: context.text.caption)
                      .animate(delay: 160.ms).fadeIn(),
                  const SizedBox(height: 20),
                  // Stats row
                  BrainUpCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          value: '${taskVm.completedThisWeek}',
                          label: 'Tasks Done',
                        ),
                        _Divider(),
                        _StatItem(
                          value: '${homeVm.studyHoursToday.toStringAsFixed(1)}h',
                          label: 'Study Hours',
                        ),
                        _Divider(),
                        _StatItem(
                          value: cgpaVm.semesters.isEmpty
                              ? 'N/A'
                              : cgpaVm.cgpa.toStringAsFixed(2),
                          label: 'CGPA',
                        ),
                        _Divider(),
                        _StatItem(
                          value: '${homeVm.studyStreakDays}',
                          label: 'Day Streak',
                        ),
                      ],
                    ),
                  ).animate(delay: 200.ms).fadeIn(duration: 300.ms).slideY(begin: 0.05),
                ],
              ),
            ),

            // ─── Settings Sections ───
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('Account'),
                  BrainUpCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SettingTile(
                          icon: Icons.person_outline_rounded,
                          title: 'Edit Profile',
                          onTap: () => _showEditProfileSheet(context),
                        ),
                        if (isEmailUser) ...[
                          const _Separator(),
                          _SettingTile(
                            icon: Icons.lock_outline_rounded,
                            title: 'Change Password',
                            onTap: () => _showChangePasswordSheet(context),
                          ),
                        ],
                        const _Separator(),
                        _SettingTile(
                          icon: Icons.logout_rounded,
                          title: 'Sign Out',
                          color: colors.error,
                          onTap: () => _confirmSignOut(context, auth),
                        ),
                      ],
                    ),
                  ).animate(delay: 250.ms).fadeIn(duration: 300.ms).slideY(begin: 0.05),

                  const SizedBox(height: 20),
                  BrainUpCard(
                    child: Builder(
                      builder: (context) {
                        final mode = context.watch<ThemeProvider>().mode;
                        final modeLabel = switch (mode) {
                          AppThemeMode.system => 'System',
                          AppThemeMode.light => 'Light',
                          AppThemeMode.dark => 'Dark',
                        };
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Appearance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<AppThemeMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: AppThemeMode.system,
                                    icon: Icon(Icons.auto_mode, size: 20),
                                    tooltip: 'System',
                                  ),
                                  ButtonSegment(
                                    value: AppThemeMode.light,
                                    icon: Icon(Icons.light_mode, size: 20),
                                    tooltip: 'Light',
                                  ),
                                  ButtonSegment(
                                    value: AppThemeMode.dark,
                                    icon: Icon(Icons.dark_mode, size: 20),
                                    tooltip: 'Dark',
                                  ),
                                ],
                                selected: {mode},
                                onSelectionChanged: (val) => context
                                    .read<ThemeProvider>()
                                    .setMode(val.first),
                                showSelectedIcon: false,
                                style: SegmentedButton.styleFrom(
                                  selectedBackgroundColor: colors.accentSoft,
                                  selectedForegroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              modeLabel,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  _SectionTitle('Notifications'),
                  BrainUpCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _ToggleTile(
                          icon: Icons.notifications_outlined,
                          title: 'Lecture Reminders',
                          value: _lectureNotifs,
                          onChanged: (v) async {
                            setState(() => _lectureNotifs = v);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('notif_lectures', v);
                          },
                        ),
                        const _Separator(),
                        _ToggleTile(
                          icon: Icons.assignment_outlined,
                          title: 'Task Reminders',
                          value: _taskNotifs,
                          onChanged: (v) async {
                            setState(() => _taskNotifs = v);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('notif_tasks', v);
                          },
                        ),
                        const _Separator(),
                        _ToggleTile(
                          icon: Icons.timer_outlined,
                          title: 'Study Reminders',
                          value: _studyNotifs,
                          onChanged: (v) async {
                            setState(() => _studyNotifs = v);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('notif_study', v);
                          },
                        ),
                      ],
                    ),
                  ).animate(delay: 300.ms).fadeIn(duration: 300.ms).slideY(begin: 0.05),

                  const SizedBox(height: 20),
                  _SectionTitle('About'),
                  BrainUpCard(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        const BrainUpLogo(size: 64),
                        const SizedBox(height: 12),
                        Text('BrainUp', style: context.text.h4),
                        Text('Study smarter.', style: context.text.caption),
                        const SizedBox(height: 16),
                        const _Separator(),
                        _SettingTile(
                          icon: Icons.info_outline_rounded,
                          title: 'App Version',
                          trailing:
                              Text('1.0.0', style: context.text.caption),
                          onTap: () {},
                        ),
                        const _Separator(),
                        _SettingTile(
                          icon: Icons.star_outline_rounded,
                          title: 'Rate App',
                          onTap: () {},
                        ),
                        const _Separator(),
                        _SettingTile(
                          icon: Icons.bug_report_outlined,
                          title: 'Report Bug',
                          onTap: () {},
                        ),
                        const _Separator(),
                        _SettingTile(
                          icon: Icons.delete_outline_rounded,
                          title: 'Clear Cache',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cache cleared')),
                            );
                          },
                        ),
                      ],
                    ),
                  ).animate(delay: 350.ms).fadeIn(duration: 300.ms).slideY(begin: 0.05),

                  const SizedBox(height: 32),
                  BrainUpButton.secondary(
                    label: 'Sign Out',
                    onTap: () => _confirmSignOut(context, auth),
                    icon: Icon(Icons.logout_rounded,
                        color: colors.accent, size: 18),
                  ).animate(delay: 450.ms).fadeIn(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AuthViewModel auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out', style: ctx.text.h4),
        content: Text('Are you sure you want to sign out?',
            style: ctx.text.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              auth.signOut();
            },
            child: Text('Sign Out',
                style: ctx.text.accentText.copyWith(color: ctx.colors.error)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    final auth = context.read<AuthViewModel>();
    final user = auth.user!;
    final nameCtrl = TextEditingController(text: user.name);
    final uniCtrl = TextEditingController(text: user.university ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            color: ctx.colors.surfaceCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: ctx.colors.surfaceBorder,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Edit Profile', style: ctx.text.h4),
                const SizedBox(height: 20),
                BrainUpTextField(
                  controller: nameCtrl,
                  label: 'Full Name',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                BrainUpTextField(
                  controller: uniCtrl,
                  label: 'University',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: BrainUpButton(
                    label: 'Save Changes',
                    onTap: () async {
                      if (!formKey.currentState!.validate()) return;
                      final profileVm = context.read<ProfileViewModel>();
                      final updated = user.copyWith(
                        name: nameCtrl.text.trim(),
                        university: uniCtrl.text.trim(),
                      );
                      final ok = await profileVm.updateProfile(updated);
                      if (ok && ctx.mounted) {
                        await auth.reloadUser();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile updated!')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            color: ctx.colors.surfaceCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: ctx.colors.surfaceBorder,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Change Password', style: ctx.text.h4),
                const SizedBox(height: 20),
                BrainUpTextField(
                  controller: currentCtrl,
                  label: 'Current Password',
                  obscureText: true,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                BrainUpTextField(
                  controller: newCtrl,
                  label: 'New Password',
                  obscureText: true,
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 14),
                BrainUpTextField(
                  controller: confirmCtrl,
                  label: 'Confirm New Password',
                  obscureText: true,
                  validator: (v) =>
                      v != newCtrl.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: BrainUpButton(
                    label: 'Update Password',
                    onTap: () async {
                      if (!formKey.currentState!.validate()) return;
                      final auth = ctx.read<AuthViewModel>();
                      try {
                        await auth.changePassword(
                          currentPassword: currentCtrl.text,
                          newPassword: newCtrl.text,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password updated!')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PhotoOptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.surfaceBorder, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: context.text.body.copyWith(
                  color: color == colors.error
                      ? colors.error
                      : colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  color: colors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: context.text.h4
                .copyWith(fontSize: 18, color: context.colors.accent)),
        const SizedBox(height: 2),
        Text(label, style: context.text.caption.copyWith(fontSize: 10)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 32, color: context.colors.surfaceBorder);
  }
}

class _Separator extends StatelessWidget {
  const _Separator();
  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 0,
        indent: 52,
        endIndent: 0,
        color: context.colors.surfaceBorder);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: context.text.label
            .copyWith(letterSpacing: 1.2, color: context.colors.textMuted),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = color ?? colors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? colors.textSecondary, size: 22),
      title: Text(title, style: context.text.body.copyWith(color: c)),
      trailing: trailing ??
          Icon(Icons.chevron_right_rounded,
              color: colors.textMuted, size: 20),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.colors.textSecondary, size: 22),
      title: Text(title, style: context.text.body),
      trailing: Switch(value: value, onChanged: onChanged),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
