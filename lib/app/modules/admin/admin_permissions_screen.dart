import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../data/enums/permission.dart';
import '../../data/models/user_model.dart';
import '../../services/permission_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

/// Permission editor for a single admin-tier user.
/// Shows every Permission grouped by category. Role defaults are pre-ticked.
/// Custom overrides (grant/deny) are highlighted in amber/red.
class AdminPermissionsScreen extends StatefulWidget {
  final UserModel user;
  const AdminPermissionsScreen({super.key, required this.user});

  @override
  State<AdminPermissionsScreen> createState() => _AdminPermissionsScreenState();
}

class _AdminPermissionsScreenState extends State<AdminPermissionsScreen> {
  late Map<String, bool> _overrides;
  late Set<Permission> _roleDefaults;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _roleDefaults = PermissionService.defaultsFor(widget.user.role);
    _overrides = Map<String, bool>.from(widget.user.customPermissions);
  }

  bool _effectiveValue(Permission p) {
    if (_overrides.containsKey(p.name)) return _overrides[p.name]!;
    return _roleDefaults.contains(p);
  }

  void _toggle(Permission p) {
    setState(() {
      final currentEffective = _effectiveValue(p);
      final roleDefault = _roleDefaults.contains(p);
      final newValue = !currentEffective;
      if (newValue == roleDefault) {
        _overrides.remove(p.name);
      } else {
        _overrides[p.name] = newValue;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AdminController.to.updateCustomPermissions(widget.user.uid, _overrides);
      Get.back();
      Get.snackbar('Saved', 'Permissions updated.',
          backgroundColor: AppColors.success, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Failed', e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overrideCount = _overrides.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Permissions'),
            Text(widget.user.name,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          if (overrideCount > 0)
            TextButton(
              onPressed: () => setState(() => _overrides.clear()),
              child: Text('Reset ($overrideCount)',
                  style: AppTextStyles.caption.copyWith(color: AppColors.error)),
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : Text('Save',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _legend(),
          const SizedBox(height: 8),
          _roleInfo(),
          const SizedBox(height: 12),
          ..._categories.entries.map((e) => _categorySection(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _legend() => AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _dot(AppColors.primary),
            const SizedBox(width: 6),
            Text('Role default', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(width: 16),
            _dot(AppColors.warning),
            const SizedBox(width: 6),
            Text('Custom grant', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(width: 16),
            _dot(AppColors.error),
            const SizedBox(width: 6),
            Text('Custom deny', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _dot(Color c) => Container(
      width: 10, height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _roleInfo() => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.badge_outlined, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Role: ${widget.user.role.name.capitalizeFirst} · ${_roleDefaults.length} defaults',
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
      );

  Widget _categorySection(String category, List<Permission> perms) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4, left: 2),
            child: Text(
              category.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8),
            ),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: perms.asMap().entries.map((e) {
                return _permRow(e.value, e.key == perms.length - 1);
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );

  Widget _permRow(Permission p, bool isLast) {
    final effective = _effectiveValue(p);
    final isDefault = _roleDefaults.contains(p);
    final overridden = _overrides.containsKey(p.name);

    Color bar;
    if (overridden) {
      bar = effective ? AppColors.warning : AppColors.error;
    } else if (isDefault) {
      bar = AppColors.primary;
    } else {
      bar = Colors.transparent;
    }

    return InkWell(
      onTap: () => _toggle(p),
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(12))
          : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 4, height: 34,
              decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(p),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: effective ? AppColors.textPrimary : AppColors.textGrey,
                    ),
                  ),
                  if (overridden) ...[
                    const SizedBox(height: 2),
                    Text(
                      effective ? 'Custom grant (role default: off)' : 'Custom deny (role default: on)',
                      style: AppTextStyles.caption
                          .copyWith(color: effective ? AppColors.warning : AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: effective,
              onChanged: (_) => _toggle(p),
              activeColor: overridden ? AppColors.warning : AppColors.primary,
              activeTrackColor: overridden
                  ? AppColors.warning.withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  static String _label(Permission p) {
    final spaced = p.name.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => ' ${m.group(0)}',
    );
    return spaced.capitalizeFirst ?? p.name;
  }

  static const Map<String, List<Permission>> _categories = {
    'Arenas': [
      Permission.viewArenas, Permission.approveArena, Permission.rejectArena,
      Permission.suspendArena, Permission.restoreArena, Permission.deleteArena,
      Permission.featureArena, Permission.manageCarousel, Permission.verifyArenaDocs,
    ],
    'Bookings': [
      Permission.viewAllBookings, Permission.cancelAnyBooking,
      Permission.refundBooking, Permission.markNoShow,
    ],
    'Users': [
      Permission.viewUsers, Permission.suspendUser, Permission.deleteUser,
      Permission.changeUserRole, Permission.changeAccountStatus, Permission.manageStaff,
    ],
    'Boosts': [
      Permission.viewBoosts, Permission.approveBoost, Permission.rejectBoost,
    ],
    'Tickets': [
      Permission.viewAllTickets, Permission.assignTicket, Permission.resolveTicket,
    ],
    'Analytics & Finance': [
      Permission.viewAnalytics, Permission.viewFinancials, Permission.exportReports,
    ],
    'Platform': [
      Permission.manageSettings, Permission.manageCMS, Permission.manageTournaments,
    ],
    'Audit Logs': [
      Permission.viewAuditLogs, Permission.exportAuditLogs,
    ],
    'Notifications': [
      Permission.viewAdminNotifications, Permission.sendBroadcast,
    ],
    'Admin Management': [
      Permission.inviteAdmins, Permission.inviteOwners, Permission.manageAdmins,
    ],
  };
}
