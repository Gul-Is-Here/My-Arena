import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/booking_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/court_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/arena_image.dart';
import '../../widgets/slot_picker_widgets.dart';

/// Calendar strip + duration picker + hourly slot grid. Args are set on
/// BookingController via startFlow() before navigating here.
class BookingSlotScreen extends StatelessWidget {
  const BookingSlotScreen({super.key});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdaysShort = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static String fmtDate(DateTime d) =>
      '${_weekdaysShort[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final c = Get.find<BookingController>();

    return Scaffold(
      backgroundColor: SlotPickerColors.bg,
      body: SafeArea(
        child: Obx(() {
          final court = c.court.value;
          final arena = c.arena.value;
          if (court == null || arena == null) {
            return const Center(
              child: Text(
                'No court selected',
                style: TextStyle(color: SlotPickerColors.onBg),
              ),
            );
          }

          return Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(Icons.arrow_back,
                          color: SlotPickerColors.onBg),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Time Slot',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: SlotPickerColors.onBg,
                            ),
                          ),
                          Text(
                            '${arena.name} · ${court.type.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: SlotPickerColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ArenaImage(
                        path:
                            arena.images.isNotEmpty ? arena.images.first : null,
                        width: 36,
                        height: 36,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Step indicator ──────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: BookingStepIndicator(
                  labels: ['DATE', 'SLOT', 'PAY'],
                  currentIndex: 1,
                ),
              ),
              const SizedBox(height: 20),

              // ── Court switcher ───────────────────────────────────────
              if (arena.courts.length > 1) ...[
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: arena.courts.map((ct) {
                      final sel = ct.id == court.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(ct.name),
                          selected: sel,
                          backgroundColor: SlotPickerColors.surface,
                          selectedColor: SlotPickerColors.green,
                          labelStyle: TextStyle(
                            color: sel
                                ? const Color(0xFF0A1628)
                                : SlotPickerColors.onBg,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide.none,
                          onSelected: (_) => c.selectCourt(ct),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Date strip ────────────────────────────────────────────
              SlotDateStrip(
                selected: c.date.value,
                days: court.advanceBookingDays,
                onSelect: c.selectDate,
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Duration ─────────────────────────────────────
                      const Text(
                        'SELECT DURATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: SlotPickerColors.muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DurationSelector(
                        options: const [1, 2, 3],
                        selected: c.selectedDuration.value,
                        onSelect: c.setDuration,
                      ),
                      const SizedBox(height: 20),

                      // ── Legend ───────────────────────────────────────
                      const SlotLegend(),
                      const SizedBox(height: 16),

                      // ── Slot grid ────────────────────────────────────
                      if (c.loadingSlots.value)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: SlotPickerColors.green,
                            ),
                          ),
                        )
                      else
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.9,
                          children: c.hoursFor(court).map((h) {
                            final status = c.slotStatus(h);
                            final sel = c.selectedHours.contains(h);
                            return GestureDetector(
                              onTap: status == SlotStatus.booked
                                  ? () => _onBookedSlotTap(context, c, arena, court, h)
                                  : null,
                              child: SlotTile(
                                hour: h,
                                pricePerHour: court.pricePerHour,
                                status: status,
                                isSelected: sel,
                                onTap: () => c.selectSlot(h),
                              ),
                            );
                          }).toList(),
                        ),

                      // ── Summary card ─────────────────────────────────
                      if (c.totalHours > 0) ...[
                        const SizedBox(height: 20),
                        _SummaryCard(arena: arena, court: court, c: c),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
      bottomNavigationBar: Obx(() {
        final n = c.totalHours;
        return SafeArea(
          top: false,
          child: Container(
            color: SlotPickerColors.bg,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        n == 0
                            ? 'No slots selected'
                            : '$n hr${n > 1 ? 's' : ''} Total',
                        style: const TextStyle(
                          fontSize: 12,
                          color: SlotPickerColors.muted,
                        ),
                      ),
                      Text(
                        n == 0 ? '—' : 'PKR ${c.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: SlotPickerColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: n == 0
                      ? null
                      : () {
                          c.buildDraft();
                          Get.toNamed(AppRoutes.bookingSummary);
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: n == 0
                          ? SlotPickerColors.surface
                          : SlotPickerColors.greenCta,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'CONFIRM & PAY',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: n == 0
                                ? SlotPickerColors.muted
                                : const Color(0xFF0A1628),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.credit_card,
                          size: 16,
                          color: n == 0
                              ? SlotPickerColors.muted
                              : const Color(0xFF0A1628),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Waitlist
// ─────────────────────────────────────────────────────────────────────────

Future<void> _onBookedSlotTap(
  BuildContext context,
  BookingController c,
  ArenaModel arena,
  CourtModel court,
  int hour,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1D2026),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Slot Taken',
        style: TextStyle(color: Color(0xFFE1E2EB), fontWeight: FontWeight.w800),
      ),
      content: Text(
        'Join the waitlist for ${fmtHour12(hour)}?\nWe\'ll notify you if it opens up.',
        style: const TextStyle(color: Color(0xFFB9CACB), fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFFB9CACB))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Join Waitlist',
              style: TextStyle(
                  color: Color(0xFF00DBE9), fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await c.joinWaitlist(
    arenaId: arena.id,
    arenaName: arena.name,
    courtId: court.id,
    date: c.date.value,
    hour: hour,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("You're on the waitlist! We'll notify you if the slot opens."),
        backgroundColor: Color(0xFF1D2026),
        duration: Duration(seconds: 3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Summary card
// ─────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final ArenaModel arena;
  final CourtModel court;
  final BookingController c;
  const _SummaryCard({
    required this.arena,
    required this.court,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = BookingSlotScreen.fmtDate(c.date.value);
    final startLabel = fmtHour12(c.startHour);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SlotPickerColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arena.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SlotPickerColors.onBg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${court.type.label} · ${court.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SlotPickerColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'TOTAL DUE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: SlotPickerColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PKR ${c.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: SlotPickerColors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFF1E3252)),
          ),
          Row(
            children: [
              Expanded(
                child: _summaryTile(
                  Icons.calendar_today_outlined,
                  'Date & Time',
                  '$dateStr · $startLabel',
                ),
              ),
              Expanded(
                child: _summaryTile(
                  Icons.schedule_outlined,
                  'Duration',
                  '${c.totalHours} Hour${c.totalHours > 1 ? 's' : ''}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: SlotPickerColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: SlotPickerColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SlotPickerColors.onBg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
