import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/staff_management_controller.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/profile_tab.dart';

/// Dashboard for arena-assigned staff (role=staff with ownerId set).
class ArenaStaffDashboardScreen extends StatefulWidget {
  const ArenaStaffDashboardScreen({super.key});

  @override
  State<ArenaStaffDashboardScreen> createState() =>
      _ArenaStaffDashboardScreenState();
}

class _ArenaStaffDashboardScreenState extends State<ArenaStaffDashboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<StaffManagementController>()) {
      Get.put(StaffManagementController(), permanent: true);
    }

    final tabs = [
      const _ArenasTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      extendBody: true,
      body: tabs[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.stadium_outlined),
            selectedIcon: Icon(Icons.stadium),
            label: 'My Arenas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ── Arenas tab ────────────────────────────────────────────────────────────────

class _ArenasTab extends StatelessWidget {
  const _ArenasTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = AuthController.to.currentUser.value;
      if (user == null) return const SizedBox.shrink();

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Arenas'),
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              onPressed: () => AuthController.to.signOut(),
              tooltip: 'Sign out',
            ),
          ],
        ),
        body: user.assignedArenas.isEmpty
            ? _empty()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: user.assignedArenas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    _ArenaCard(arenaId: user.assignedArenas[i], user: user),
              ),
      );
    });
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.stadium_outlined,
              size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text('No arenas assigned', style: AppTextStyles.titleMedium),
          const SizedBox(height: 6),
          Text('Contact your owner to assign arenas.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Arena Card ────────────────────────────────────────────────────────────────

class _ArenaCard extends StatefulWidget {
  final String arenaId;
  final UserModel user;

  const _ArenaCard({required this.arenaId, required this.user});

  @override
  State<_ArenaCard> createState() => _ArenaCardState();
}

class _ArenaCardState extends State<_ArenaCard> {
  String _arenaName = '';
  String _arenaLocation = '';

  @override
  void initState() {
    super.initState();
    _loadArena();
  }

  Future<void> _loadArena() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('arenas')
          .doc(widget.arenaId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _arenaName = data['name'] ?? widget.arenaId;
          _arenaLocation = data['location'] ?? '';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final canEditArena = widget.user.canEditArena(widget.arenaId);
    final canEditCourts = widget.user.canEditCourts(widget.arenaId);
    final hasAnyEditPerm = canEditArena || canEditCourts;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.stadium,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _arenaName.isNotEmpty ? _arenaName : widget.arenaId,
                      style: AppTextStyles.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_arenaLocation.isNotEmpty)
                      Text(_arenaLocation,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    if (hasAnyEditPerm) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: [
                          if (canEditArena)
                            _permChip('Edit Arena', AppColors.primary),
                          if (canEditCourts)
                            _permChip('Edit Courts', AppColors.secondary),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionBtn(
                icon: Icons.calendar_month_outlined,
                label: 'Bookings',
                onTap: () => Get.toNamed(AppRoutes.ownerBookings),
              ),
              _actionBtn(
                icon: Icons.calendar_view_week_outlined,
                label: 'Schedule',
                onTap: () => Get.toNamed(AppRoutes.ownerSchedule),
              ),
              _actionBtn(
                icon: Icons.qr_code_scanner,
                label: 'Scan QR',
                onTap: () => Get.toNamed(AppRoutes.ownerQrScanner),
              ),
              if (canEditArena)
                _actionBtn(
                  icon: Icons.edit_outlined,
                  label: 'Edit Arena',
                  color: AppColors.primary,
                  onTap: () => Get.toNamed(AppRoutes.editArena,
                      arguments: widget.arenaId),
                ),
              if (canEditCourts)
                _actionBtn(
                  icon: Icons.sports_tennis_outlined,
                  label: 'Edit Courts',
                  color: AppColors.secondary,
                  onTap: () => Get.toNamed(AppRoutes.arenaDetailOwner,
                      arguments: widget.arenaId),
                ),
            ],
          ),
          if (!hasAnyEditPerm) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showRequestPermSheet(context),
              icon: const Icon(Icons.shield_outlined, size: 16),
              label: const Text('Request Edit Access'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _permChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: AppTextStyles.bodySmall
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.textSecondary,
  }) {
    return Material(
      color: AppColors.elevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  void _showRequestPermSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RequestPermSheet(
        arenaId: widget.arenaId,
        arenaName: _arenaName.isNotEmpty ? _arenaName : widget.arenaId,
      ),
    );
  }
}

// ── Permission request sheet ──────────────────────────────────────────────────

class _RequestPermSheet extends StatefulWidget {
  final String arenaId;
  final String arenaName;
  const _RequestPermSheet({required this.arenaId, required this.arenaName});

  @override
  State<_RequestPermSheet> createState() => _RequestPermSheetState();
}

class _RequestPermSheetState extends State<_RequestPermSheet> {
  bool _editArena = false;
  bool _editCourts = false;
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final perms = [
      if (_editArena) 'edit_arena',
      if (_editCourts) 'edit_courts',
    ];
    if (perms.isEmpty) {
      Get.snackbar('Select Permission',
          'Choose at least one permission to request.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (!Get.isRegistered<StaffManagementController>()) {
      Get.put(StaffManagementController());
    }
    await Get.find<StaffManagementController>().requestPermission(
      arenaId: widget.arenaId,
      arenaName: widget.arenaName,
      permissions: perms,
      reason: _reasonCtrl.text.trim(),
    );
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Request Edit Access', style: AppTextStyles.titleLarge),
          Text(
            'For: ${widget.arenaName}',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text('Your owner will review and approve this request.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          CheckboxListTile(
            value: _editArena,
            onChanged: (v) => setState(() => _editArena = v ?? false),
            title: const Text('Edit Arena Info',
                style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text('Name, address, description, hours',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            activeColor: AppColors.primary,
            checkColor: AppColors.onPrimary,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _editCourts,
            onChanged: (v) => setState(() => _editCourts = v ?? false),
            title: const Text('Edit Courts',
                style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text('Add / edit / deactivate courts',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            activeColor: AppColors.primary,
            checkColor: AppColors.onPrimary,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Reason (optional)',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.elevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Send Request',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
