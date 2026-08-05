import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/owner_controller.dart';
import '../../controllers/staff_management_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/staff_invitation_model.dart';
import '../../data/models/staff_permission_request_model.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

class MyTeamScreen extends StatelessWidget {
  const MyTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<StaffManagementController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Team'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 68,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showInviteSheet(context, ctrl),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Invite Staff'),
        ),
      ),
      body: Obx(() {
        final staff = ctrl.myStaff;
        final pending = ctrl.pendingInvitations;
        final requests = ctrl.permissionRequests;

        if (staff.isEmpty && pending.isEmpty && requests.isEmpty) {
          return _empty();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (requests.isNotEmpty) ...[
              _sectionLabel('Permission Requests', badge: requests.length),
              const SizedBox(height: 8),
              ...requests.map((r) => _PermissionRequestCard(request: r, ctrl: ctrl)),
              const SizedBox(height: 20),
            ],
            if (staff.isNotEmpty) ...[
              _sectionLabel('Team Members'),
              const SizedBox(height: 8),
              ...staff.map((s) => _StaffCard(staff: s)),
              const SizedBox(height: 20),
            ],
            if (pending.isNotEmpty) ...[
              _sectionLabel('Pending Invitations', badge: pending.length),
              const SizedBox(height: 8),
              ...pending.map((inv) => _InviteCard(invitation: inv, ctrl: ctrl)),
            ],
          ],
        );
      }),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text('No team members yet', style: AppTextStyles.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Invite staff to help manage your arenas',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, {int badge = 0}) {
    return Row(
      children: [
        Text(label,
            style: AppTextStyles.label
                .copyWith(color: AppColors.textSecondary)),
        if (badge > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$badge',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }

  void _showInviteSheet(BuildContext context, StaffManagementController ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _InviteSheet(ctrl: ctrl),
    );
  }
}

// ── Invite Sheet ─────────────────────────────────────────────────────────────

class _InviteSheet extends StatefulWidget {
  final StaffManagementController ctrl;
  const _InviteSheet({required this.ctrl});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _emailCtrl = TextEditingController();
  final Set<String> _selectedArenaIds = {};
  List<ArenaModel> _arenas = [];

  @override
  void initState() {
    super.initState();
    _arenas = Get.find<OwnerController>().myArenas.toList();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !GetUtils.isEmail(email)) {
      Get.snackbar('Invalid Email', 'Enter a valid email address.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_selectedArenaIds.isEmpty) {
      Get.snackbar('No Arenas Selected', 'Select at least one arena.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final selected = _arenas.where((a) => _selectedArenaIds.contains(a.id)).toList();
    await widget.ctrl.inviteStaff(email: email, arenas: selected);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Invite Staff Member', style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text('Enter their email and assign arenas they can manage.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Staff Email',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.elevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Assign Arenas', style: AppTextStyles.label),
          const SizedBox(height: 8),
          if (_arenas.isEmpty)
            Text('No arenas available.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))
          else
            ...(_arenas.map((arena) => CheckboxListTile(
                  value: _selectedArenaIds.contains(arena.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedArenaIds.add(arena.id);
                      } else {
                        _selectedArenaIds.remove(arena.id);
                      }
                    });
                  },
                  title: Text(arena.name,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textPrimary)),
                  subtitle: Text(arena.location.address,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                  activeColor: AppColors.primary,
                  checkColor: AppColors.onPrimary,
                  contentPadding: EdgeInsets.zero,
                ))),
          const SizedBox(height: 20),
          Obx(() => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.ctrl.isLoading.value ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: widget.ctrl.isLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Invitation',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              )),
        ],
      ),
    );
  }
}

// ── Staff Card ────────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final UserModel staff;
  const _StaffCard({required this.staff});

  @override
  Widget build(BuildContext context) {
    final isActive = staff.isActive;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Get.toNamed(AppRoutes.staffDetail, arguments: staff),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: staff.avatar.isNotEmpty ? NetworkImage(staff.avatar) : null,
              child: staff.avatar.isEmpty
                  ? Text(
                      staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(staff.name.isNotEmpty ? staff.name : staff.email,
                      style: AppTextStyles.label),
                  Text(staff.email,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    '${staff.assignedArenas.length} arena${staff.assignedArenas.length == 1 ? '' : 's'}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isActive ? 'Active' : 'Suspended',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isActive ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Invite Card ───────────────────────────────────────────────────────────────

class _InviteCard extends StatelessWidget {
  final StaffInvitationModel invitation;
  final StaffManagementController ctrl;
  const _InviteCard({required this.invitation, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.warning.withValues(alpha: 0.15),
              child: const Icon(Icons.mail_outline, color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invitation.email, style: AppTextStyles.label),
                  Text(
                    '${invitation.assignedArenas.length} arena${invitation.assignedArenas.length == 1 ? '' : 's'} assigned',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                final confirm = await Get.dialog<bool>(
                  AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('Revoke Invitation',
                        style: TextStyle(color: AppColors.textPrimary)),
                    content: Text('Revoke invitation for ${invitation.email}?',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    actions: [
                      TextButton(
                          onPressed: () => Get.back(result: false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Get.back(result: true),
                          child: const Text('Revoke',
                              style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                );
                if (confirm == true) ctrl.revokeInvitation(invitation.id);
              },
              child: const Text('Revoke', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Permission Request Card ───────────────────────────────────────────────────

class _PermissionRequestCard extends StatelessWidget {
  final StaffPermissionRequestModel request;
  final StaffManagementController ctrl;
  const _PermissionRequestCard({required this.request, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final perms = request.permissions
        .map((p) => p == 'edit_arena' ? 'Edit Arena' : 'Edit Courts')
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${request.staffName} → ${request.arenaName}',
                    style: AppTextStyles.label,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Requesting: $perms',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            if (request.reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('"${request.reason}"',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        ctrl.resolvePermission(request.id, approved: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Deny'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        ctrl.resolvePermission(request.id, approved: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Grant Access'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
