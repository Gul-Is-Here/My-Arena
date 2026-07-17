import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/booking_controller.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/court_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/arena_image.dart';
import '../../widgets/slot_picker_widgets.dart';

class BookingSummaryScreen extends StatelessWidget {
  const BookingSummaryScreen({super.key});

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _fmtDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

  static Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed:
      case BookingStatus.completed:
        return SlotPickerColors.green;
      case BookingStatus.rejected:
      case BookingStatus.cancelled:
        return const Color(0xFFFF5252);
      default:
        return SlotPickerColors.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<BookingController>();
    final b = c.draft;

    if (b == null) {
      return Scaffold(
        backgroundColor: SlotPickerColors.bg,
        body: const Center(
          child: Text(
            'No booking in progress',
            style: TextStyle(color: SlotPickerColors.muted),
          ),
        ),
      );
    }

    final arena = c.arena.value;
    final court = c.court.value;
    final statusColor = _statusColor(b.status);

    return Scaffold(
      backgroundColor: SlotPickerColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              onCopy: () {
                final text =
                    '${b.arenaName} — ${b.courtName}\n${_fmtDate(b.date)}\n${b.timeRange} (${b.totalHours} hr${b.totalHours > 1 ? 's' : ''})\nTotal: PKR ${b.totalAmount.toStringAsFixed(0)}';
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking details copied')),
                );
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ArenaImage(
                      path: arena?.images.isNotEmpty == true
                          ? arena!.images.first
                          : null,
                      height: 170,
                      width: double.infinity,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        b.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    b.arenaName,
                    style: const TextStyle(
                      color: SlotPickerColors.onBg,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _iconLine(
                    Icons.sports_soccer,
                    court != null
                        ? '${court.type.label} · ${b.courtName}'
                        : b.courtName,
                  ),
                  if (arena != null && arena.location.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _iconLine(Icons.location_on_outlined, arena.location.address),
                  ],
                  const SizedBox(height: 20),
                  _InfoTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'DATE',
                    value: _fmtDate(b.date),
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.access_time_rounded,
                    label: 'TIME',
                    value: b.timeRange,
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.timer_outlined,
                    label: 'DURATION',
                    value:
                        '${b.totalHours} Hour${b.totalHours > 1 ? 's' : ''}',
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment Details',
                    style: TextStyle(
                      color: SlotPickerColors.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: SlotPickerColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      children: [
                        _amountRow('Price per hour',
                            'PKR ${b.pricePerHour.toStringAsFixed(0)}'),
                        const SizedBox(height: 10),
                        _amountRow(
                          'Subtotal (${b.totalHours} hr${b.totalHours > 1 ? 's' : ''})',
                          'PKR ${b.totalAmount.toStringAsFixed(0)}',
                        ),
                        Divider(
                          height: 24,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'DEPOSIT DUE NOW',
                              style: TextStyle(
                                color: SlotPickerColors.onBg,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: SlotPickerColors.green
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline,
                                      size: 11, color: SlotPickerColors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'SECURED',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: SlotPickerColors.green,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PKR ${b.depositAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: SlotPickerColors.green,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${BookingSettings.depositPercent}% of total',
                              style: const TextStyle(
                                color: SlotPickerColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'PKR ${b.remainingAmount.toStringAsFixed(0)} remaining, payable at the venue',
                            style: const TextStyle(
                              color: SlotPickerColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SlotPickerColors.pending.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: SlotPickerColors.pending.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            size: 18, color: SlotPickerColors.pending),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cancellation Policy',
                                style: TextStyle(
                                  color: SlotPickerColors.pending,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Booking is confirmed after the owner verifies your deposit. Free cancellation up to ${BookingSettings.minCancelHoursBefore} hour before start time (${BookingSettings.cancellationDeductPercent}% deposit deduction applies after that).',
                                style: const TextStyle(
                                  color: SlotPickerColors.muted,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _BottomBar(
              label:
                  'Pay Deposit — PKR ${b.depositAmount.toStringAsFixed(0)}',
              onPressed: () => Get.toNamed(AppRoutes.depositPayment),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: SlotPickerColors.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SlotPickerColors.muted,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _amountRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: SlotPickerColors.muted, fontSize: 13)),
        Text(
          value,
          style: const TextStyle(
            color: SlotPickerColors.onBg,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onCopy;
  const _Header({required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back, color: SlotPickerColors.onBg),
          ),
          const Expanded(
            child: Text(
              'Booking Summary',
              style: TextStyle(
                color: SlotPickerColors.green,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onCopy,
            tooltip: 'Copy details',
            icon: const Icon(Icons.share_outlined, color: SlotPickerColors.onBg),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SlotPickerColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: SlotPickerColors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: SlotPickerColors.green),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: SlotPickerColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: SlotPickerColors.onBg,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _BottomBar({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: SlotPickerColors.bg,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Material(
        color: SlotPickerColors.greenCta,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.payments_outlined,
                    size: 18, color: Color(0xFF0A1628)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF0A1628),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
