import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/owner_booking_controller.dart';
import '../../controllers/owner_schedule_controller.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/court_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_confirm_dialog.dart';

const _bg = AppColors.background;
const _surface = AppColors.surface;
const _surfaceLow = AppColors.elevated;
const _outline = AppColors.border;
const _cyan = AppColors.secondary;
const _green = AppColors.success;
const _amber = AppColors.warning;
const _red = AppColors.error;
const _onSurface = AppColors.textPrimary;
const _onSurfaceVar = AppColors.textSecondary;

/// Day schedule grid — rows are the selected arena's courts, columns are
/// hours. Tap a booked cell for details, an empty cell to block it, a
/// blocked cell to unblock.
class OwnerScheduleScreen extends StatelessWidget {
  const OwnerScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
    if (!Get.isRegistered<OwnerScheduleController>()) {
      Get.put(OwnerScheduleController());
    }
    final c = OwnerScheduleController.to;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _onSurface),
        title: Text('Day Schedule',
            style: AppTextStyles.titleLarge.copyWith(
                color: _onSurface, fontSize: 20, fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _OwnerAvatar(),
          ),
        ],
      ),
      body: Obx(() {
        final arenas = c.arenas;
        if (arenas.isEmpty) {
          return Center(
            child: Text('No arenas yet',
                style: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar, fontSize: 14)),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (arenas.length > 1) ...[
              _ArenaSelector(controller: c),
              const SizedBox(height: 14),
            ],
            _DateCard(controller: c),
            const SizedBox(height: 16),
            const _Legend(),
            const SizedBox(height: 12),
            _GridCard(controller: c),
            const SizedBox(height: 16),
            _OccupancyCard(controller: c),
          ],
        );
      }),
    );
  }
}

// ── Owner avatar (appbar) ───────────────────────────────────────────────

class _OwnerAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final u = AuthController.to.currentUser.value;
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: (u?.avatar.isNotEmpty ?? false)
            ? Image.network(u!.avatar, fit: BoxFit.cover)
            : const Icon(Icons.person, color: _onSurfaceVar, size: 18),
      );
    });
  }
}

// ── Arena selector ────────────────────────────────────────────────────

class _ArenaSelector extends StatelessWidget {
  final OwnerScheduleController controller;
  const _ArenaSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Obx(() => ListView(
            scrollDirection: Axis.horizontal,
            children: controller.arenas.map((a) {
              final selected = controller.arena.value?.id == a.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => controller.selectArena(a),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? AppColors.primary : _outline),
                    ),
                    child: Text(
                      a.name.toUpperCase(),
                      style: AppTextStyles.label.copyWith(
                        color: selected ? AppColors.onPrimary : _onSurfaceVar,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          )),
    );
  }
}

// ── Date strip (next 14 days) ─────────────────────────────────────────

class _DateCard extends StatelessWidget {
  final OwnerScheduleController controller;
  const _DateCard({required this.controller});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Container(
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 68,
        child: Obx(() {
          final sel = controller.date.value;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: 14,
            itemBuilder: (_, i) {
              final d = DateTime(today.year, today.month, today.day + i);
              final selected = d.year == sel.year &&
                  d.month == sel.month &&
                  d.day == sel.day;
              return GestureDetector(
                onTap: () => controller.selectDate(d),
                child: Container(
                  width: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_days[d.weekday - 1].toUpperCase(),
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: selected ? AppColors.onPrimary : _onSurfaceVar)),
                      const SizedBox(height: 4),
                      Text('${d.day}',
                          style: AppTextStyles.titleLarge.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: selected ? AppColors.onPrimary : _onSurface)),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: AppTextStyles.caption.copyWith(
                    color: _onSurfaceVar,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ],
        );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        dot(_green, 'Booked'),
        dot(_amber, 'Pending'),
        dot(_red, 'Blocked'),
        dot(_outline, 'Free'),
      ],
    );
  }
}

// ── Grid ──────────────────────────────────────────────────────────────

