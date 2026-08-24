import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/admin_booking_controller.dart';
import '../../data/models/booking_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class AdminBookingDetailScreen extends StatelessWidget {
  const AdminBookingDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Get.arguments;
    if (b is! BookingModel) return const SizedBox.shrink();
    final ctrl = AdminBookingController.to;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Booking #${b.id.substring(0, 8)}…'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusBanner(b),
          const SizedBox(height: 16),
          _section('Customer', [
            _row('Name', b.customerName),
            _row('ID', b.customerId),
          ]),
          _section('Venue', [
            _row('Arena', b.arenaName),
            _row('Court', b.courtName),
          ]),
          _section('Schedule', [
            _row('Date', DateFormat('EEEE, d MMM yyyy').format(b.date)),
            _row('Time', b.timeRange),
            _row('Duration', '${b.totalHours} hour${b.totalHours > 1 ? "s" : ""}'),
          ]),
          _section('Payment', [
            _row('Total', 'PKR ${b.totalAmount.toStringAsFixed(0)}'),
            _row('Deposit', 'PKR ${b.depositAmount.toStringAsFixed(0)}'),
            _row('Remaining', 'PKR ${b.remainingAmount.toStringAsFixed(0)}'),
            _row('Platform fee (10%)',
                'PKR ${(b.totalAmount * 0.10).toStringAsFixed(0)}'),
            _row('Owner share (90%)',
                'PKR ${(b.totalAmount * 0.90).toStringAsFixed(0)}'),
          ]),
          _section('Meta', [
            _row('Booked by', b.bookedByRole),
            _row('Created',
                DateFormat('d MMM yyyy, HH:mm').format(b.createdAt)),
            _row('Checked in', b.checkedIn ? 'Yes' : 'No'),
            if (b.noShow) _row('No-show', 'Yes'),
            if (b.isGroupBooking)
              _row('Group booking', '${b.groupSize} players'),
          ]),
          const SizedBox(height: 16),
          _ActionPanel(booking: b, ctrl: ctrl),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _statusBanner(BookingModel b) {
    final color = _statusColor(b.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 10),
          Text(b.status.label,
              style: AppTextStyles.titleMedium
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.textDisabled,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(label,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(value,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  Color _statusColor(BookingStatus s) => switch (s) {
        BookingStatus.confirmed => AppColors.success,
        BookingStatus.completed => AppColors.secondary,
        BookingStatus.cancelled || BookingStatus.rejected => AppColors.error,
        BookingStatus.refundPending ||
        BookingStatus.refundSent ||
        BookingStatus.refundConfirmed =>
          AppColors.warning,
        _ => AppColors.textSecondary,
      };
}

class _ActionPanel extends StatelessWidget {
  final BookingModel booking;
  final AdminBookingController ctrl;
  const _ActionPanel({required this.booking, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final canApprove = b.status == BookingStatus.depositSubmitted;
    final canCancel = b.status != BookingStatus.cancelled &&
        b.status != BookingStatus.completed &&
        b.status != BookingStatus.rejected;
    final canRefund = b.status == BookingStatus.cancelled ||
        b.status == BookingStatus.depositSubmitted ||
        b.status == BookingStatus.confirmed;
    final canComplete = b.status == BookingStatus.confirmed;

    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Admin Actions',
                style: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (canApprove)
              _btn('Approve Booking', AppColors.success, Icons.check_circle,
                  () => ctrl.approveBooking(b)),
            if (canCancel)
              _btn('Cancel Booking', AppColors.error, Icons.cancel_outlined,
                  () => _reasonDialog(context, 'Cancel', (r) => ctrl.cancelBooking(b, reason: r))),
            if (canComplete)
              _btn('Force Complete', AppColors.secondary, Icons.done_all,
                  () => ctrl.forceComplete(b)),
            if (canRefund)
              _btn('Initiate Refund', AppColors.warning, Icons.replay,
                  () => _reasonDialog(context, 'Refund', (r) => ctrl.refundBooking(b, reason: r))),
            if (ctrl.isActionLoading.value)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(color: AppColors.primary),
              ),
          ],
        ));
  }

  Widget _btn(String label, Color color, IconData icon, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18, color: color),
          label: Text(label, style: TextStyle(color: color)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withOpacity(0.5)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );

  void _reasonDialog(
      BuildContext ctx, String action, void Function(String?) onConfirm) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('$action reason (optional)',
            style: AppTextStyles.titleMedium),
        content: TextField(
          controller: reasonCtrl,
          style: AppTextStyles.bodyMedium,
          decoration: const InputDecoration(
            hintText: 'Enter reason…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              onConfirm(
                  reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(action,
                style: const TextStyle(color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }
}
