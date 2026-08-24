import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../data/models/user_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

/// Scope editor for a mini-admin: set managedOwnerIds, managedArenaIds, ownerInviteLimit.
/// Full admins (admin/superAdmin) should not have scope restrictions; this
/// screen is intended for operationsManager and below.
class AdminScopeScreen extends StatefulWidget {
  final UserModel user;
  const AdminScopeScreen({super.key, required this.user});

  @override
  State<AdminScopeScreen> createState() => _AdminScopeScreenState();
}

class _AdminScopeScreenState extends State<AdminScopeScreen> {
  late Set<String> _arenaIds;
  late Set<String> _ownerIds;
  final _limitCtrl = TextEditingController();
  bool _saving = false;
  String _arenaQuery = '';
  String _ownerQuery = '';

  @override
  void initState() {
    super.initState();
    _arenaIds = Set<String>.from(widget.user.managedArenaIds);
    _ownerIds = Set<String>.from(widget.user.managedOwnerIds);
    final limit = widget.user.ownerInviteLimit;
    _limitCtrl.text = limit != null ? limit.toString() : '';
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final limitText = _limitCtrl.text.trim();
      final limit = limitText.isEmpty ? null : int.tryParse(limitText);
      await AdminController.to.updateAdminScope(
        widget.user.uid,
        managedOwnerIds: _ownerIds.toList(),
        managedArenaIds: _arenaIds.toList(),
        ownerInviteLimit: limit,
      );
      Get.back();
      Get.snackbar('Saved', 'Scope updated for ${widget.user.name}.',
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
    final admin = AdminController.to;
    final allArenas = admin.arenas.toList();
    final allOwners = admin.users.where((u) => u.role == UserRole.owner).toList();

    final filteredArenas = _arenaQuery.isEmpty
        ? allArenas
        : allArenas
            .where((a) => a.name.toLowerCase().contains(_arenaQuery.toLowerCase()))
            .toList();
    final filteredOwners = _ownerQuery.isEmpty
        ? allOwners
        : allOwners.where((u) =>
            u.name.toLowerCase().contains(_ownerQuery.toLowerCase()) ||
            u.email.toLowerCase().contains(_ownerQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Scope'),
            Text(widget.user.name,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : Text('Save',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _infoCard(),
          const SizedBox(height: 12),
          _inviteLimitSection(),
          const SizedBox(height: 16),
          _sectionHeader(
            'Managed Arenas',
            '${_arenaIds.length} selected (empty = all arenas)',
          ),
          _searchField(
            hint: 'Search arenas…',
            onChanged: (v) => setState(() => _arenaQuery = v),
          ),
          const SizedBox(height: 6),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: filteredArenas.isEmpty
                  ? [_emptyRow('No arenas found')]
                  : filteredArenas.asMap().entries.map((e) {
                      final arena = e.value;
                      final isLast = e.key == filteredArenas.length - 1;
                      return _checkRow(
                        title: arena.name,
                        subtitle: arena.location.address,
                        checked: _arenaIds.contains(arena.id),
                        isLast: isLast,
                        onTap: () => setState(() {
                          if (_arenaIds.contains(arena.id)) {
                            _arenaIds.remove(arena.id);
                          } else {
                            _arenaIds.add(arena.id);
                          }
                        }),
                      );
                    }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader(
            'Managed Owners',
            '${_ownerIds.length} selected (empty = all owners)',
          ),
          _searchField(
            hint: 'Search owners…',
            onChanged: (v) => setState(() => _ownerQuery = v),
          ),
          const SizedBox(height: 6),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: filteredOwners.isEmpty
                  ? [_emptyRow('No owners found')]
                  : filteredOwners.asMap().entries.map((e) {
                      final owner = e.value;
                      final isLast = e.key == filteredOwners.length - 1;
                      return _checkRow(
                        title: owner.name,
                        subtitle: owner.email,
                        checked: _ownerIds.contains(owner.uid),
                        isLast: isLast,
                        onTap: () => setState(() {
                          if (_ownerIds.contains(owner.uid)) {
                            _ownerIds.remove(owner.uid);
                          } else {
                            _ownerIds.add(owner.uid);
                          }
                        }),
                      );
                    }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoCard() => AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Leave arena and owner lists empty to grant access to everything. '
                'Set selections to restrict this admin to specific arenas and owners only.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );

  Widget _inviteLimitSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Owner Invite Limit', 'Leave blank for unlimited'),
          const SizedBox(height: 6),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.mail_outline, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _limitCtrl,
                    keyboardType: TextInputType.number,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'e.g. 10  (blank = unlimited)',
                      hintStyle:
                          AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _sectionHeader(String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          Text(sub,
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
        ],
      );

  Widget _searchField({required String hint, required ValueChanged<String> onChanged}) =>
      TextField(
        onChanged: onChanged,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          prefixIcon:
              const Icon(Icons.search, color: AppColors.textSecondary, size: 18),
          filled: true,
          fillColor: AppColors.elevated,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      );

  Widget _checkRow({
    required String title,
    required String subtitle,
    required bool checked,
    required bool isLast,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: (_) => onTap(),
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w500)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _emptyRow(String msg) => Padding(
        padding: const EdgeInsets.all(16),
        child:
            Text(msg, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
      );
}
