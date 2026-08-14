import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/auth_controller.dart';
import '../data/models/user_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';

// ── Palette aliases ───────────────────────────────────────────────────────────
const _bg = AppColors.background;
const _surface = AppColors.surface;
const _elevated = AppColors.elevated;
const _border = AppColors.border;
const _lime = AppColors.primary;
const _blue = AppColors.secondary;
const _onSurface = AppColors.textPrimary;
const _muted = AppColors.textSecondary;
const _dim = AppColors.textDisabled;
const _red = AppColors.error;
const _green = AppColors.success;
const _onLime = AppColors.onPrimary;

/// Premium customer profile tab — 2026 AI-era design.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  late final AnimationController _headerCtrl;
  late final Animation<double> _headerScale;
  late final Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _headerScale = Tween(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.elasticOut));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _enterCtrl.forward();
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthController.to;
    final theme = ThemeController.to;

    return Container(
      color: _bg,
      child: Stack(
        children: [
          // Ambient lime glow top-right
          Positioned(
            top: -80,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_lime.withValues(alpha: 0.06), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          // Ambient blue glow bottom-left
          Positioned(
            bottom: 120,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_blue.withValues(alpha: 0.05), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: ScaleTransition(
                      scale: _headerScale,
                      child: Obx(() {
                        final user = auth.currentUser.value;
                        return _ProfileHeader(
                          user: user,
                          onCameraTap: user?.role == UserRole.customer
                              ? () => Get.toNamed(AppRoutes.profilePhotoUpload)
                              : () => _showEditProfile(context, auth),
                        );
                      }),
                    ),
                  ),
                ),

                // ── Body content ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: Obx(() {
                        final user = auth.currentUser.value;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),

                              // Settings
                              _SectionLabel('Settings'),
                              const SizedBox(height: 12),
                              _SettingsCard(
                                children: [
                                  _SettingsTile(
                                    icon: Icons.person_outline_rounded,
                                    label: 'Edit Profile',
                                    subtitle: 'Name, phone number',
                                    onTap: () =>
                                        _showEditProfile(context, auth),
                                  ),
                                  _SettingsDivider(),
                                  Obx(
                                    () => _SettingsTile(
                                      icon: theme.isDarkMode.value
                                          ? Icons.dark_mode_rounded
                                          : Icons.light_mode_rounded,
                                      label: 'Dark Mode',
                                      subtitle: theme.isDarkMode.value
                                          ? 'On'
                                          : 'Off',
                                      onTap: theme.toggleTheme,
                                      trailing: _GlowSwitch(
                                        value: theme.isDarkMode.value,
                                        onChanged: (_) => theme.toggleTheme(),
                                      ),
                                    ),
                                  ),
                                  _SettingsDivider(),
                                  _SettingsTile(
                                    icon: Icons.notifications_outlined,
                                    label: 'Notifications',
                                    subtitle: 'Alerts & reminders',
                                    onTap: () =>
                                        Get.toNamed(AppRoutes.notifications),
                                  ),
                                  if (user?.role == UserRole.owner) ...[
                                    _SettingsDivider(),
                                    _SettingsTile(
                                      icon: Icons.rocket_launch_outlined,
                                      label: 'My Boost Requests',
                                      subtitle: 'Arena promotion status',
                                      onTap: () =>
                                          Get.toNamed(AppRoutes.boostStatus),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Sign out
                              _SettingsCard(
                                borderColor: _red.withValues(alpha: 0.2),
                                children: [
                                  _SettingsTile(
                                    icon: Icons.logout_rounded,
                                    label: 'Sign Out',
                                    subtitle: 'Log out of your account',
                                    iconColor: _red,
                                    labelColor: _red,
                                    showChevron: false,
                                    onTap: auth.signOut,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Delete account
                              _SettingsCard(
                                borderColor: _red.withValues(alpha: 0.35),
                                children: [
                                  _SettingsTile(
                                    icon: Icons.delete_forever_rounded,
                                    label: 'Delete Account',
                                    subtitle: 'Permanently remove all data',
                                    iconColor: _red,
                                    labelColor: _red,
                                    showChevron: false,
                                    onTap: () =>
                                        _confirmDeleteAccount(context, auth),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'Account deletion is permanent and cannot be undone.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: _red.withValues(alpha: 0.55),
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Edit profile sheet ─────────────────────────────────────────────────────

  void _showEditProfile(BuildContext context, AuthController auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _EditProfileSheet(auth: auth),
    );
  }

  // ── Delete account dialog ──────────────────────────────────────────────────

  void _confirmDeleteAccount(BuildContext context, AuthController auth) {
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _elevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.warning_amber_rounded, color: _red, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Delete Account',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete your account, cancel all pending bookings, and remove all personal data. This cannot be undone.',
              style: TextStyle(fontSize: 13, color: _muted, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Type DELETE to confirm:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 14, letterSpacing: 1.5),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: TextStyle(color: _muted.withValues(alpha: 0.5)),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _red.withValues(alpha: 0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _red),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          Obx(
            () => TextButton(
              onPressed: auth.isLoading.value
                  ? null
                  : () async {
                      if (confirmCtrl.text.trim() != 'DELETE') {
                        Get.snackbar(
                          'Incorrect',
                          'Please type DELETE in capitals to confirm.',
                          backgroundColor: _elevated,
                          colorText: _onSurface,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      await auth.deleteAccount();
                    },
              child: auth.isLoading.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Delete Forever',
                      style: TextStyle(
                        color: _red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Header ─────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserModel? user;
  final VoidCallback onCameraTap;
  const _ProfileHeader({required this.user, required this.onCameraTap});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user?.name ?? '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(
          bottom: BorderSide(color: _border.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _lime.withValues(alpha: 0.5),
                      _blue.withValues(alpha: 0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _lime.withValues(alpha: 0.18),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Avatar circle
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _elevated,
                  border: Border.all(color: _bg, width: 3),
                ),
                clipBehavior: Clip.antiAlias,
                child: user?.avatar.isNotEmpty == true
                    ? Image.network(
                        user!.avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) =>
                            _InitialsAvatar(initials: initials),
                      )
                    : _InitialsAvatar(initials: initials),
              ),
              // Edit button
              Positioned(
                bottom: -2,
                right: -2,
                child: GestureDetector(
                  onTap: onCameraTap,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _lime,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bg, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: _lime.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: _onLime,
                      size: 16,
                    ),
                  ),
                ),
              ),
              // Online dot
              Positioned(top: 6, right: 6, child: _OnlineDot()),
            ],
          ),

          const SizedBox(height: 16),

          // Name
          Text(
            user?.name.isNotEmpty == true ? user!.name : 'My Profile',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _onSurface,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),

          // Email / phone
          Text(
            user?.email.isNotEmpty == true ? user!.email : (user?.phone ?? ''),
            style: const TextStyle(
              fontSize: 14,
              color: _muted,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 12),

          // Role badge + optional verified badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _lime.withValues(alpha: 0.15),
                      _blue.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _lime.withValues(alpha: 0.3)),
                ),
                child: Text(
                  (user?.role.name ?? 'customer').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _lime,
                    letterSpacing: 2,
                  ),
                ),
              ),
              if (user?.email.isNotEmpty == true) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _green.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified_rounded, size: 12, color: _green),
                      SizedBox(width: 4),
                      Text(
                        'VERIFIED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _green,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  if (name.isEmpty) return '?';
  final parts = name.trim().split(' ');
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _elevated,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: _lime,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }
}

class _OnlineDot extends StatefulWidget {
  @override
  State<_OnlineDot> createState() => _OnlineDotState();
}

class _OnlineDotState extends State<_OnlineDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_ctrl),
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: _green,
          shape: BoxShape.circle,
          border: Border.all(color: _surface, width: 2),
          boxShadow: [
            BoxShadow(color: _green.withValues(alpha: 0.5), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

// ── Settings ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _muted,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final Color? borderColor;
  const _SettingsCard({required this.children, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor ?? _border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? labelColor;
  final bool showChevron;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.iconColor,
    this.labelColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: (iconColor ?? _lime).withValues(alpha: 0.06),
        highlightColor: (iconColor ?? _lime).withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (iconColor ?? _lime).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: iconColor ?? _lime),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: labelColor ?? _onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              trailing ??
                  (showChevron
                      ? const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: _dim,
                        )
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 67,
      color: _border.withValues(alpha: 0.4),
    );
  }
}

// ── Edit Profile Sheet ─────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final AuthController auth;
  const _EditProfileSheet({required this.auth});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  XFile? _picked;
  Uint8List? _pickedBytes;
  bool _saving = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = widget.auth.currentUser.value;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final xf = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (xf != null && mounted) {
      final bytes = await xf.readAsBytes();
      setState(() {
        _picked = xf;
        _pickedBytes = bytes;
      });
    }
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: _lime),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: _lime),
              title: const Text('Photo Library'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (widget.auth.currentUser.value?.avatar.isNotEmpty == true)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: _red),
                title: const Text('Remove Photo',
                    style: TextStyle(color: _red)),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() {
                    _picked = null;
                    _pickedBytes = null;
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      if (_picked != null) {
        await widget.auth.uploadProfilePhoto(_picked!);
      }
      await widget.auth.updateProfile(
          name: name, phone: _phoneCtrl.text.trim());
      if (mounted) {
        Navigator.pop(context);
        Get.snackbar(
          'Profile Updated',
          'Your changes have been saved.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        Get.snackbar(
          'Error',
          'Failed to save profile. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.currentUser.value;
    final initials = _initials(user?.name ?? '');

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _lime.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_outline_rounded,
                    color: _lime, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Edit Profile',
                style: TextStyle(
                  color: _onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Avatar picker
          GestureDetector(
            onTap: _saving ? null : _showSourceSheet,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow ring
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        _lime.withValues(alpha: 0.4),
                        _blue.withValues(alpha: 0.25),
                      ],
                    ),
                  ),
                ),
                // Avatar
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _elevated,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _picked != null
                      ? Image.memory(_pickedBytes!, fit: BoxFit.cover)
                      : (user?.avatar.isNotEmpty == true
                          ? Image.network(user!.avatar, fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) =>
                                  _InitialsAvatar(initials: initials))
                          : _InitialsAvatar(initials: initials)),
                ),
                // Camera badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _lime,
                      shape: BoxShape.circle,
                      border: Border.all(color: _elevated, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: _onLime, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap to change photo',
            style: TextStyle(fontSize: 12, color: _muted),
          ),

          // Upload progress bar
          if (_saving && _picked != null)
            Obx(() {
              final p = widget.auth.photoUploadProgress.value;
              return p > 0 && p < 1
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: p,
                          backgroundColor: _border,
                          valueColor: const AlwaysStoppedAnimation(_lime),
                          minHeight: 4,
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            }),

          const SizedBox(height: 20),

          // Fields
          _SheetField(
            controller: _nameCtrl,
            hint: 'Full name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),
          _SheetField(
            controller: _phoneCtrl,
            hint: 'Phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _lime,
                foregroundColor: _onLime,
                disabledBackgroundColor: _lime.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _onLime,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet Field ────────────────────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  const _SheetField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: _onSurface, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _dim),
        filled: true,
        fillColor: _bg,
        prefixIcon: Icon(icon, color: _muted, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _lime, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ── Glow Switch ────────────────────────────────────────────────────────────────

class _GlowSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _GlowSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? _lime : _elevated,
          borderRadius: BorderRadius.circular(13),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: _lime.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(color: _bg, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
