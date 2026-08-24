import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/owner_booking_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/court_model.dart';
import '../../../data/models/extension_request_model.dart';
import '../../../data/models/pos_product_model.dart';
import '../../../data/models/pos_transaction_model.dart';
import '../../../routes/app_routes.dart';
import 'pos_collect_sheet.dart';
import '../../../services/extension_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

final _pkr = NumberFormat('#,##0');

class LiveCourtScreen extends StatelessWidget {
  const LiveCourtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PosController>()) {
      Get.put(PosController(), permanent: true);
    }
    final pos = PosController.to;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Court Command Center'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _ClockWidget(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('New Walk-in'),
        onPressed: () => Get.toNamed(AppRoutes.posWalkIn),
      ),
      body: Obx(() {
        final arena = pos.selectedArena.value;
        if (arena == null) {
          return const Center(
            child: Text('No arena selected', style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        final courts = arena.courts.where((c) => c.isActive).toList();
        if (courts.isEmpty) {
          return const Center(
            child: Text('No active courts', style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return Column(
              children: [
                _LegendRow(),
                Expanded(
                  child: isWide
                      ? _DesktopCourtGrid(courts: courts, pos: pos)
                      : _MobileCourtList(courts: courts, pos: pos),
                ),
              ],
            );
          },
        );
      }),
    );
  }
}

// Ticks every minute so the app-bar clock stays accurate
class _ClockWidget extends StatefulWidget {
  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        DateFormat('HH:mm').format(_now),
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _legend(AppColors.success, 'Available'),
          const SizedBox(width: 16),
          _legend(AppColors.warning, 'Upcoming'),
          const SizedBox(width: 16),
          _legend(AppColors.accent, 'Occupied'),
          const SizedBox(width: 16),
          _legend(AppColors.textDisabled, 'Maintenance'),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11)),
        ],
      );
}

class _MobileCourtList extends StatelessWidget {
  final List<CourtModel> courts;
  final PosController pos;
  const _MobileCourtList({required this.courts, required this.pos});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: courts.length,
      itemBuilder: (_, i) => _CourtCard(court: courts[i], pos: pos),
    );
  }
}

class _DesktopCourtGrid extends StatelessWidget {
  final List<CourtModel> courts;
  final PosController pos;
  const _DesktopCourtGrid({required this.courts, required this.pos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        childAspectRatio: 1.1,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: courts.length,
      itemBuilder: (_, i) => _CourtCard(court: courts[i], pos: pos),
    );
  }
}

// ── Court Card ────────────────────────────────────────────────────────────

class _CourtCard extends StatelessWidget {
  final CourtModel court;
  final PosController pos;
  const _CourtCard({required this.court, required this.pos});

