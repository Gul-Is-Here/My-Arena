import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../data/models/user_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class WorkspaceSelectorScreen extends StatefulWidget {
  const WorkspaceSelectorScreen({super.key});

  @override
  State<WorkspaceSelectorScreen> createState() =>
      _WorkspaceSelectorScreenState();
}

class _WorkspaceSelectorScreenState extends State<WorkspaceSelectorScreen>
    with SingleTickerProviderStateMixin {
  final auth = AuthController.to;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser.value;
    final roles = user?.roles ?? [user?.role ?? UserRole.customer];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _ctrl,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // Avatar + greeting
                Row(
                  children: [
                    _Avatar(name: user?.name ?? ''),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary),
                          ),
                          Text(
                            user?.name ?? 'User',
                            style: AppTextStyles.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                Text('Choose your\nworkspace',
                    style: AppTextStyles.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'Your account has access to multiple workspaces.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),

                // Workspace cards
                ...roles.map((role) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _WorkspaceCard(
                        role: role,
                        onTap: () => auth.switchRole(role),
                      ),
                    )),

                const Spacer(),

                // Sign out
                Center(
                  child: TextButton.icon(
                    onPressed: auth.signOut,
                    icon: const Icon(Icons.logout,
                        size: 16, color: AppColors.textDisabled),
                    label: Text(
                      'Sign out',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textDisabled),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0]).take(2).join();
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.15),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _WorkspaceCard extends StatefulWidget {
  final UserRole role;
  final VoidCallback onTap;

  const _WorkspaceCard({required this.role, required this.onTap});

  @override
  State<_WorkspaceCard> createState() => _WorkspaceCardState();
}

class _WorkspaceCardState extends State<_WorkspaceCard> {
  bool _pressed = false;

  static const _roleConfig = {
    UserRole.customer: (
      icon: Icons.sports_tennis_rounded,
      label: 'Customer',
      desc: 'Discover arenas, book courts and join tournaments',
      accent: AppColors.primary,
    ),
    UserRole.owner: (
      icon: Icons.stadium_rounded,
      label: 'Arena Owner',
      desc: 'Manage your arenas, bookings and revenue',
      accent: AppColors.secondary,
    ),
    UserRole.staff: (
      icon: Icons.badge_outlined,
      label: 'Staff',
      desc: 'Handle arena operations and customer support',
      accent: AppColors.accent,
    ),
    UserRole.admin: (
      icon: Icons.admin_panel_settings_outlined,
      label: 'Admin',
      desc: 'Platform management and oversight',
      accent: AppColors.accent,
    ),
    UserRole.superAdmin: (
      icon: Icons.shield_outlined,
      label: 'Super Admin',
      desc: 'Full platform control and configuration',
      accent: AppColors.accent,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _roleConfig[widget.role] ??
        (
          icon: Icons.person_outline,
          label: widget.role.label,
          desc: 'Access your workspace',
          accent: AppColors.textSecondary,
        );

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _pressed ? AppColors.elevated : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _pressed
                  ? cfg.accent.withValues(alpha: 0.5)
                  : AppColors.border,
              width: 1.5,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: cfg.accent.withValues(alpha: 0.12),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cfg.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(cfg.icon, size: 26, color: cfg.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cfg.label, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      cfg.desc,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: cfg.accent.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
