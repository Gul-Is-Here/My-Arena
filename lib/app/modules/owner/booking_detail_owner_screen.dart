import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/owner_booking_controller.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';

const _bg = Color(0xFF10131A);
const _surface = Color(0xFF1D2026);
const _surfaceLow = Color(0xFF191C22);
const _outline = Color(0xFF3B494B);
const _cyan = Color(0xFF00DBE9);
const _greenFixed = Color(0xFF79FF5B);
const _amber = Color(0xFFFFB59C);
const _red = Color(0xFFFFB4AB);
const _onSurface = Color(0xFFE1E2EB);
const _onSurfaceVar = Color(0xFFB9CACB);

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
  }
}

Color _statusColor(BookingStatus s) {
  switch (s) {
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
    final String id = Get.arguments as String;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Obx(() {
          final b = c.bookings.firstWhereOrNull((x) => x.id == id);
          if (b == null) {
            return const Center(
              child: Text('Booking not found',
                  style: TextStyle(color: _onSurfaceVar)),
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
                    if (b.depositScreenshot != null) ...[
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
          const Text(
            'Booking Details',
            style: TextStyle(
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
                    style: TextStyle(
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
                                style: const TextStyle(
                                    color: _cyan,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800))))
                    : Center(
                        child: Text(initials,
                            style: const TextStyle(
                                color: _cyan, fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: _onSurface, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    if ((user?.phone.isNotEmpty ?? false)) ...[
                      Row(
                        children: [
                          const Icon(Icons.call_outlined, size: 14, color: _onSurfaceVar),
                          const SizedBox(width: 6),
                          Text(user!.phone,
                              style: const TextStyle(color: _onSurfaceVar, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (user?.createdAt != null)
                      Row(
                        children: [
                          const Icon(Icons.star, size: 13, color: _cyan),
                          const SizedBox(width: 6),
                          Text('Customer since ${_fmtMonthYear(user!.createdAt!)}',
                              style: const TextStyle(
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
              const Text('Summary',
                  style: TextStyle(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _outline),
                ),
                child: Text(b.bookedByRole == 'customer' ? 'Customer' : 'Walk-in',
                    style: const TextStyle(
                        color: _onSurfaceVar, fontSize: 11, fontWeight: FontWeight.w700)),
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
                    Text(label, style: const TextStyle(color: _onSurfaceVar, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(
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
    final hasScreenshot = b.depositScreenshot != null;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Info',
              style: TextStyle(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _amountRow('Subtotal', 'PKR ${b.totalAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: _greenFixed),
                  SizedBox(width: 8),
                  Text('Deposit Paid',
                      style: TextStyle(
                          color: _greenFixed, fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              Text('PKR ${b.depositAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
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
              const Text('Payment Status',
                  style: TextStyle(color: _onSurfaceVar, fontSize: 13)),
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
                        style: TextStyle(
                            color: hasScreenshot ? _cyan : _amber,
                            fontSize: 11,
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
          Text(label, style: const TextStyle(color: _onSurfaceVar, fontSize: 13.5)),
          Text(value,
              style: const TextStyle(color: _onSurface, fontSize: 14.5, fontWeight: FontWeight.w700)),
        ],
      );

  Widget _depositProofCard(BuildContext context, BookingModel b) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deposit Proof',
              style: TextStyle(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text('View Screenshot',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
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
          const Text('Cancellation & Refund',
              style: TextStyle(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
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
              label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
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
                label: const Text('Approve Booking',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReject(
      BuildContext context, OwnerBookingController c, BookingModel b) async {
    final user = await _fetchCustomer(b.customerId);
    final name = b.customerName.isNotEmpty ? b.customerName : (user?.name ?? 'This customer');
    Get.defaultDialog(
      backgroundColor: _surfaceLow,
      titleStyle: const TextStyle(color: _onSurface, fontWeight: FontWeight.w800),
      middleTextStyle: const TextStyle(color: _onSurfaceVar),
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
              const Text('Deposit Screenshot',
                  style: TextStyle(color: _onSurface, fontSize: 18, fontWeight: FontWeight.w800)),
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
                child: const Text('Close', style: TextStyle(color: _cyan)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