  @override
  Widget build(BuildContext context) {
    final status = pos.courtStatus(court.id);
    final current = pos.currentBookingForCourt(court.id);
    final upcomingBookings = pos.todayBookingsForCourt(court.id);

    // A confirmed booking within 2h window (check-in eligible)
    final now = DateTime.now();
    final checkInEligible = upcomingBookings.firstWhereOrNull((b) =>
        b.status == BookingStatus.confirmed &&
        !b.checkedIn &&
        !b.date.isBefore(DateTime(now.year, now.month, now.day)) &&
        b.startDateTime.difference(now).inHours <= 2 &&
        now.isBefore(b.endDateTime));

    Color statusColor;
    switch (status) {
      case CourtLiveStatus.available:
        statusColor = AppColors.success;
      case CourtLiveStatus.upcoming:
        statusColor = AppColors.warning;
      case CourtLiveStatus.occupied:
        statusColor = AppColors.accent;
      case CourtLiveStatus.maintenance:
        statusColor = AppColors.textDisabled;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Court header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.sports_outlined, color: statusColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(court.name, style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                      Text(court.type.label, style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.label,
                    style: AppTextStyles.caption.copyWith(
                      color: statusColor, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Live session timer (ongoing only)
          if (current != null && current.checkedIn && current.checkedInAt != null)
            _SessionTimer(booking: current),

          // Current / upcoming info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (current != null && !(current.checkedIn)) ...[
                  _BookingInfo(booking: current, label: 'Current'),
                  const SizedBox(height: 8),
                ],
                Builder(builder: (_) {
                  final next = upcomingBookings.where((b) =>
                    b.startHour > now.hour &&
                    b.id != (current?.id ?? '')).firstOrNull;
                  if (next == null) return const SizedBox.shrink();
                  return _BookingInfo(booking: next, label: 'Next');
                }),
                if (current == null && upcomingBookings.isEmpty)
                  Text('Open all day', style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.success, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _ActionChip(
                  label: 'Walk-in',
                  icon: Icons.add,
                  color: AppColors.primary,
                  onTap: () => Get.toNamed(AppRoutes.posWalkIn,
                      arguments: {'courtId': court.id, 'courtName': court.name}),
                ),
                // Check In — shown when a confirmed booking is within the 2h window
                if (checkInEligible != null)
                  _ActionChip(
                    label: 'Check In',
                    icon: Icons.login,
                    color: AppColors.success,
                    onTap: () => _checkIn(checkInEligible),
                  ),
                // Session — shown when court is occupied (ongoing + checked in)
                if (current != null && current.checkedIn)
                  _ActionChip(
                    label: 'Session',
                    icon: Icons.timer_outlined,
                    color: AppColors.accent,
                    onTap: () => _showSessionSheet(context, current, court),
                  ),
                // Add Items — food/drinks/equipment during live session
                if (current != null && current.checkedIn)
                  _ActionChip(
                    label: 'Add Items',
                    icon: Icons.add_shopping_cart_outlined,
                    color: AppColors.secondary,
                    onTap: () => _showAddItemsSheet(context, current),
                  ),
                // Collect Balance — shown when there's an outstanding amount
                if (current != null && current.remainingAmount > 0)
                  _ActionChip(
                    label: 'Collect',
                    icon: Icons.payments_outlined,
                    color: AppColors.warning,
                    onTap: () => _showCollectSheet(context, current),
                  ),
                if (current != null && !current.checkedIn)
                  _ActionChip(
                    label: 'View',
                    icon: Icons.open_in_new,
                    color: AppColors.secondary,
                    onTap: () => Get.toNamed(
                      AppRoutes.bookingDetailOwner,
                      arguments: current,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkIn(BookingModel booking) async {
    final error = await OwnerBookingController.to.checkIn(booking.id);
    if (error != null) {
      Get.snackbar('Check-in Failed', error,
          backgroundColor: AppColors.error, colorText: Colors.white);
    } else {
      Get.snackbar('Checked In', '${booking.customerName.isNotEmpty ? booking.customerName : 'Walk-in'} — ${booking.timeRange}',
          backgroundColor: AppColors.success, colorText: Colors.white);
    }
  }

  void _showSessionSheet(BuildContext context, BookingModel booking, CourtModel court) {
    Get.bottomSheet(
      isScrollControlled: true,
      _SessionSheet(booking: booking, court: court),
    );
  }

  void _showCollectSheet(BuildContext context, BookingModel booking) {
    Get.bottomSheet(
      isScrollControlled: true,
      PosCollectBalanceSheet(booking: booking),
    );
  }

  void _showAddItemsSheet(BuildContext context, BookingModel booking) {
    Get.bottomSheet(
      isScrollControlled: true,
      _AddItemsSheet(booking: booking),
    );
  }
}

// ── Live Session Timer ────────────────────────────────────────────────────

class _SessionTimer extends StatefulWidget {
  final BookingModel booking;
  const _SessionTimer({required this.booking});

  @override
  State<_SessionTimer> createState() => _SessionTimerState();
}

class _SessionTimerState extends State<_SessionTimer> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_update);
    });
  }

  void _update() {
    final start = widget.booking.checkedInAt!;
    _elapsed = DateTime.now().difference(start);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalBooked = Duration(hours: widget.booking.totalHours);
    final remaining = totalBooked - _elapsed;
    final isOvertime = remaining.isNegative;
    final timerColor = isOvertime ? AppColors.error : AppColors.accent;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: timerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: timerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: timerColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.booking.customerName.isNotEmpty
                      ? widget.booking.customerName
                      : 'Walk-in',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary, fontSize: 11),
                ),
                Text(
                  isOvertime ? 'Overtime +${_fmt(-remaining)}' : 'Remaining ${_fmt(remaining)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: timerColor, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _fmt(_elapsed),
            style: AppTextStyles.titleMedium.copyWith(
              color: timerColor, fontWeight: FontWeight.w800, fontSize: 18,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Booking Info Row ──────────────────────────────────────────────────────

class _BookingInfo extends StatelessWidget {
  final BookingModel booking;
  final String label;
  const _BookingInfo({required this.booking, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.timeRange,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
                ),
                Text(
                  booking.customerName.isNotEmpty ? booking.customerName : 'Walk-in',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            'PKR ${_pkr.format(booking.totalAmount)}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label, style: AppTextStyles.caption.copyWith(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ── Session Bottom Sheet ──────────────────────────────────────────────────

class _SessionSheet extends StatefulWidget {
  final BookingModel booking;
  final CourtModel court;
  const _SessionSheet({required this.booking, required this.court});

  @override
  State<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends State<_SessionSheet> {
  bool _submitting = false;
  // Checkout state
  PosPaymentMethod _payMethod = PosPaymentMethod.cash;
  // We always track the live booking from the stream
  BookingModel get _booking {
    final live = OwnerBookingController.to.bookings
        .firstWhereOrNull((b) => b.id == widget.booking.id);
    return live ?? widget.booking;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final b = _booking;
      final remaining = b.remainingAmount;
      final needsPayment = remaining > 0;
      return _buildSheet(context, b, remaining, needsPayment);
    });
  }

  Widget _buildSheet(BuildContext context, BookingModel b, double remaining, bool needsPayment) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active Session', style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700)),
                      Text('${widget.court.name} · ${b.timeRange}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                _SessionTimerCompact(checkedInAt: b.checkedInAt!),
              ],
            ),
            const SizedBox(height: 20),

            // Payment summary
            _SummaryRow('Total Amount', 'PKR ${_pkr.format(b.totalAmount)}'),
            const SizedBox(height: 6),
            _SummaryRow('Already Paid', 'PKR ${_pkr.format(b.amountPaid ?? 0)}'),
            const SizedBox(height: 6),
            _SummaryRow(
              'Remaining',
              'PKR ${_pkr.format(remaining)}',
              highlight: remaining > 0,
            ),
            const Divider(height: 24, color: AppColors.border),

            // Extend session (whole hours)
            _ExtendSection(booking: b),
            const Divider(height: 24, color: AppColors.border),

            // Pending minute-extension requests from the customer
            _PendingExtensionPanel(booking: b),
            const Divider(height: 24, color: AppColors.border),

            // Add items (food, beverages, equipment) to this session
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Items',
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      Text('Food, beverages, equipment rental',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Get.back();
                    Get.bottomSheet(
                      isScrollControlled: true,
                      _AddItemsSheet(booking: b),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_shopping_cart_outlined,
                            size: 14, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        Text('Add Items',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: AppColors.border),

            // Checkout section
            Text('Checkout', style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),

            if (needsPayment) ...[
              Text('Collect remaining payment',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PosPaymentMethod.cash,
                  PosPaymentMethod.card,
                  PosPaymentMethod.jazzcash,
                  PosPaymentMethod.easypaisa,
                  PosPaymentMethod.bankTransfer,
                ].map((m) {
                  final sel = _payMethod == m;
                  return GestureDetector(
                    onTap: () => setState(() => _payMethod = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.elevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(m.label, style: AppTextStyles.caption.copyWith(
                        color: sel ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : () => _checkout(remaining),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Collect PKR ${_pkr.format(remaining)} & Complete'),
              ),
            ] else ...[
              FilledButton(
                onPressed: _submitting ? null : () => _checkout(0),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Complete Session'),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _checkout(double amountToCollect) async {
    setState(() => _submitting = true);
    try {
      final b = _booking;
      // Collect remaining balance through the unified ledger (source: pos)
      if (amountToCollect > 0) {
        await PosController.to.collectBalance(
          booking: b,
          amount: amountToCollect,
          method: _payMethod,
        );
      }
      // Mark booking as completed
      final newRemaining = (b.remainingAmount - amountToCollect).clamp(0.0, double.infinity);
      await OwnerBookingController.to.checkoutSession(b.id, amountToCollect, newRemaining);
      Get.back();
      Get.snackbar('Session Complete', 'Booking closed successfully',
          backgroundColor: AppColors.success, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _SummaryRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label, style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: AppTextStyles.bodyMedium.copyWith(
            color: highlight ? AppColors.error : AppColors.textPrimary,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
          )),
        ],
      );
}

// Compact timer shown inside the session sheet header
class _SessionTimerCompact extends StatefulWidget {
  final DateTime checkedInAt;
  const _SessionTimerCompact({required this.checkedInAt});

  @override
  State<_SessionTimerCompact> createState() => _SessionTimerCompactState();
}

class _SessionTimerCompactState extends State<_SessionTimerCompact> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.checkedInAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(widget.checkedInAt));
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes % 60;
    final s = _elapsed.inSeconds % 60;
    final label = h > 0
        ? '${h}h ${m.toString().padLeft(2, '0')}m'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.accent,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      )),
    );
  }
}

// ── Extend Session Section ────────────────────────────────────────────────

class _ExtendSection extends StatefulWidget {
  final BookingModel booking;
  const _ExtendSection({required this.booking});

  @override
  State<_ExtendSection> createState() => _ExtendSectionState();
}

class _ExtendSectionState extends State<_ExtendSection> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Extend Session', style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: [
            _ExtendButton(
              label: '+1 hour',
              extraHours: 1,
              price: widget.booking.pricePerHour,
              booking: widget.booking,
              submitting: _submitting,
              onStart: () => setState(() => _submitting = true),
              onEnd: () { if (mounted) setState(() => _submitting = false); },
            ),
            const SizedBox(width: 8),
            _ExtendButton(
              label: '+2 hours',
              extraHours: 2,
              price: widget.booking.pricePerHour * 2,
              booking: widget.booking,
              submitting: _submitting,
              onStart: () => setState(() => _submitting = true),
              onEnd: () { if (mounted) setState(() => _submitting = false); },
            ),
            const SizedBox(width: 8),
            _ExtendButton(
              label: '+3 hours',
              extraHours: 3,
              price: widget.booking.pricePerHour * 3,
              booking: widget.booking,
              submitting: _submitting,
              onStart: () => setState(() => _submitting = true),
              onEnd: () { if (mounted) setState(() => _submitting = false); },
            ),
          ],
        ),
      ],
    );
  }
}

class _ExtendButton extends StatelessWidget {
  final String label;
  final int extraHours;
  final double price;
  final BookingModel booking;
  final bool submitting;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  const _ExtendButton({
    required this.label,
    required this.extraHours,
    required this.price,
    required this.booking,
    required this.submitting,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: submitting ? null : _extend,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(label, style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              Text('PKR ${NumberFormat('#,##0').format(price)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _extend() async {
    onStart();
    try {
      final error = await OwnerBookingController.to.extendSession(booking, extraHours);
      if (error != null) {
        Get.snackbar('Cannot Extend', error,
            backgroundColor: AppColors.error, colorText: Colors.white);
      } else {
        Get.snackbar('Extended', '$label added to session',
            backgroundColor: AppColors.success, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      onEnd();
    }
  }
}

// ── Owner: Pending extension requests panel ───────────────────────────────

class _PendingExtensionPanel extends StatefulWidget {
  final BookingModel booking;
  const _PendingExtensionPanel({required this.booking});

  @override
  State<_PendingExtensionPanel> createState() => _PendingExtensionPanelState();
}

class _PendingExtensionPanelState extends State<_PendingExtensionPanel> {
  final _svc = ExtensionService();
  final _acting = <String, bool>{};

  Future<void> _approve(ExtensionRequestModel req) async {
    setState(() => _acting[req.id] = true);
    try {
      await _svc.approveRequest(req);
      Get.snackbar(
        'Extension Approved',
        '+${req.extensionMinutes} min added to session',
        backgroundColor: AppColors.success,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Cannot Extend', e.toString(),
          backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _acting.remove(req.id));
    }
  }

  Future<void> _reject(ExtensionRequestModel req) async {
    setState(() => _acting[req.id] = true);
    try {
      await _svc.rejectRequest(req.id);
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _acting.remove(req.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExtensionRequestModel>>(
      stream: _svc.bookingRequestsStream(widget.booking.id),
      builder: (context, snap) {
        final pending = (snap.data ?? [])
            .where((r) => r.status == ExtensionRequestStatus.pending)
            .toList();

        if (pending.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Extension Requests',
                  style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('No pending requests from customer.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Extension Requests',
                    style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${pending.length}',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.warning, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...pending.map((req) => _ExtensionRequestTile(
                  req: req,
                  acting: _acting[req.id] ?? false,
                  onApprove: () => _approve(req),
                  onReject: () => _reject(req),
                )),
          ],
        );
      },
    );
  }
}

class _ExtensionRequestTile extends StatelessWidget {
  final ExtensionRequestModel req;
  final bool acting;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ExtensionRequestTile({
    required this.req,
    required this.acting,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+${req.extensionMinutes} min requested',
                  style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                Text(
                  req.customerName.isNotEmpty ? req.customerName : 'Walk-in',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (acting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onReject,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text('Reject',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onApprove,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Text('Approve',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Add Items Sheet ───────────────────────────────────────────────────────

class _AddItemsSheet extends StatefulWidget {
  final BookingModel booking;
  const _AddItemsSheet({required this.booking});

  @override
  State<_AddItemsSheet> createState() => _AddItemsSheetState();
}

class _AddItemsSheetState extends State<_AddItemsSheet> {
  final Map<String, int> _qty = {}; // productId → quantity
  bool _submitting = false;

  BookingModel get _booking {
    final live = OwnerBookingController.to.bookings
        .firstWhereOrNull((b) => b.id == widget.booking.id);
    return live ?? widget.booking;
  }

  List<PosProductModel> get _products =>
      PosController.to.products.where((p) => p.isActive).toList();

  double get _total => _products.fold(0.0, (sum, p) {
        final q = _qty[p.id] ?? 0;
        return sum + p.price * q;
      });

  bool get _hasItems => _qty.values.any((q) => q > 0);

  Future<void> _confirm() async {
    if (!_hasItems) return;
    setState(() => _submitting = true);
    try {
      final items = _products
          .where((p) => (_qty[p.id] ?? 0) > 0)
          .map((p) => {
                'name': p.name,
                'qty': _qty[p.id]!,
                'unitPrice': p.price,
              })
          .toList();

      await PosController.to.addSessionItems(
        booking: _booking,
        items: items,
        total: _total,
      );

      Get.back();
      Get.snackbar(
        'Items Added',
        'PKR ${_pkr.format(_total)} added to session bill',
        backgroundColor: AppColors.success,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final products = _products;
      final categories = products.map((p) => p.category).toSet().toList();

      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Items to Session',
                          style: AppTextStyles.titleMedium
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        '${_booking.customerName.isNotEmpty ? _booking.customerName : 'Walk-in'} · ${_booking.courtName}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (products.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No products set up yet.\nGo to POS → Products to add items.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45),
                child: ListView(
                  shrinkWrap: true,
                  children: categories.expand((cat) {
                    final catProducts =
                        products.where((p) => p.category == cat).toList();
                    return [
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 6),
                        child: Text(cat.label.toUpperCase(),
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textDisabled,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                      ),
                      ...catProducts.map((p) => _ProductRow(
                            product: p,
                            qty: _qty[p.id] ?? 0,
                            onIncrement: () =>
                                setState(() => _qty[p.id] = (_qty[p.id] ?? 0) + 1),
                            onDecrement: () {
                              final current = _qty[p.id] ?? 0;
                              if (current > 0) {
                                setState(() => _qty[p.id] = current - 1);
                              }
                            },
                          )),
                    ];
                  }).toList(),
                ),
              ),

            if (_hasItems) ...[
              const Divider(height: 20, color: AppColors.border),
              Row(
                children: [
                  Text('Total to add',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                  const Spacer(),
                  Text('PKR ${_pkr.format(_total)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Added to session bill — collect at checkout',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],

            const SizedBox(height: 14),
            FilledButton(
              onPressed: (_submitting || !_hasItems) ? null : _confirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: AppColors.border,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_hasItems
                      ? 'Add PKR ${_pkr.format(_total)} to Bill'
                      : 'Select items above'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    });
  }
}

class _ProductRow extends StatelessWidget {
  final PosProductModel product;
  final int qty;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _ProductRow({
    required this.product,
    required this.qty,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                Text('PKR ${_pkr.format(product.price)}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: onDecrement,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: qty > 0
                        ? AppColors.secondary.withValues(alpha: 0.12)
                        : AppColors.elevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: qty > 0
                            ? AppColors.secondary.withValues(alpha: 0.4)
                            : AppColors.border),
                  ),
                  child: Icon(Icons.remove,
                      size: 14,
                      color: qty > 0
                          ? AppColors.secondary
                          : AppColors.textDisabled),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$qty',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700),
                ),
              ),
              GestureDetector(
                onTap: onIncrement,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.4)),
                  ),
                  child: Icon(Icons.add,
                      size: 14, color: AppColors.secondary),
                ),
              ),
            ],
          ),
          if (qty > 0) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              child: Text(
                'PKR ${_pkr.format(product.price * qty)}',
                textAlign: TextAlign.end,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ] else
            const SizedBox(width: 74),
        ],
      ),
    );
  }
}
