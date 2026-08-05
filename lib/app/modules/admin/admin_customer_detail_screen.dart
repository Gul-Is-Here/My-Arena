import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/models/booking_model.dart';
import '../../data/models/user_model.dart';
import '../../repositories/admin_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class AdminCustomerDetailScreen extends StatefulWidget {
  const AdminCustomerDetailScreen({super.key});

  @override
  State<AdminCustomerDetailScreen> createState() =>
      _AdminCustomerDetailScreenState();
}

class _AdminCustomerDetailScreenState
    extends State<AdminCustomerDetailScreen> {
  late UserModel _user;
  final _db = FirebaseFirestore.instance;
  final _repo = AdminRepository();

  final _bookings = <BookingModel>[].obs;
  final _isLoading = true.obs;
  final _isActing = false.obs;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _user = Get.arguments as UserModel;
    _sub = _db
        .collection('bookings')
        .where('customerId', isEqualTo: _user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((s) {
      _bookings.assignAll(
        s.docs
            .map((d) => BookingModel.fromMap({...d.data(), 'id': d.id}))
            .toList(),
      );
      _isLoading.value = false;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _toggleBan() async {
    _isActing.value = true;
    await _repo.toggleBan(_user);
    // Refresh from Firestore
    final doc = await _db.collection('users').doc(_user.uid).get();
    if (doc.exists) {
      _user = UserModel.fromMap({...doc.data()!, 'uid': doc.id});
    }
    _isActing.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(_user.name),
        actions: [
          Obx(() => _isActing.value
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              : IconButton(
                  tooltip: _user.isActive ? 'Suspend user' : 'Unsuspend user',
                  icon: Icon(
                    _user.isActive ? Icons.block : Icons.check_circle_outline,
                    color:
                        _user.isActive ? AppColors.error : AppColors.success,
                  ),
                  onPressed: _toggleBan,
                )),
        ],
      ),
      body: Obx(() {
        final bkgs = _bookings;
        final totalSpend =
            bkgs.fold(0.0, (s, b) => s + b.totalAmount);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _profileCard(),
            const SizedBox(height: 12),
            _statsRow(bkgs.length, totalSpend),
            const SizedBox(height: 12),
            _sectionTitle('Booking History'),
            if (_isLoading.value)
              const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary))
            else if (bkgs.isEmpty)
              _empty('No bookings yet')
            else
              ...bkgs.map((b) => _bookingRow(b)),
          ],
        );
      }),
    );
  }

  Widget _profileCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.elevated,
              backgroundImage:
                  _user.avatar.isNotEmpty ? NetworkImage(_user.avatar) : null,
              child: _user.avatar.isEmpty
                  ? Text(
                      _user.name.isNotEmpty ? _user.name[0].toUpperCase() : '?',
                      style: AppTextStyles.headlineMedium
                          .copyWith(color: AppColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(_user.name,
                              style: AppTextStyles.titleMedium
                                  .copyWith(fontWeight: FontWeight.w700))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_user.isActive
                                  ? AppColors.success
                                  : AppColors.error)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _user.isActive ? 'Active' : 'Suspended',
                          style: AppTextStyles.caption.copyWith(
                            color: _user.isActive
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_user.email,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                  if (_user.phone.isNotEmpty)
                    Text(_user.phone,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                  if (_user.createdAt != null)
                    Text(
                      'Joined ${DateFormat('MMM yyyy').format(_user.createdAt!)}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textDisabled),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _statsRow(int bookings, double spend) => Row(
        children: [
          Expanded(child: _statCard('Bookings', '$bookings', Icons.calendar_month)),
          const SizedBox(width: 10),
          Expanded(
              child: _statCard('Total Spend',
                  'PKR ${spend.toStringAsFixed(0)}', Icons.payments_outlined)),
        ],
      );

  Widget _statCard(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                Text(value,
                    style: AppTextStyles.titleMedium
                        .copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: AppTextStyles.titleMedium
                .copyWith(fontWeight: FontWeight.w700)),
      );

  Widget _bookingRow(BookingModel b) {
    final color = b.isCancelled ? AppColors.error : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
              width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${b.arenaName} • ${b.courtName}',
                    style: AppTextStyles.bodyMedium),
                Text(
                    '${DateFormat("d MMM").format(b.date)} • ${b.timeRange}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PKR ${b.totalAmount.toStringAsFixed(0)}',
                  style: AppTextStyles.caption
                      .copyWith(fontWeight: FontWeight.w600)),
              Text(b.status.label,
                  style: AppTextStyles.caption
                      .copyWith(color: color, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: Text(msg,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary))),
      );
}
