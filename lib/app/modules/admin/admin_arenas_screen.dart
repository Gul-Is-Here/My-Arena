import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';
import '../owner/add_arena_screen.dart';

enum _ArenaFilter { all, pending, approved, rejected, suspended, featured, carousel }

/// Arena management — Pending approvals | All arenas with search & filters.
class AdminArenasScreen extends StatefulWidget {
  const AdminArenasScreen({super.key});

  @override
  State<AdminArenasScreen> createState() => _AdminArenasScreenState();
}

class _AdminArenasScreenState extends State<AdminArenasScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _ArenaFilter _filter = _ArenaFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ArenaModel> _applyFilter(List<ArenaModel> src) {
    var list = switch (_filter) {
      _ArenaFilter.all => src,
      _ArenaFilter.pending => src.where((a) => a.status == ArenaStatus.pending).toList(),
      _ArenaFilter.approved => src.where((a) => a.status == ArenaStatus.approved).toList(),
      _ArenaFilter.rejected => src.where((a) => a.status == ArenaStatus.rejected).toList(),
      _ArenaFilter.suspended => src.where((a) => !a.isActive).toList(),
      _ArenaFilter.featured => src.where((a) => a.isFeatured).toList(),
      _ArenaFilter.carousel => src.where((a) => a.showOnHomeCarousel).toList(),
    };
    final q = _query.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((a) {
        return a.name.toLowerCase().contains(q) ||
            a.location.address.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminController.to;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('Arena Management'),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
            tabs: [
              Obx(() => Tab(text: 'Pending (${admin.pendingArenas.length})')),
              const Tab(text: 'All Arenas'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Add Arena for Owner'),
          onPressed: () => _showOwnerPicker(context, admin),
        ),
        body: Obx(() {
          admin.arenas.length;
          return TabBarView(
            children: [
              _pendingTab(admin),
              _allTab(admin),
            ],
          );
        }),
      ),
    );
  }

  void _showOwnerPicker(BuildContext context, AdminController admin) {
    final owners = admin.users
        .where((u) => u.role == UserRole.owner)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final searchCtrl = TextEditingController();
    String query = '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = query.isEmpty
              ? owners
              : owners
                  .where((u) =>
                      u.name.toLowerCase().contains(query) ||
                      u.email.toLowerCase().contains(query))
                  .toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (_, scrollCtrl) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Select Owner',
                      style: AppTextStyles.titleLarge
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchCtrl,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Search by name or email',
                        hintStyle: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textSecondary, size: 20),
                        filled: true,
                        fillColor: AppColors.elevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onChanged: (v) =>
                          setSheetState(() => query = v.toLowerCase()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        owners.isEmpty
                            ? 'No owners found. Invite an owner first.'
                            : 'No owners match your search.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final u = filtered[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                u.name.isNotEmpty
                                    ? u.name[0].toUpperCase()
                                    : '?',
                                style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(u.name,
                                style: AppTextStyles.bodyMedium
                                    .copyWith(fontWeight: FontWeight.w600)),
                            subtitle: Text(u.email,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondary)),
                            trailing: u.isActive
                                ? null
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Pending',
                                        style: AppTextStyles.caption
                                            .copyWith(color: Colors.orange)),
                                  ),
                            onTap: () {
                              Navigator.pop(ctx);
                              Get.to(
                                () => AddArenaScreen(
                                  ownerIdOverride: u.uid,
                                  ownerNameOverride: u.name,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Pending tab ──────────────────────────────────────────────────────────

  Widget _pendingTab(AdminController admin) {
    final items = admin.pendingArenas;
    if (items.isEmpty) {
      return Center(
        child: Text('No arenas awaiting approval',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final a = items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            onTap: () => Get.toNamed(AppRoutes.adminArenaDetail, arguments: a.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _arenaHeader(a),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rejectWithReason(admin, a),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => admin.setArenaStatus(a.id, ArenaStatus.approved),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _rejectWithReason(AdminController admin, ArenaModel a) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Reject "${a.name}"',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Reason for rejection (required)',
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.elevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (reason != null && reason.isNotEmpty) {
      admin.setArenaStatus(a.id, ArenaStatus.rejected, reason: reason);
    }
  }

  // ── All arenas tab with search & filters ─────────────────────────────────

  Widget _allTab(AdminController admin) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            style: AppTextStyles.bodyMedium,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search name, city, address…',
              hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
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
        Container(
          color: AppColors.surface,
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            children: _ArenaFilter.values.map((f) {
              final label = switch (f) {
                _ArenaFilter.all => 'All',
                _ArenaFilter.pending => 'Pending',
                _ArenaFilter.approved => 'Approved',
                _ArenaFilter.rejected => 'Rejected',
                _ArenaFilter.suspended => 'Suspended',
                _ArenaFilter.featured => 'Featured',
                _ArenaFilter.carousel => 'Carousel',
              };
              final sel = _filter == f;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
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
            }).toList(),
          ),
        ),
        Expanded(
          child: Builder(builder: (_) {
            final filtered = _applyFilter(admin.arenas.toList());
            if (filtered.isEmpty) {
              return Center(
                child: Text('No arenas match',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final a = filtered[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => Get.toNamed(AppRoutes.adminArenaDetail, arguments: a.id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _arenaHeader(a),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              a.isActive ? 'Visible to customers' : 'Hidden (OFF)',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: a.isActive ? AppColors.success : AppColors.error,
                              ),
                            ),
                            Switch(
                              value: a.isActive,
                              activeThumbColor: AppColors.success,
                              onChanged: (_) => admin.toggleArenaActive(a.id),
                            ),
                          ],
                        ),
                        if (a.status == ArenaStatus.rejected &&
                            a.rejectionReason != null &&
                            a.rejectionReason!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Rejected: ${a.rejectionReason}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _arenaHeader(ArenaModel a) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name, style: AppTextStyles.titleMedium),
                Text(a.location.address,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey)),
                const SizedBox(height: 4),
                Text('${a.courts.length} court${a.courts.length == 1 ? '' : 's'}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey)),
              ],
            ),
          ),
          StatusBadge(status: a.status.name),
        ],
      );
}
