import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/owner_booking_controller.dart';
import '../../data/models/booking_model.dart';
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

/// Owner booking management — Pending | All | Refunds, plus a
/// walk-in (manual) booking FAB.
class OwnerBookingsScreen extends StatelessWidget {
  const OwnerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
    final c = OwnerBookingController.to;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _bg,
        extendBody: true,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Bookings',
                  style: TextStyle(
                    color: _onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _outline)),
                ),
                child: TabBar(
                  indicatorColor: _cyan,
                  indicatorWeight: 2,
                  labelColor: _cyan,
                  unselectedLabelColor: _onSurfaceVar,
                  labelStyle:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  unselectedLabelStyle:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  tabs: [
                    Obx(() => Tab(text: 'Pending (${c.pendingApproval.length})')),
                    const Tab(text: 'All'),
                    Obx(() => Tab(text: 'Refunds (${c.refunds.length})')),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  c.bookings.length; // rebuild on any change
                  return TabBarView(
                    children: [
                      _PendingList(controller: c),
                      _AllList(controller: c),
                      _RefundList(controller: c),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
        // GlassNavBar is 74 px tall (64 content + 10 bottom padding).
        // extendBody:true in the outer Scaffold zeroes out the inner Scaffold's
        // FAB bottom offset, so we must push the FABs up manually.
        floatingActionButton: Padding(
          padding: EdgeInsets.only(
            bottom: 74 + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _glowFab(
                heroTag: 'walk_in',
                icon: Icons.person_add_alt,
                label: 'Walk-in',
                colors: const [_surfaceLow, _surfaceLow],
                borderColor: _greenFixed,
                iconTextColor: _greenFixed,
                onPressed: () => Get.toNamed(AppRoutes.manualBooking),
              ),
              const SizedBox(height: 12),
              _glowFab(
                heroTag: 'scan_qr',
                icon: Icons.qr_code_scanner,
                label: 'Scan QR',
                colors: const [Color(0xFF00DBE9), Color(0xFF2979FF)],
                iconTextColor: const Color(0xFF0B0E14),
                glow: _cyan,
                onPressed: () => Get.toNamed(AppRoutes.ownerQrScanner),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glowFab({
    required String heroTag,
    required IconData icon,
    required String label,
    required List<Color> colors,
    required Color iconTextColor,
    Color? borderColor,
    Color? glow,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(28),
            border: borderColor != null
                ? Border.all(color: borderColor.withValues(alpha: 0.6))
                : null,
            boxShadow: glow != null
                ? [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconTextColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: iconTextColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
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
    case BookingStatus.refundPending:
    case BookingStatus.refundSent:
      return _amber;
    case BookingStatus.pendingDeposit:
    case BookingStatus.depositSubmitted:
      return _cyan;
  }
}

// Resolves the real customer name for bookings whose `customerName` field
// is empty (e.g. legacy bookings created before that field was populated
// at booking time), falling back to their live profile — and finally to
// 'Customer' only if no profile exists.
final Map<String, String> _customerNameCache = {};

Future<String> _resolveCustomerName(BookingModel b) async {
  if (b.customerName.isNotEmpty) return b.customerName;
  final cached = _customerNameCache[b.customerId];
  if (cached != null) return cached;
  try {
    final user = await AuthService().fetchUser(b.customerId);
    final name = (user?.name.isNotEmpty ?? false) ? user!.name : 'Customer';
    _customerNameCache[b.customerId] = name;
    return name;
  } catch (_) {
    // Firestore rules may deny reading another user's profile; fall back
    // gracefully instead of crashing. Not cached so a later retry can win.
    return 'Customer';
  }
}

class _CustomerNameText extends StatelessWidget {
  final BookingModel booking;
  final TextStyle style;

  const _CustomerNameText({required this.booking, required this.style});

  @override
  Widget build(BuildContext context) {
    if (booking.customerName.isNotEmpty) {
      return Text(booking.customerName,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    return FutureBuilder<String>(
      future: _resolveCustomerName(booking),
      builder: (context, snap) => Text(snap.data ?? 'Customer',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    );
  }
}

Future<void> _openChat(BookingModel b) async {
  if (!Get.isRegistered<ChatController>()) {
    Get.put(ChatController(), permanent: true);
  }
  final chatId = await ChatController.to.openBookingChat(b);
  Get.toNamed(AppRoutes.chatRoom, arguments: chatId);
}

Widget _emptyState(IconData icon, String title, String subtitle) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cyan.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 52, color: _cyan),
        ),
        const SizedBox(height: 20),
        Text(title,
            style: const TextStyle(
                color: _onSurface, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(color: _onSurfaceVar, fontSize: 13)),
      ],
    ),
  );
}

Widget _infoChip(IconData icon, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _outline),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _cyan),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: _onSurface, fontSize: 12)),
      ],
    ),
  );
}

Widget _chatButton(BookingModel b, {double size = 18}) {
  return GestureDetector(
    onTap: () => _openChat(b),
    child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: _cyan,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _cyan.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(Icons.chat_bubble_outline,
          size: size, color: const Color(0xFF0B0E14)),
    ),
  );
}

