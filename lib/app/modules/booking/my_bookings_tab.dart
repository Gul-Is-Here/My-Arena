import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/booking_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/court_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'rate_booking_sheet.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
const _bg = AppColors.background;
const _surface = AppColors.surface;
const _surfaceLow = AppColors.elevated;
const _outline = AppColors.border;
const _cyan = AppColors.secondary;
const _cyanDim = AppColors.secondary;
const _green = AppColors.success;
const _greenFixed = AppColors.success;
const _onSurface = AppColors.textPrimary;
const _onSurfaceVar = AppColors.textSecondary;
const _amber = AppColors.warning; // "pending" accent
const _red = AppColors.error;

class MyBookingsTab extends StatefulWidget {
  const MyBookingsTab({super.key});

  @override
  State<MyBookingsTab> createState() => _MyBookingsTabState();
}

class _MyBookingsTabState extends State<MyBookingsTab> {
  int _tabIndex = 0; // 0 Pending · 1 Confirmed · 2 Active · 3 Completed · 4 Cancelled

  static const _tabs = [
    'Pending',
    'Confirmed',
    'Active',
    'Completed',
    'Cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    final c = Get.find<BookingController>();

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Ambient glow blobs
          Positioned(
            top: -80, left: -80,
            child: _glowBlob(_cyan),
          ),
          Positioned(
            bottom: -80, right: -80,
            child: _glowBlob(_green),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildTabRow(),
                Expanded(
                  child: Obx(() {
                    c.bookings.length; // reactive trigger
                    final items = _itemsForTab(c);
                    if (items.isEmpty) return _buildEmpty();
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _BookingCard(booking: items[i]),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MY BOOKINGS',
              style: AppTextStyles.headlineLarge.copyWith(
                fontSize: 24,
                color: _cyanDim,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Manage your field reservations & track statuses.',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 13,
                color: _onSurfaceVar,
              ),
            ),
          ],
        ),
      );

  Widget _buildTabRow() => SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          itemCount: _tabs.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final active = i == _tabIndex;
            return GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : _surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: active ? AppColors.primary : _outline.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _tabs[i],
                  style: AppTextStyles.label.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: active ? AppColors.primary : _onSurfaceVar,
                  ),
                ),
              ),
            );
          },
        ),
      );

  List<BookingModel> _itemsForTab(BookingController c) {
    switch (_tabIndex) {
      case 0:
        return c.bookings
            .where((b) =>
                b.status == BookingStatus.pendingDeposit ||
                b.status == BookingStatus.depositSubmitted)
            .toList()
          ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      case 1:
        return c.bookings
            .where((b) => b.status == BookingStatus.confirmed && !b.checkedIn)
            .toList()
          ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      case 2:
        return c.bookings
            .where((b) => b.isActive)
            .toList()
          ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      case 3:
        return c.bookings
            .where((b) => b.status == BookingStatus.completed)
            .toList()
          ..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
      case 4:
        return c.cancelled;
      default:
        return [];
    }
  }

  Widget _buildEmpty() {
    const labels = [
      ('No pending bookings', 'Bookings awaiting deposit payment appear here'),
      ('No confirmed bookings', 'Confirmed reservations appear here'),
      ('No active sessions', 'Sessions in progress appear here'),
      ('No completed sessions', 'Completed sessions appear here'),
      ('No cancellations', 'Cancelled bookings appear here'),
    ];
    final record = labels[_tabIndex];
    final title = record.$1;
    final sub = record.$2;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _cyan.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _cyan.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.event_busy_outlined,
                size: 48, color: _cyanDim),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: AppTextStyles.titleMedium.copyWith(
                  fontSize: 16, color: _onSurface)),
          const SizedBox(height: 6),
          Text(sub,
              style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 13, color: _onSurfaceVar)),
        ],
      ),
    );
  }
}

// ── Ambient glow blob ──────────────────────────────────────────────────────
// Radial gradient replaces BackdropFilter(sigma=60) — same visual, zero GPU cost.
Widget _glowBlob(Color color) => IgnorePointer(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );

