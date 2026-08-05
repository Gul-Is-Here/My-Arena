import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/admin_controller.dart';
import '../../data/models/owner_invitation_model.dart';
import '../../data/models/user_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

/// User management — All users with search | Staff tab.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  UserRole? _roleFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<UserModel> _filter(List<UserModel> src) {
    var list = _roleFilter != null
        ? src.where((u) => u.role == _roleFilter).toList()
        : src;
    final q = _query.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((u) {
        return u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            u.phone.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminController.to;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('User Management'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_outlined, color: AppColors.primary),
              tooltip: 'Invite Owner',
              onPressed: () => _showInviteDialog(context, admin),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(104),
            child: Column(
              children: [
                const TabBar(
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textGrey,
                  tabs: [
                    Tab(text: 'All Users'),
                    Tab(text: 'Staff'),
                    Tab(text: 'Invitations'),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    style: AppTextStyles.bodyMedium,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search name, email, phone…',
                      hintStyle:
                          AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textSecondary, size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18, color: AppColors.textSecondary),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.elevated,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Obx(() {
          admin.users.length;
          final all = _filter(admin.users.toList());
          final staff = _filter(admin.users
              .where((u) =>
                  u.role == UserRole.staff || u.role == UserRole.supportAgent)
              .toList());
          return TabBarView(
            children: [
              _userList(context, all, admin, roleChips: true),
              _userList(context, staff, admin, roleChips: false),
              _InvitationsTab(admin: admin),
            ],
          );
        }),
      ),
    );
  }

  Widget _userList(BuildContext context, List<UserModel> users,
      AdminController admin, {required bool roleChips}) {
    return Column(
      children: [
        if (roleChips) ...[
          Container(
            color: AppColors.surface,
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              children: [
                _roleChip(null, 'All'),
                ...UserRole.values.map((r) => _roleChip(r, r.name.capitalizeFirst!)),
              ],
            ),
          ),
        ],
        Expanded(
          child: users.isEmpty
              ? Center(
                  child: Text('No users found',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: users.length,
                  itemBuilder: (_, i) => _UserTile(
                    user: users[i],
                    admin: admin,
                    onRoleChange: () => _showRoleSheet(context, users[i], admin),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _roleChip(UserRole? role, String label) {
    final sel = _roleFilter == role;
    return GestureDetector(
      onTap: () => setState(() => _roleFilter = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.elevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppColors.primary : AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: AppTextStyles.caption.copyWith(
              color: sel ? AppColors.onPrimary : AppColors.textSecondary,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
            )),
      ),
    );
  }

  void _showRoleSheet(BuildContext context, UserModel user, AdminController admin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change role — ${user.name}', style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),
              ...UserRole.values.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    r == user.role
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: r == user.role ? AppColors.primary : AppColors.textGrey,
                  ),
                  title: Text(r.name.capitalizeFirst!),
                  onTap: () {
                    admin.changeRole(user.uid, r);
                    Get.back();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context, AdminController admin) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Invite Arena Owner', style: AppTextStyles.titleMedium),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  style: AppTextStyles.bodyMedium,
                  decoration: _inputDec('Full Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  style: AppTextStyles.bodyMedium,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDec('Email Address'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter valid email' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  style: AppTextStyles.bodyMedium,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDec('Phone (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => loading = true);
                      try {
                        final result = await admin.inviteOwner(
                          email: emailCtrl.text.trim(),
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                        );
                        Get.back();
                        final msg = result['isUpgrade'] == true
                            ? 'Existing account upgraded to owner.'
                            : 'Invitation sent to ${emailCtrl.text.trim()}';
                        Get.snackbar('Success', msg,
                            backgroundColor: AppColors.success,
                            colorText: Colors.white);
                      } catch (e) {
                        setS(() => loading = false);
                        Get.snackbar('Failed',
                            e.toString().replaceFirst('Exception: ', ''),
                            backgroundColor: AppColors.error,
                            colorText: Colors.white);
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.elevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
}

// ── Invitations Tab ────────────────────────────────────────────────────────

class _InvitationsTab extends StatelessWidget {
  final AdminController admin;
  const _InvitationsTab({required this.admin});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OwnerInvitationModel>>(
      stream: admin.invitationsStream(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mail_outline, color: AppColors.textGrey, size: 48),
                const SizedBox(height: 12),
                Text('No invitations yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (_, i) => _InvitationTile(inv: list[i], admin: admin),
        );
      },
    );
  }
}

class _InvitationTile extends StatelessWidget {
  final OwnerInvitationModel inv;
  final AdminController admin;
  const _InvitationTile({required this.inv, required this.admin});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (inv.status) {
      InvitationStatus.pending  => AppColors.warning,
      InvitationStatus.accepted => AppColors.success,
      InvitationStatus.expired  => AppColors.textGrey,
      InvitationStatus.revoked  => AppColors.error,
    };
    final expiredOverride = inv.isExpired && inv.status == InvitationStatus.pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.name, style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600)),
                    Text(inv.email, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  expiredOverride ? 'Expired' : inv.status.label,
                  style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule, size: 12, color: AppColors.textGrey),
              const SizedBox(width: 4),
              Text(
                inv.status == InvitationStatus.accepted
                    ? 'Accepted ${_fmt(inv.acceptedAt)}'
                    : expiredOverride
                        ? 'Expired ${_fmt(inv.expiresAt)}'
                        : inv.status == InvitationStatus.pending
                            ? 'Expires ${_fmt(inv.expiresAt)}'
                            : 'Revoked ${_fmt(inv.revokedAt)}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textGrey),
              ),
              if (inv.isUpgrade) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('UPGRADE', style: AppTextStyles.caption.copyWith(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          if (inv.status == InvitationStatus.pending && !expiredOverride) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (inv.canResend)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.send_outlined, size: 14),
                      label: Text('Resend${inv.resendCount > 0 ? ' (${inv.resendCount})' : ''}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        textStyle: AppTextStyles.caption,
                      ),
                      onPressed: () async {
                        try {
                          await admin.resendInvitation(inv.id);
                          Get.snackbar('Sent', 'Invitation resent.', backgroundColor: AppColors.success, colorText: Colors.white);
                        } catch (e) {
                          Get.snackbar('Failed', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: Colors.white);
                        }
                      },
                    ),
                  ),
                if (inv.canResend) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.block_outlined, size: 14),
                    label: const Text('Revoke'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      textStyle: AppTextStyles.caption,
                    ),
                    onPressed: () => _confirmRevoke(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _confirmRevoke(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Revoke Invitation?', style: AppTextStyles.titleMedium),
        content: Text(
          'Revoking will disable ${inv.name}\'s account and archive any pre-created arenas.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Get.back();
              try {
                await admin.revokeInvitation(inv.id);
                Get.snackbar('Revoked', 'Invitation revoked.', backgroundColor: AppColors.error, colorText: Colors.white);
              } catch (e) {
                Get.snackbar('Failed', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: Colors.white);
              }
            },
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('d MMM, HH:mm').format(dt);
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  final AdminController admin;
  final VoidCallback onRoleChange;

  const _UserTile({
    required this.user,
    required this.admin,
    required this.onRoleChange,
  });

  @override
  Widget build(BuildContext context) {
    final u = user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                u.name.isNotEmpty ? u.name[0] : '?',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(u.name,
                            style: AppTextStyles.titleMedium,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (!u.isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('BANNED',
                              style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 10,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  Text(u.email,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey)),
                  Text(u.role.name.toUpperCase(),
                      style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 10,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textGrey),
              onSelected: (action) {
                if (action == 'ban') {
                  admin.toggleBan(u.uid);
                } else if (action == 'role') {
                  onRoleChange();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'ban',
                  child: Text(u.isActive ? 'Ban user' : 'Unban user'),
                ),
                const PopupMenuItem(
                  value: 'role',
                  child: Text('Change role'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