/// Shared card shell: dark glass panel + colored status pill header.
Widget _bookingCardShell(
  BuildContext context,
  BookingModel b, {
  required Widget body,
  VoidCallback? onTap,
}) {
  final sColor = _statusColor(b.status);
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: _surfaceLow,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _outline),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _outline),
                    ),
                    child: const Icon(Icons.person_outline,
                        size: 20, color: _cyan),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: _CustomerNameText(
                                booking: b,
                                style: const TextStyle(
                                  color: _onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (b.bookedByRole != 'customer') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('WALK-IN',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: _amber,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                        Text('${b.arenaName} · ${b.courtName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _onSurfaceVar, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  if (b.checkedIn)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: _greenFixed.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.login,
                          size: 14, color: _greenFixed),
                    ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      b.status.label.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          color: sColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _infoChip(Icons.calendar_today_outlined, _fmtDate(b.date)),
                  const SizedBox(width: 8),
                  _infoChip(Icons.schedule_outlined,
                      '${b.timeRange} · ${b.totalHours}h'),
                ],
              ),
              const SizedBox(height: 14),
              body,
            ],
          ),
        ),
      ),
    ),
  );
}

void _showScreenshotDialog(BuildContext context, BookingModel b) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: _surfaceLow,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Deposit Screenshot',
                style: TextStyle(
                    color: _onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            b.depositScreenshot != null &&
                    b.depositScreenshot!.startsWith('http')
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      b.depositScreenshot!,
                      height: 320,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, e, s) => const SizedBox(
                        height: 120,
                        child: Center(
                            child: Icon(Icons.broken_image,
                                color: _onSurfaceVar)),
                      ),
                    ),
                  )
                : Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _outline),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long,
                            size: 56, color: _onSurfaceVar),
                        const SizedBox(height: 12),
                        const Text('No screenshot uploaded',
                            style: TextStyle(color: _onSurfaceVar)),
                        Text('PKR ${b.depositAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: _onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                      ],
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

// ── Pending tab ───────────────────────────────────────────────────────

class _PendingList extends StatelessWidget {
  final OwnerBookingController controller;

  const _PendingList({required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = controller.pendingApproval;
    if (items.isEmpty) {
      return _emptyState(
          Icons.task_alt, 'All caught up', 'No deposits awaiting approval');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final b = items[i];
        return _bookingCardShell(
          context,
          b,
          onTap: () =>
              Get.toNamed(AppRoutes.bookingDetailOwner, arguments: b.id),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Deposit PKR ${b.depositAmount.toStringAsFixed(0)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _cyan, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showScreenshotDialog(context, b),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.image_outlined,
                        size: 18, color: _cyan),
                    label: const Text('Screenshot',
                        style: TextStyle(color: _cyan, fontSize: 13)),
                  ),
                  const SizedBox(width: 6),
                  _chatButton(b),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _confirmReject(context, b),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _red,
                        side: BorderSide(color: _red.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Reject',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _greenFixed.withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: () async {
                          controller.approve(b.id);
                          final name = await _resolveCustomerName(b);
                          Get.snackbar('Booking confirmed',
                              '$name will be notified.',
                              snackPosition: SnackPosition.BOTTOM,
                              margin: const EdgeInsets.all(16));
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _greenFixed,
                          foregroundColor: const Color(0xFF0B0E14),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Approve',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmReject(BuildContext context, BookingModel b) async {
    final name = await _resolveCustomerName(b);
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
      onConfirm: () {
        controller.reject(b.id);
        Get.back();
      },
    );
  }
}

// ── All tab ───────────────────────────────────────────────────────────

class _AllList extends StatelessWidget {
  final OwnerBookingController controller;

  const _AllList({required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = controller.all;
    if (items.isEmpty) {
      return _emptyState(Icons.event_note_outlined, 'No bookings yet',
          'Bookings across your arenas appear here');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final b = items[i];
        return _bookingCardShell(
          context,
          b,
          onTap: () =>
              Get.toNamed(AppRoutes.bookingDetailOwner, arguments: b.id),
          body: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PKR ${b.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: _cyan, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              _chatButton(b),
            ],
          ),
        );
      },
    );
  }
}

// ── Refunds tab ───────────────────────────────────────────────────────

class _RefundList extends StatelessWidget {
  final OwnerBookingController controller;

  const _RefundList({required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = controller.refunds;
    if (items.isEmpty) {
      return _emptyState(Icons.currency_exchange, 'No refunds due',
          'Cancelled bookings needing refunds appear here');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final b = items[i];
        final cx = b.cancellation;
        final sent = b.status == BookingStatus.refundSent;
        return _bookingCardShell(
          context,
          b,
          onTap: () =>
              Get.toNamed(AppRoutes.bookingDetailOwner, arguments: b.id),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cx != null) ...[
                Row(
                  children: [
                    const Icon(Icons.account_balance_outlined,
                        size: 16, color: _onSurfaceVar),
                    const SizedBox(width: 8),
                    Text('${cx.bankName} · ${cx.accountNumber}',
                        style: const TextStyle(color: _onSurface, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Refund PKR ${(cx?.refundAmount ?? 0).toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: _amber, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Row(
                    children: [
                      if (!sent)
                        FilledButton.icon(
                          onPressed: () async {
                            controller.sendRefund(b.id);
                            final name = await _resolveCustomerName(b);
                            Get.snackbar('Refund marked sent',
                                '$name will confirm receipt.',
                                snackPosition: SnackPosition.BOTTOM,
                                margin: const EdgeInsets.all(16));
                          },
                          icon: const Icon(Icons.upload_outlined, size: 18),
                          label: const Text('Upload & Send'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _cyan,
                            foregroundColor: const Color(0xFF0B0E14),
                          ),
                        )
                      else
                        const Text('Awaiting confirmation',
                            style: TextStyle(color: _onSurfaceVar, fontSize: 12)),
                      const SizedBox(width: 8),
                      _chatButton(b),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
