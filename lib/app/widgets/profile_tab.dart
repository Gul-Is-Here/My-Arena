import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../theme/theme_controller.dart';

// ── Design tokens (Arena Command dark glass theme) ────────────────────────
const _bg = Color(0xFF0B0E14);
const _surfaceHighest = Color(0xFF32353C);
const _outline = Color(0xFF3B494B);
const _cyan = Color(0xFF00DBE9);
const _cyanDim = Color(0xFF7DF4FF);
const _green = Color(0xFF79FF5B);
const _onSurface = Color(0xFFE1E2EB);
const _onSurfaceVar = Color(0xFFB9CACB);
const _red = Color(0xFFFFB4AB);
const _redContainer = Color(0xFF93000A);

/// Profile tab shared by all role shells: user info, theme toggle, sign out.
/// Dark liquid-glass design matching the Arena Command bookings tab.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthController.to;
    final theme = ThemeController.to;

    return Container(
      color: _bg,
      child: Stack(
        children: [
          // Ambient radial glow at top center
          Positioned(
            top: -140,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 320,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _cyan.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              children: [
                Obx(() {
                  final user = auth.currentUser.value;
                  return Column(
                    children: [
                      _Avatar(),
                      const SizedBox(height: 16),
                      Text(
                        user?.name ?? 'User',
                        style: const TextStyle(
                          fontFamily: 'Archivo Narrow',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: _onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email.isNotEmpty == true
                            ? user!.email
                            : (user?.phone ?? ''),
                        style: const TextStyle(
                          fontSize: 15,
                          color: _onSurfaceVar,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: _surfaceHighest,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _outline.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          (user?.role.name ?? 'customer').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _cyanDim,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 36),

                // Settings glass card
                _GlassCard(
                  child: Column(
                    children: [
                      Obx(
                        () => _SettingsRow(
                          icon: Icons.dark_mode_outlined,
                          label: 'Dark Mode',
                          onTap: theme.toggleTheme,
                          trailing: _GlowSwitch(
                            value: theme.isDarkMode.value,
                            onChanged: (_) => theme.toggleTheme(),
                          ),
                        ),
                      ),
                      _divider(),
                      _SettingsRow(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        onTap: () => _comingSoon('Notification settings'),
                      ),
                      _divider(),
                      _SettingsRow(
                        icon: Icons.help_outline,
                        label: 'Help & Support',
                        onTap: () => _comingSoon('Support chat (Phase 4)'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sign out glass card
                _GlassCard(
                  borderColor: _redContainer.withValues(alpha: 0.35),
                  child: _SettingsRow(
                    icon: Icons.logout,
                    label: 'Sign Out',
                    color: _red,
                    showChevron: false,
                    onTap: auth.signOut,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 1,
        color: _outline.withValues(alpha: 0.2),
      );

  void _comingSoon(String feature) {
    Get.snackbar(
      'Coming soon',
      feature,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }
}

/// Glass avatar with cyan halo and pulsing green status dot.
class _Avatar extends StatefulWidget {
  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF252A34).withValues(alpha: 0.5),
                  border: Border.all(
                    color: _cyan.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _cyan.withValues(alpha: 0.12),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.person, size: 60, color: _cyanDim),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: FadeTransition(
              opacity: Tween(begin: 0.4, end: 1.0).animate(_pulse),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                  border: Border.all(color: _bg, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted-glass rounded container used for the settings groups.
class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _GlassCard({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D23).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.05),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? color;
  final bool showChevron;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.color,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color ?? _onSurfaceVar),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16.5,
                    color: color ?? _onSurface,
                  ),
                ),
              ),
              trailing ??
                  (showChevron
                      ? const Icon(Icons.chevron_right,
                          size: 22, color: _onSurfaceVar)
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom pill switch matching the HTML toggle (cyan track, dark thumb).
class _GlowSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _GlowSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? _cyanDim : _surfaceHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: _bg,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
