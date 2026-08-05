import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/user_model.dart';
import '../../repositories/admin_repository.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

enum _CustomerFilter { all, active, suspended }

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final _db = FirebaseFirestore.instance;
  final _repo = AdminRepository();

  final _searchCtrl = TextEditingController();
  final _customers = <UserModel>[].obs;
  final _filter = _CustomerFilter.all.obs;
  final _query = ''.obs;
  final _isLoading = true.obs;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _db
        .collection('users')
        .where('role', isEqualTo: 'customer')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((s) {
      _customers.assignAll(
        s.docs
            .map((d) => UserModel.fromMap({...d.data(), 'uid': d.id}))
            .toList(),
      );
      _isLoading.value = false;
    });
    _searchCtrl.addListener(() => _query.value = _searchCtrl.text);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<UserModel> get _filtered {
    var list = _customers.toList();
    switch (_filter.value) {
      case _CustomerFilter.active:
        list = list.where((u) => u.isActive).toList();
      case _CustomerFilter.suspended:
        list = list.where((u) => !u.isActive).toList();
      case _CustomerFilter.all:
        break;
    }
    final q = _query.value.toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((u) =>
              u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              (u.phone).contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Customer Management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _searchCtrl,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search name, email, phone…',
                    hintStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textSecondary, size: 20),
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
              _FilterBar(filter: _filter),
            ],
          ),
        ),
      ),
      body: Obx(() {
        if (_isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final list = _filtered;
        if (list.isEmpty) {
          return Center(
            child: Text('No customers found',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (ctx, i) =>
              _CustomerTile(user: list[i], repo: _repo),
        );
      }),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final Rx<_CustomerFilter> filter;
  const _FilterBar({required this.filter});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Obx(() => ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            children: _CustomerFilter.values.map((f) {
              final label = switch (f) {
                _CustomerFilter.all => 'All',
                _CustomerFilter.active => 'Active',
                _CustomerFilter.suspended => 'Suspended',
              };
              final sel = filter.value == f;
              return GestureDetector(
                onTap: () => filter.value = f,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.elevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? AppColors.primary : AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(label,
                      style: AppTextStyles.caption.copyWith(
                        color: sel
                            ? AppColors.onPrimary
                            : AppColors.textSecondary,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w400,
                      )),
                ),
              );
            }).toList(),
          )),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final UserModel user;
  final AdminRepository repo;
  const _CustomerTile({required this.user, required this.repo});

  @override
  Widget build(BuildContext context) {
    final u = user;
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.adminCustomerDetail, arguments: u),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.elevated,
              backgroundImage:
                  u.avatar.isNotEmpty ? NetworkImage(u.avatar) : null,
              child: u.avatar.isEmpty
                  ? Text(
                      u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                      style: AppTextStyles.titleMedium
                          .copyWith(color: AppColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(u.name,
                              style: AppTextStyles.titleMedium
                                  .copyWith(fontWeight: FontWeight.w600))),
                      if (!u.isActive)
                        _badge('Suspended', AppColors.error)
                      else
                        _badge('Active', AppColors.success),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(u.email,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                  if (u.phone.isNotEmpty)
                    Text(u.phone,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: AppTextStyles.caption.copyWith(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}