// ── Booking card ───────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _fmtDate {
    final d = booking.date;
    return '${d.day} ${_months[d.month - 1]}, ${_fmtHour(booking.startHour)}';
  }

  static String _fmtHour(int h) {
    final hh = h % 24;
    final suffix = hh >= 12 ? 'PM' : 'AM';
    final display = hh % 12 == 0 ? 12 : hh % 12;
    return '$display:00 $suffix';
  }

  // Status → accent color
  Color get _accent {
    if (booking.isActive) return AppColors.primary;
    switch (booking.status) {
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
      case BookingStatus.rescheduleRequested:
        return _amber;
    }
  }

  bool get _isPulse =>
      booking.status == BookingStatus.pendingDeposit ||
      booking.status == BookingStatus.depositSubmitted;

  @override
  Widget build(BuildContext context) {
    final accent = _accent;

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.bookingDetail, arguments: booking),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _surfaceLow.withValues(alpha: 0.85),
              _bg.withValues(alpha: 0.95),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: accent, width: 2),
                left: BorderSide(color: _outline.withValues(alpha: 0.3)),
                right: BorderSide(color: _outline.withValues(alpha: 0.3)),
                bottom: BorderSide(color: _outline.withValues(alpha: 0.3)),
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Row 1: icon + arena/court + status badge
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.3)),
                        ),
                        child: Icon(Icons.stadium_outlined,
                            color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.arenaName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontSize: 15,
                                color: _onSurface,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              booking.courtName,
                              style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  color: _onSurfaceVar,
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(
                          label: booking.displayLabel,
                          color: accent,
                          pulse: _isPulse),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Divider
                  Divider(color: _outline.withValues(alpha: 0.25), height: 1),
                  const SizedBox(height: 12),
                  // Recurring / group chips
                  if (booking.isRecurring || booking.isGroupBooking) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (booking.isRecurring)
                          _MiniChip(
                            icon: Icons.repeat,
                            label: booking.recurringWeek != null &&
                                    booking.recurringTotal != null
                                ? 'Recurring · Week ${booking.recurringWeek}/${booking.recurringTotal}'
                                : 'Recurring',
                            color: const Color(0xFF7C83FD),
                          ),
                        if (booking.isGroupBooking)
                          _MiniChip(
                            icon: Icons.group,
                            label: 'Group · ${booking.groupSize} players',
                            color: const Color(0xFF43C59E),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Row 2: date/time + amount
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date & Time',
                                style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    letterSpacing: 0.6,
                                    color: _onSurfaceVar)),
                            const SizedBox(height: 2),
                            Text(_fmtDate,
                                style: AppTextStyles.bodySmall.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _onSurface)),
                            Text(
                              '${booking.timeRange} · ${booking.totalHours}h',
                              style: AppTextStyles.caption.copyWith(
                                  fontSize: 11, color: _onSurfaceVar),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Total',
                              style: AppTextStyles.caption.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 0.6,
                                  color: _onSurfaceVar)),
                          const SizedBox(height: 2),
                          Text(
                            'PKR ${booking.totalAmount.toStringAsFixed(0)}',
                            style: AppTextStyles.scoreboard.copyWith(
                              fontSize: 20,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 3: actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Refund info / cancel / rate
                      if (booking.cancellation != null)
                        Text(
                          'Refund PKR ${booking.cancellation!.refundAmount.toStringAsFixed(0)}',
                          style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 12, color: _amber),
                        )
                      else if (booking.status == BookingStatus.completed &&
                          !booking.hasReview)
                        _ActionChip(
                          label: 'Rate',
                          color: _amber,
                          onTap: () => RateBookingSheet.show(booking),
                        )
                      else if (booking.canCancel)
                        _ActionChip(
                          label: 'Cancel',
                          color: _red,
                          onTap: () => Get.toNamed(
                              AppRoutes.bookingCancellation,
                              arguments: booking.id),
                        )
                      else
                        const SizedBox.shrink(),
                      Row(
                        children: [
                          // Book Again for completed bookings
                          if (booking.status == BookingStatus.completed) ...[
                            _IconBtn(
                              icon: Icons.event_repeat,
                              color: _cyan,
                              onTap: () => bookAgain(booking),
                            ),
                            const SizedBox(width: 8),
                          ],
                          // QR only for confirmed + not yet checked in + session not expired
                          if (booking.status == BookingStatus.confirmed &&
                              !booking.checkedIn &&
                              booking.endDateTime.isAfter(DateTime.now())) ...[
                            _IconBtn(
                              icon: Icons.qr_code_2,
                              color: _cyanDim,
                              onTap: () => Get.toNamed(AppRoutes.bookingDetail,
                                  arguments: booking),
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Details icon for all non-pending statuses
                          if (booking.status != BookingStatus.pendingDeposit &&
                              booking.status != BookingStatus.depositSubmitted &&
                              !(booking.status == BookingStatus.confirmed &&
                                  !booking.checkedIn &&
                                  booking.endDateTime.isAfter(DateTime.now()))) ...[
                            _IconBtn(
                              icon: Icons.info_outline,
                              color: _cyanDim,
                              onTap: () => Get.toNamed(AppRoutes.bookingDetail,
                                  arguments: booking),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ],
                  ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small info chip (recurring / group) ──────────────────────────────────
class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status badge with optional pulse dot ─────────────────────────────────
class _StatusBadge extends StatefulWidget {
  final String label;
  final Color color;
  final bool pulse;
  const _StatusBadge(
      {required this.label, required this.color, this.pulse = false});

  @override
  State<_StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<_StatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ac);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.pulse)
            ExcludeSemantics(
              child: RepaintBoundary(
                child: FadeTransition(
                  opacity: _anim,
                  child: Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                        color: widget.color, shape: BoxShape.circle),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration:
                  BoxDecoration(color: widget.color, shape: BoxShape.circle),
            ),
          Text(
            widget.label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small icon button ─────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  static const bool filled = false;
  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: filled
              ? color.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ── Small text action chip ────────────────────────────────────────────────
class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: AppTextStyles.label.copyWith(fontSize: 11, color: color)),
      ),
    );
  }
}

// ── Helpers (used by other screens) ──────────────────────────────────────

Future<void> bookAgain(BookingModel b) async {
  Get.dialog(
    const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    barrierDismissible: false,
  );
  try {
    final arenaDoc = await FirebaseFirestore.instance
        .collection('arenas')
        .doc(b.arenaId)
        .get();
    final courtDoc = await FirebaseFirestore.instance
        .collection('arenas')
        .doc(b.arenaId)
        .collection('courts')
        .doc(b.courtId)
        .get();
    Get.back();
    if (!arenaDoc.exists || !courtDoc.exists) {
      Get.snackbar('Unavailable', 'This arena or court is no longer available',
          backgroundColor: _surface, colorText: _onSurface, duration: const Duration(seconds: 3));
      return;
    }
    final arena = ArenaModel.fromMap({...arenaDoc.data()!, 'id': arenaDoc.id});
    final court = CourtModel.fromMap({...courtDoc.data()!, 'id': courtDoc.id});
    Get.find<BookingController>().startFlow(arena, court);
    Get.toNamed(AppRoutes.bookingSlot);
  } catch (e) {
    if (Get.isDialogOpen ?? false) Get.back();
    Get.snackbar('Error', 'Could not load arena details',
        backgroundColor: _surface, colorText: _onSurface);
  }
}

Future<void> openBookingChatAndGo(BookingModel b) async {
  if (!Get.isRegistered<ChatController>()) {
    Get.put(ChatController(), permanent: true);
  }
  final chatId = await ChatController.to.openBookingChat(b);
  Get.toNamed(AppRoutes.chatRoom, arguments: chatId);
}

Color statusColor(BookingStatus s) {
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
    default:
      return AppColors.primary;
  }
}

// Keep BookingCard public for any external reference
class BookingCard extends StatelessWidget {
  final BookingModel booking;
  const BookingCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context) => _BookingCard(booking: booking);
}
