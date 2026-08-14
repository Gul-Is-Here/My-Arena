import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/owner_booking_controller.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

const _bg = AppColors.background;
const _surface = AppColors.surface;
const _surfaceLow = AppColors.elevated;
const _outline = AppColors.border;
const _cyan = AppColors.primary;
const _greenFixed = AppColors.success;
const _amber = AppColors.warning;
const _red = AppColors.error;
const _onSurface = AppColors.textPrimary;
const _onSurfaceVar = AppColors.textSecondary;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String _fmtMonthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

String _statusLabel(BookingStatus s) {
  switch (s) {
    case BookingStatus.pendingDeposit:
      return 'Deposit Pending';
    case BookingStatus.depositSubmitted:
      return 'Pending Approval';
    case BookingStatus.confirmed:
      return 'Confirmed';
    case BookingStatus.rejected:
      return 'Rejected';
    case BookingStatus.completed:
      return 'Completed';
    case BookingStatus.cancelled:
      return 'Cancelled';
    case BookingStatus.refundPending:
      return 'Refund Pending';
    case BookingStatus.refundSent:
      return 'Refund Sent';
    case BookingStatus.refundConfirmed:
      return 'Refund Confirmed';
    case BookingStatus.ongoing:
      return 'Ongoing';
    case BookingStatus.rescheduleRequested:
      return 'Reschedule Requested';
  }
}

Color _statusColor(BookingStatus s) {
  switch (s) {
    case BookingStatus.ongoing:
    case BookingStatus.confirmed:
    case BookingStatus.completed:
    case BookingStatus.refundConfirmed:
      return _greenFixed;
    case BookingStatus.rejected:
    case BookingStatus.cancelled:
      return _red;
    case BookingStatus.pendingDeposit:
    case BookingStatus.depositSubmitted:
    case BookingStatus.refundPending:
    case BookingStatus.refundSent:
    case BookingStatus.rescheduleRequested:
      return _amber;
  }
}

// Resolves the customer's live profile (name, phone, avatar, join date) for
// this booking, since BookingModel only stores a name snapshot. Cached by
// uid so repeated Obx rebuilds don't refetch.
final Map<String, UserModel?> _customerCache = {};

Future<UserModel?> _fetchCustomer(String uid) async {
  if (uid.isEmpty) return null;
  if (_customerCache.containsKey(uid)) return _customerCache[uid];
  final user = await AuthService().fetchUser(uid);
  _customerCache[uid] = user;
  return user;
}

