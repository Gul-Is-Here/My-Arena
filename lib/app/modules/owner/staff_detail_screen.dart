import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/owner_controller.dart';
import '../../controllers/staff_management_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/user_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

class StaffDetailScreen extends StatefulWidget {
  const StaffDetailScreen({super.key});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  late UserModel _staff;
  late Set<String> _selectedArenaIds;
  late List<ArenaModel> _allArenas;
  bool _editingArenas = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is! UserModel) {
      Get.back();
      return;
    }
    _staff = args;
    _selectedArenaIds = Set<String>.from(_staff.assignedArenas);
    if (!Get.isRegistered<OwnerController>()) {
      Get.put(OwnerController());
    }
    _allArenas = Get.find<OwnerController>().myArenas.toList();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<StaffManagementController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_staff.name.isNotEmpty ? _staff.name : 'Staff Detail'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          Obx(() => ctrl.isLoading.value
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(),
          const SizedBox(height: 20),
          _SuspendCard(staff: _staff, ctrl: ctrl),
          const SizedBox(height: 20),
          _ArenaAssignmentSection(
            allArenas: _allArenas,
            selectedIds: _selectedArenaIds,
            editing: _editingArenas,
            onToggleEdit: () => setState(() => _editingArenas = !_editingArenas),
            onToggle: (id) => setState(() {
              if (_selectedArenaIds.contains(id)) {
                _selectedArenaIds.remove(id);
              } else {
                _selectedArenaIds.add(id);
              }
            }),
            onSave: () async {
              await ctrl.updateStaffArenas(_staff.uid, _selectedArenaIds.toList());
              setState(() => _editingArenas = false);
            },
            ctrl: ctrl,
          ),
          const SizedBox(height: 20),
          _PermissionsSection(staff: _staff),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            backgroundImage:
                _staff.avatar.isNotEmpty ? NetworkImage(_staff.avatar) : null,
            child: _staff.avatar.isEmpty
                ? Text(
                    _staff.name.isNotEmpty ? _staff.name[0].toUpperCase() : '?',
                    style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_staff.name.isNotEmpty ? _staff.name : '(Not set)',
                    style: AppTextStyles.titleMedium),
                Text(_staff.email,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                if (_staff.phone.isNotEmpty)
                  Text(_staff.phone,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _staff.isActive
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _staff.isActive ? 'Active' : 'Suspended',
              style: AppTextStyles.bodySmall.copyWith(
                color: _staff.isActive ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suspend card ──────────────────────────────────────────────────────────────

class _SuspendCard extends StatelessWidget {
  final UserModel staff;
  final StaffManagementController ctrl;
  const _SuspendCard({required this.staff, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isSuspended = !staff.isActive;
    return AppCard(
      child: Row(
        children: [
          Icon(
            isSuspended ? Icons.block : Icons.check_circle_outline,
            color: isSuspended ? AppColors.error : AppColors.success,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isSuspended ? 'Account Suspended' : 'Account Active',
                    style: AppTextStyles.label),
                Text(
                  isSuspended
                      ? 'This staff member cannot log in.'
                      : 'This staff member has full access.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => ctrl.setSuspended(staff.uid, suspend: !isSuspended),
            child: Text(
              isSuspended ? 'Reactivate' : 'Suspend',
              style: TextStyle(
                  color: isSuspended ? AppColors.success : AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Arena assignment ──────────────────────────────────────────────────────────

class _ArenaAssignmentSection extends StatelessWidget {
  final List<ArenaModel> allArenas;
  final Set<String> selectedIds;
  final bool editing;
  final VoidCallback onToggleEdit;
  final void Function(String) onToggle;
  final VoidCallback onSave;
  final StaffManagementController ctrl;

  const _ArenaAssignmentSection({
    required this.allArenas,
    required this.selectedIds,
    required this.editing,
    required this.onToggleEdit,
    required this.onToggle,
    required this.onSave,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Assigned Arenas', style: AppTextStyles.label),
            const Spacer(),
            TextButton.icon(
              onPressed: onToggleEdit,
              icon: Icon(editing ? Icons.close : Icons.edit_outlined, size: 16),
              label: Text(editing ? 'Cancel' : 'Edit'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (allArenas.isEmpty)
          Text('No arenas available.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary))
        else
          ...allArenas.map((arena) {
            final isSelected = selectedIds.contains(arena.id);
            return AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: isSelected ? AppColors.primary : AppColors.border,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(arena.name, style: AppTextStyles.bodyMedium),
                        Text(arena.location.address,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (editing)
                    Switch(
                      value: isSelected,
                      onChanged: (_) => onToggle(arena.id),
                      activeColor: AppColors.primary,
                    ),
                ],
              ),
            );
          }),
        if (editing) ...[
          const SizedBox(height: 12),
          Obx(() => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: ctrl.isLoading.value ? null : onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save Changes',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              )),
        ],
      ],
    );
  }
}

// ── Permissions section ───────────────────────────────────────────────────────

class _PermissionsSection extends StatelessWidget {
  final UserModel staff;
  const _PermissionsSection({required this.staff});

  String _label(String p) => p == 'edit_arena' ? 'Edit Arena' : 'Edit Courts';

  @override
  Widget build(BuildContext context) {
    if (staff.assignedArenas.isEmpty) return const SizedBox.shrink();

    final arenaIdsWithPerms = staff.assignedArenas
        .where((id) => staff.permissionsFor(id).isNotEmpty)
        .toList();

    if (arenaIdsWithPerms.isEmpty) return const SizedBox.shrink();

    final ctrl = Get.find<StaffManagementController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Granted Permissions', style: AppTextStyles.label),
        const SizedBox(height: 4),
        Text('Tap × to revoke access.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        ...arenaIdsWithPerms.map((arenaId) {
          final perms = staff.permissionsFor(arenaId);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(arenaId,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: perms.map((p) {
                      return Chip(
                        label: Text(_label(p)),
                        labelStyle: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.onPrimary),
                        backgroundColor: AppColors.primary,
                        deleteIcon: const Icon(Icons.close, size: 14,
                            color: AppColors.onPrimary),
                        onDeleted: () async {
                          final confirm = await Get.dialog<bool>(AlertDialog(
                            title: const Text('Revoke Access'),
                            content: Text(
                                'Remove "${_label(p)}" access from ${staff.name}?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Get.back(result: false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Get.back(result: true),
                                  child: Text('Revoke',
                                      style: TextStyle(
                                          color: AppColors.error))),
                            ],
                          ));
                          if (confirm == true) {
                            await ctrl.revokePermission(
                              staffUid: staff.uid,
                              arenaId: arenaId,
                              permission: p,
                            );
                          }
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