IconData _courtTypeIcon(CourtType t) {
  switch (t) {
    case CourtType.football:
      return Icons.sports_soccer;
    case CourtType.padel:
      return Icons.sports_tennis;
    case CourtType.indoor:
      return Icons.stadium_outlined;
    case CourtType.cricket:
      return Icons.sports_cricket;
    case CourtType.other:
      return Icons.sports_outlined;
  }
}

class _GridCard extends StatelessWidget {
  final OwnerScheduleController controller;
  const _GridCard({required this.controller});

  static const double _nameW = 128;
  static const double _cellW = 56;
  static const double _cellH = 56;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Touch the observables the grid depends on.
      controller.blocked.length;
      OwnerBookingController.to.bookings.length;
      controller.date.value;

      final courts = controller.courts;
      final hours = controller.hours;
      if (courts.isEmpty || hours.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outline),
          ),
          child: Center(
            child: Text('No active courts in this arena',
                style: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar, fontSize: 14)),
          ),
        );
      }
      return Container(
        decoration: BoxDecoration(
          color: _surfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _outline),
        ),
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  SizedBox(
                    width: _nameW,
                    child: Text('FACILITY',
                        style: AppTextStyles.caption.copyWith(
                            color: _onSurfaceVar,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6)),
                  ),
                  ...hours.map((h) => SizedBox(
                        width: _cellW,
                        child: Text(
                          '${(h % 24).toString().padLeft(2, '0')}:00',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                              color: _onSurfaceVar,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800),
                        ),
                      )),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(
                    height: 1, color: _outline.withValues(alpha: 0.5)),
              ),
              for (var i = 0; i < courts.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(
                        height: 1, color: _outline.withValues(alpha: 0.25)),
                  ),
                Row(
                  children: [
                    SizedBox(
                      width: _nameW,
                      height: _cellH,
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _cyan.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_courtTypeIcon(courts[i].type),
                                size: 17, color: _cyan),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              courts[i].name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: _onSurface,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...hours.map((h) => _Cell(
                        controller: controller, court: courts[i], hour: h)),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _Cell extends StatelessWidget {
  final OwnerScheduleController controller;
  final CourtModel court;
  final int hour;
  const _Cell({required this.controller, required this.court, required this.hour});

  @override
  Widget build(BuildContext context) {
    if (!controller.courtOperatesAt(court, hour)) {
      // Outside this court's operating hours.
      return const SizedBox(width: _GridCard._cellW, height: _GridCard._cellH);
    }
    final status = controller.cellStatus(court.id, hour);

    Color fill;
    Color border;
    Widget? child;
    switch (status) {
      case ScheduleCellStatus.confirmed:
        fill = _green.withValues(alpha: 0.25);
        border = _green;
        child = const Icon(Icons.person, size: 15, color: _green);
        break;
      case ScheduleCellStatus.completed:
        fill = _green.withValues(alpha: 0.10);
        border = _green.withValues(alpha: 0.4);
        child = Icon(Icons.check, size: 14, color: _green.withValues(alpha: 0.7));
        break;
      case ScheduleCellStatus.pending:
        fill = _amber.withValues(alpha: 0.18);
        border = _amber;
        child = const Icon(Icons.hourglass_bottom, size: 14, color: _amber);
        break;
      case ScheduleCellStatus.blocked:
        fill = _red.withValues(alpha: 0.18);
        border = _red;
        child = const Icon(Icons.block, size: 14, color: _red);
        break;
      case ScheduleCellStatus.past:
        fill = _surfaceLow.withValues(alpha: 0.6);
        border = _outline.withValues(alpha: 0.4);
        break;
      case ScheduleCellStatus.available:
        fill = _surface;
        border = _outline;
        break;
    }

    return GestureDetector(
      onTap: () => _onTap(context, status),
      child: Container(
        width: _GridCard._cellW - 4,
        height: _GridCard._cellH,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 1),
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }

  void _onTap(BuildContext context, ScheduleCellStatus status) {
    switch (status) {
      case ScheduleCellStatus.confirmed:
      case ScheduleCellStatus.pending:
      case ScheduleCellStatus.completed:
        final b = controller.bookingAt(court.id, hour);
        if (b != null) _showBookingSheet(context, b);
        break;
      case ScheduleCellStatus.available:
        _confirmBlock(context);
        break;
      case ScheduleCellStatus.blocked:
        _confirmUnblock(context);
        break;
      case ScheduleCellStatus.past:
        break;
    }
  }

  String get _hourLabel {
    final h = hour % 24;
    return '${h.toString().padLeft(2, '0')}:00 – ${((h + 1) % 24).toString().padLeft(2, '0')}:00';
  }

  Future<void> _confirmBlock(BuildContext context) async {
    final ok = await AppConfirmDialog.show(
      context,
      icon: Icons.block,
      iconColor: AppColors.error,
      title: 'Block this slot?',
      subtitle: '${court.name} · $_hourLabel',
      message:
          'Blocking this slot will prevent any new bookings from being made '
          'during this time period. You can unblock it again at any time '
          'from this schedule.',
      confirmLabel: 'Confirm Block',
    );
    if (ok != true) return;
    controller.block(court, hour).catchError((e) {
      Get.snackbar('Could not block slot', '$e',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    });
  }

  Future<void> _confirmUnblock(BuildContext context) async {
    final ok = await AppConfirmDialog.show(
      context,
      icon: Icons.lock_open_rounded,
      iconColor: AppColors.success,
      title: 'Unblock this slot?',
      subtitle: '${court.name} · $_hourLabel',
      message:
          'This slot will become available again and customers will be able '
          'to book it right away.',
      confirmLabel: 'Confirm Unblock',
    );
    if (ok != true) return;
    controller.unblock(court, hour).catchError((e) {
      Get.snackbar('Could not unblock slot', '$e',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    });
  }

  void _showBookingSheet(BuildContext context, BookingModel b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final badgeColor = (b.status == BookingStatus.confirmed || b.status == BookingStatus.completed)
            ? _green
            : (b.status == BookingStatus.pendingDeposit || b.status == BookingStatus.depositSubmitted)
                ? _amber
                : (b.status == BookingStatus.cancelled || b.status == BookingStatus.rejected)
                    ? _red
                    : _onSurfaceVar;
        return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    b.customerName.isNotEmpty ? b.customerName : 'Customer',
                    style: AppTextStyles.titleMedium.copyWith(
                        color: _onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(b.status.label.toUpperCase(),
                      style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          color: badgeColor,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${b.courtName} · ${b.timeRange} · ${b.totalHours}h',
                style: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar, fontSize: 13.5)),
            const SizedBox(height: 4),
            Text('PKR ${b.totalAmount.toStringAsFixed(0)}',
                style: AppTextStyles.scoreboard.copyWith(
                    color: _onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
            if (b.checkedIn) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.login, size: 15, color: _green),
                  const SizedBox(width: 6),
                  Text('Checked in',
                      style: AppTextStyles.bodySmall.copyWith(color: _green, fontSize: 12.5)),
                ],
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Get.back();
                  Get.toNamed(AppRoutes.bookingDetailOwner, arguments: b.id);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('View Booking',
                    style: AppTextStyles.button.copyWith(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      );
      },
    );
  }
}

// ── Occupancy rate ───────────────────────────────────────────────────

class _OccupancyCard extends StatelessWidget {
  final OwnerScheduleController controller;
  const _OccupancyCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline),
      ),
      child: Obx(() {
        // Touch the observables the rate depends on.
        controller.blocked.length;
        OwnerBookingController.to.bookings.length;
        controller.date.value;

        final rate = controller.occupancyRate;
        final occupied = controller.occupiedSlotCount;
        final total = controller.totalSlotCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OCCUPANCY RATE',
                          style: AppTextStyles.label.copyWith(
                              color: _onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4)),
                      const SizedBox(height: 2),
                      Text(
                        total > 0
                            ? '$occupied of $total hourly slots booked'
                            : 'No operating slots today',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: _onSurfaceVar, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _cyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.show_chart, size: 18, color: _cyan),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('${(rate * 100).round()}%',
                style: AppTextStyles.scoreboardMedium.copyWith(
                    color: AppColors.primary, fontSize: 34, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: rate.clamp(0, 1),
                minHeight: 8,
                backgroundColor: _outline.withValues(alpha: 0.4),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ],
        );
      }),
    );
  }
}