/// Full booking details for the owner. Route argument: booking id.
class BookingDetailOwnerScreen extends StatelessWidget {
  const BookingDetailOwnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = OwnerBookingController.to;
    final String? id = Get.arguments as String?;
    if (id == null) {
      return const Scaffold(body: Center(child: Text('No booking selected')));
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Obx(() {
          final b = c.bookings.firstWhereOrNull((x) => x.id == id);
          if (b == null) {
            return Center(
              child: Text('Booking not found',
                  style: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar)),
            );
          }
          final sColor = _statusColor(b.status);
          return Column(
            children: [
              _header(b, sColor),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _customerCard(b),
                    const SizedBox(height: 14),
                    _summaryCard(b),
                    const SizedBox(height: 14),
                    _paymentCard(b),
                    if (!b.isPosBooking && b.depositScreenshot != null) ...[
                      const SizedBox(height: 14),
                      _depositProofCard(context, b),
                    ],
                    if (b.cancellation != null) ...[
                      const SizedBox(height: 14),
                      _refundCard(b),
                    ],
                  ],
                ),
              ),
              if (b.status == BookingStatus.depositSubmitted)
                _actionBar(context, c, b),
              if (b.status == BookingStatus.refundPending)
                _refundSentBar(context, b),
              if (b.status == BookingStatus.rescheduleRequested &&
                  b.rescheduleRequest != null)
                _rescheduleBar(context, c, b),
              if (b.status == BookingStatus.confirmed &&
                  DateTime.now().isAfter(b.endDateTime) &&
                  !b.noShow &&
                  !b.checkedIn)
                _noShowBar(context, c, b),
            ],
          );
        }),
      ),
    );
  }

  Widget _header(BookingModel b, Color sColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: Get.back,
            icon: const Icon(Icons.arrow_back, color: _onSurface),
          ),
          Text(
            'Booking Details',
            style: AppTextStyles.titleLarge.copyWith(
                color: _onSurface, fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: sColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(_statusLabel(b.status),
                    style: AppTextStyles.caption.copyWith(
                        color: sColor, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outline),
        ),
        child: child,
      );

  Widget _customerCard(BookingModel b) {
    return _card(
      child: FutureBuilder<UserModel?>(
        future: _fetchCustomer(b.customerId),
        builder: (context, snap) {
          final user = snap.data;
          final name =
              b.customerName.isNotEmpty ? b.customerName : (user?.name ?? 'Customer');
          final initials = name.trim().isEmpty
              ? '?'
              : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cyan, width: 1.4),
                  boxShadow: [
                    BoxShadow(color: _cyan.withValues(alpha: 0.3), blurRadius: 10),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: (user?.avatar.isNotEmpty ?? false)
                    ? Image.network(user!.avatar, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                            child: Text(initials,
                                style: AppTextStyles.titleLarge.copyWith(
                                    color: _cyan,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800))))
                    : Center(
                        child: Text(initials,
                            style: AppTextStyles.titleLarge.copyWith(
                                color: _cyan, fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: AppTextStyles.titleLarge.copyWith(
                            color: _onSurface, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    if ((user?.phone.isNotEmpty ?? false)) ...[
                      Row(
                        children: [
                          const Icon(Icons.call_outlined, size: 14, color: _onSurfaceVar),
                          const SizedBox(width: 6),
                          Text(user!.phone,
                              style: AppTextStyles.bodySmall.copyWith(color: _onSurfaceVar, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (user?.createdAt != null)
                      Row(
                        children: [
                          const Icon(Icons.star, size: 13, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('Customer since ${_fmtMonthYear(user!.createdAt!)}',
                              style: AppTextStyles.label.copyWith(
                                  color: _cyan, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _openChat(b),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: _outline),
                  ),
                  child: const Icon(Icons.chat_bubble_outline, size: 18, color: _cyan),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(BookingModel b) {
    final bookingRef = '#${b.id.replaceFirst('booking-', '').replaceFirst('ob-', '')}';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Summary',
                  style: AppTextStyles.titleMedium.copyWith(color: _onSurface, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _outline),
                ),
                child: Text(b.bookedByRole == 'customer' ? 'Customer' : 'Walk-in',
                    style: AppTextStyles.caption.copyWith(
                        color: _onSurfaceVar, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _summaryRow(Icons.stadium_outlined, 'Arena', b.arenaName),
          _summaryRow(Icons.sports_soccer_outlined, 'Court', b.courtName),
          _summaryRow(Icons.calendar_today_outlined, 'Date', _fmtDate(b.date)),
          _summaryRow(Icons.schedule_outlined, 'Time Slot', b.timeRange),
          _summaryRow(Icons.timer_outlined, 'Duration',
              '${b.totalHours} Hour${b.totalHours > 1 ? 's' : ''}'),
          _summaryRow(Icons.tag, 'Booking ID', bookingRef, isLast: true),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _outline),
                ),
                child: Icon(icon, size: 16, color: _cyan),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.bodySmall.copyWith(color: _onSurfaceVar, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: AppTextStyles.titleMedium.copyWith(
                            color: _onSurface, fontSize: 14.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: _outline),
      ],
    );
  }

  Widget _paymentCard(BookingModel b) {
    if (b.isPosBooking) return _posPaymentCard(b);
    final hasScreenshot = b.depositScreenshot != null;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Info',
              style: AppTextStyles.titleMedium.copyWith(color: _onSurface, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _amountRow('Subtotal', 'PKR ${b.totalAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: _greenFixed),
                  const SizedBox(width: 8),
                  Text('Deposit Paid',
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: _greenFixed, fontWeight: FontWeight.w700)),
                ],
              ),
              Text('PKR ${b.depositAmount.toStringAsFixed(0)}',
                  style: AppTextStyles.titleMedium.copyWith(
                      color: _greenFixed, fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          _amountRow('Due at Venue', 'PKR ${b.remainingAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _outline),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment Status',
                  style: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (hasScreenshot ? _cyan : _amber).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: (hasScreenshot ? _cyan : _amber).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(hasScreenshot ? Icons.image_outlined : Icons.hourglass_empty,
                        size: 13, color: hasScreenshot ? _cyan : _amber),
                    const SizedBox(width: 5),
                    Text(hasScreenshot ? 'Screenshot Uploaded' : 'Awaiting Screenshot',
                        style: AppTextStyles.caption.copyWith(
                            color: hasScreenshot ? _cyan : _amber,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _posPaymentCard(BookingModel b) {
    final paid = b.amountPaid ?? 0;
    final remaining = b.remainingAmount;
    final fullyPaid = remaining <= 0;
    final method = b.posPaymentMethod ?? 'cash';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Info',
              style: AppTextStyles.titleMedium.copyWith(color: _onSurface, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _amountRow('Court Total', 'PKR ${b.totalAmount.toStringAsFixed(0)}'),
          if (b.posDiscount > 0) ...[
            const SizedBox(height: 8),
            _amountRow('Discount', '− PKR ${b.posDiscount.toStringAsFixed(0)}'),
          ],
          if (b.posAddOnsTotal > 0) ...[
            const SizedBox(height: 8),
            _amountRow('Add-ons', '+ PKR ${b.posAddOnsTotal.toStringAsFixed(0)}'),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: _greenFixed),
                  const SizedBox(width: 8),
                  Text('Amount Paid',
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: _greenFixed, fontWeight: FontWeight.w700)),
                ],
              ),
              Text('PKR ${paid.toStringAsFixed(0)}',
                  style: AppTextStyles.titleMedium.copyWith(
                      color: _greenFixed, fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          _amountRow('Balance Due', 'PKR ${remaining.toStringAsFixed(0)}'),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _outline),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment Method',
                  style: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar, fontSize: 13)),
              Text(method[0].toUpperCase() + method.substring(1),
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: _onSurface, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment Status',
                  style: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (fullyPaid ? _greenFixed : _amber).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: (fullyPaid ? _greenFixed : _amber).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(fullyPaid ? Icons.check_circle_outline : Icons.pending_outlined,
                        size: 13, color: fullyPaid ? _greenFixed : _amber),
                    const SizedBox(width: 5),
                    Text(fullyPaid ? 'Fully Paid' : 'Balance Pending',
                        style: AppTextStyles.caption.copyWith(
                            color: fullyPaid ? _greenFixed : _amber,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar, fontSize: 13.5)),
          Text(value,
              style: AppTextStyles.titleMedium.copyWith(color: _onSurface, fontSize: 14.5, fontWeight: FontWeight.w700)),
        ],
      );

  Widget _depositProofCard(BuildContext context, BookingModel b) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Deposit Proof',
              style: AppTextStyles.titleMedium.copyWith(color: _onSurface, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showScreenshot(context, b),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  b.depositScreenshot!.startsWith('http')
                      ? Image.network(
                          b.depositScreenshot!,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 220,
                            color: _surface,
                            child: const Icon(Icons.broken_image, color: _onSurfaceVar),
                          ),
                        )
                      : Container(height: 220, color: _surface),
                  Positioned.fill(
                    child: Container(color: Colors.black.withValues(alpha: 0.35)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('View Screenshot',
                            style: AppTextStyles.label.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _refundCard(BookingModel b) {
    final cx = b.cancellation!;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cancellation & Refund',
              style: AppTextStyles.titleMedium.copyWith(color: _onSurface, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _summaryRow(
              Icons.event_busy_outlined, 'Requested', _fmtDate(cx.requestedAt)),
          _summaryRow(Icons.account_balance_outlined, 'Account',
              '${cx.bankName} · ${cx.accountNumber}'),
          _summaryRow(Icons.currency_exchange, 'Refund Due',
              'PKR ${cx.refundAmount.toStringAsFixed(0)}', isLast: true),
        ],
      ),
    );
  }

  Widget _actionBar(BuildContext context, OwnerBookingController c, BookingModel b) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _confirmReject(context, c, b),
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                backgroundColor: _red.withValues(alpha: 0.08),
                side: BorderSide(color: _red.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.close, size: 18),
              label: Text('Reject', style: AppTextStyles.button.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: _greenFixed.withValues(alpha: 0.3), blurRadius: 14),
                ],
              ),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await c.approve(b.id);
                  final user = await _fetchCustomer(b.customerId);
                  final name = b.customerName.isNotEmpty
                      ? b.customerName
                      : (user?.name ?? 'Customer');
                  Get.back();
                  Get.snackbar('Booking confirmed', '$name will be notified.',
                      snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(16));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _greenFixed,
                  side: const BorderSide(color: _greenFixed),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text('Approve Booking',
                    style: AppTextStyles.button.copyWith(fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _refundSentBar(BuildContext context, BookingModel b) {
    final refCtrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: _surfaceLow,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => Padding(
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: _outline, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Mark Refund Sent',
                        style: AppTextStyles.titleLarge.copyWith(color: _onSurface, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your bank transfer reference so the customer can verify receipt.',
                      style: AppTextStyles.bodySmall.copyWith(color: _onSurfaceVar, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: refCtrl,
                      style: AppTextStyles.bodyMedium.copyWith(color: _onSurface),
                      decoration: InputDecoration(
                        hintText: 'e.g. TRN-20240712-001',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar),
                        filled: true,
                        fillColor: _surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _outline)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _outline)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cyan)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final ref = refCtrl.text.trim();
                          if (ref.isEmpty) {
                            Get.snackbar('Required', 'Enter a bank transfer reference.',
                                snackPosition: SnackPosition.BOTTOM);
                            return;
                          }
                          await BookingService().submitRefundWithRef(b.id, ref);
                          Get.back();
                          Get.snackbar('Refund Marked', 'Customer will be notified to confirm.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: _surface, colorText: _greenFixed);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Confirm Refund Sent', style: AppTextStyles.button.copyWith(fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.currency_exchange, size: 18),
          label: Text('Mark Refund Sent', style: AppTextStyles.button.copyWith(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _rescheduleBar(BuildContext context, OwnerBookingController c, BookingModel b) {
    final req = b.rescheduleRequest!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _amber.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_calendar_outlined, color: _amber, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Customer Requested Reschedule',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _amber, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_fmtDate(req.proposedDate)} · ${req.timeRange}',
              style: AppTextStyles.bodyMedium.copyWith(color: _onSurface),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await c.rejectReschedule(b.id);
                      Get.back();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: BorderSide(color: _red.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await c.approveReschedule(b.id);
                      Get.back();
                      Get.snackbar('Reschedule Approved',
                          'Booking moved to the new slot.',
                          snackPosition: SnackPosition.BOTTOM,
                          margin: const EdgeInsets.all(16));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _greenFixed,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _noShowBar(BuildContext context, OwnerBookingController c, BookingModel b) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Get.defaultDialog(
            backgroundColor: _surfaceLow,
            titleStyle: AppTextStyles.titleLarge.copyWith(color: _onSurface, fontWeight: FontWeight.w800),
            middleTextStyle: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar),
            title: 'Mark as No-Show?',
            middleText: 'This will complete the booking and flag the customer as a no-show.',
            textCancel: 'Cancel',
            textConfirm: 'Mark No-Show',
            confirmTextColor: Colors.white,
            buttonColor: _amber,
            onConfirm: () async {
              await c.markNoShow(b.id);
              Get.back();
              Get.back();
            },
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _amber,
            backgroundColor: _amber.withValues(alpha: 0.08),
            side: BorderSide(color: _amber.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.person_off_outlined, size: 18),
          label: Text('Mark No-Show', style: AppTextStyles.button.copyWith(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Future<void> _confirmReject(
      BuildContext context, OwnerBookingController c, BookingModel b) async {
    final user = await _fetchCustomer(b.customerId);
    final name = b.customerName.isNotEmpty ? b.customerName : (user?.name ?? 'This customer');
    Get.defaultDialog(
      backgroundColor: _surfaceLow,
      titleStyle: AppTextStyles.titleLarge.copyWith(color: _onSurface, fontWeight: FontWeight.w800),
      middleTextStyle: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar),
      title: 'Reject booking?',
      middleText: '$name\'s deposit will need to be refunded manually.',
      textCancel: 'Back',
      textConfirm: 'Reject',
      confirmTextColor: Colors.white,
      buttonColor: _red,
      onConfirm: () async {
        await c.reject(b.id);
        Get.back();
        Get.back();
      },
    );
  }

  Future<void> _openChat(BookingModel b) async {
    if (!Get.isRegistered<ChatController>()) {
      Get.put(ChatController(), permanent: true);
    }
    final chatId = await ChatController.to.openBookingChat(b);
    Get.toNamed(AppRoutes.chatRoom, arguments: chatId);
  }

  void _showScreenshot(BuildContext context, BookingModel b) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _surfaceLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Deposit Screenshot',
                  style: AppTextStyles.titleLarge.copyWith(color: _onSurface, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  b.depositScreenshot!,
                  height: 340,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 140,
                    child: Center(child: Icon(Icons.broken_image, color: _onSurfaceVar)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: Get.back,
                child: Text('Close', style: AppTextStyles.label.copyWith(color: _onSurfaceVar)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
