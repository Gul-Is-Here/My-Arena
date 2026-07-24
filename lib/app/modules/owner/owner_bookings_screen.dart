import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/owner_booking_controller.dart';
import '../../data/models/booking_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

// ── Palette (aligned with the app's global dark theme) ────────────────────────
const _bg = AppColors.background;
const _white = AppColors.surface; // card / chrome surface
const _cardRadius = 16.0;
const _orange = AppColors.secondary; // brand accent (CTAs, active tab, links)
const _green = AppColors.success;
const _grey = AppColors.textSecondary;
const _red = AppColors.error;
const _textDark = AppColors.textPrimary; // primary on-surface text
const _textMid = AppColors.textSecondary;
const _outline = AppColors.border;
const _onColor =
    Colors.white; // text/icon on a colored (non-surface) background

// ── Status pill color ──────────────────────────────────────────────────────
Color _statusColor(BookingModel b) {
  if (b.isActive) return AppColors.primary;
  switch (b.status) {
    case BookingStatus.depositSubmitted:
    case BookingStatus.pendingDeposit:
      return AppColors.warning;
    case BookingStatus.confirmed:
      return _green;
    case BookingStatus.completed:
    case BookingStatus.refundConfirmed:
      return _green;
    case BookingStatus.cancelled:
    case BookingStatus.rejected:
    case BookingStatus.refundPending:
    case BookingStatus.refundSent:
      return _grey;
  }
}

String _statusLabel(BookingModel b) {
  if (b.isActive) return 'Ongoing';
  switch (b.status) {
    case BookingStatus.depositSubmitted:
    case BookingStatus.pendingDeposit:
      return 'Pending';
    case BookingStatus.refundPending:
    case BookingStatus.refundSent:
      return 'Refund';
    default:
      return b.status.label;
  }
}

String _dateLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = that.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}

// ── Customer info (name + phone), resolved + cached ──────────────────────────
class _CustomerInfo {
  final String name;
  final String phone;
  const _CustomerInfo(this.name, this.phone);
}

final Map<String, _CustomerInfo> _customerCache = {};
final Map<String, String> _customerNameCache = {};

Future<_CustomerInfo> _resolveCustomer(BookingModel b) async {
  final cached = _customerCache[b.customerId];
  if (cached != null) return cached;
  try {
    final user = await AuthService().fetchUser(b.customerId);
    final name = b.customerName.isNotEmpty
        ? b.customerName
        : ((user?.name.isNotEmpty ?? false) ? user!.name : 'Customer');
    final info = _CustomerInfo(name, user?.phone ?? '');
    _customerCache[b.customerId] = info;
    return info;
  } catch (_) {
    return _CustomerInfo(
      b.customerName.isNotEmpty ? b.customerName : 'Customer',
      '',
    );
  }
}

Future<String> _resolveCustomerName(BookingModel b) async {
  if (b.customerName.isNotEmpty) return b.customerName;
  final cached = _customerNameCache[b.customerId];
  if (cached != null) return cached;
  final info = await _resolveCustomer(b);
  _customerNameCache[b.customerId] = info.name;
  return info.name;
}

void _exportCsv(BuildContext context, List<BookingModel> bookings) {
  final rows = [
    'Date,Arena,Court,Customer,Start,Hours,Total (PKR),Deposit (PKR),Status',
    ...bookings
        .where(
          (b) =>
              b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.completed,
        )
        .map((b) {
          String esc(String s) =>
              s.contains(',') ? '"${s.replaceAll('"', '""')}"' : s;
          final d = b.date;
          return [
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
            esc(b.arenaName),
            esc(b.courtName),
            esc(b.customerName.isNotEmpty ? b.customerName : 'Customer'),
            '${b.startHour.toString().padLeft(2, '0')}:00',
            '${b.totalHours}',
            b.totalAmount.toStringAsFixed(0),
            b.depositAmount.toStringAsFixed(0),
            b.status.label,
          ].join(',');
        }),
  ];
  final csv = rows.join('\n');
  Clipboard.setData(ClipboardData(text: csv));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'CSV copied to clipboard (${rows.length - 1} completed bookings)',
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

// ── Date range filter ─────────────────────────────────────────────────────────

enum _RangeFilter { today, week, month, custom }

bool _inRange(DateTime d, _RangeFilter filter, DateTimeRange? custom) {
  final now = DateTime.now();
  final that = DateTime(d.year, d.month, d.day);
  switch (filter) {
    case _RangeFilter.today:
      final today = DateTime(now.year, now.month, now.day);
      return that == today;
    case _RangeFilter.week:
      final weekStart = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - 1),
      );
      final weekEnd = weekStart.add(const Duration(days: 6));
      return !that.isBefore(weekStart) && !that.isAfter(weekEnd);
    case _RangeFilter.month:
      return d.year == now.year && d.month == now.month;
    case _RangeFilter.custom:
      if (custom == null) return true;
      final start = DateTime(
        custom.start.year,
        custom.start.month,
        custom.start.day,
      );
      final end = DateTime(custom.end.year, custom.end.month, custom.end.day);
      return !that.isBefore(start) && !that.isAfter(end);
  }
}

// ── Status tab filter ─────────────────────────────────────────────────────────

enum _StatusTab { all, pending, confirmed, ongoing, completed, refunds }

bool _matchesStatusTab(BookingModel b, _StatusTab tab) {
  switch (tab) {
    case _StatusTab.all:
      return true;
    case _StatusTab.pending:
      return b.status == BookingStatus.depositSubmitted ||
          b.status == BookingStatus.pendingDeposit;
    case _StatusTab.confirmed:
      return b.status == BookingStatus.confirmed && !b.isActive;
    case _StatusTab.ongoing:
      return b.isActive;
    case _StatusTab.completed:
      return b.status == BookingStatus.completed;
    case _StatusTab.refunds:
      return b.status == BookingStatus.refundPending ||
          b.status == BookingStatus.refundSent;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  final _searchCtrl = TextEditingController();
  final _searchQuery = ''.obs;
  final Rx<_RangeFilter> _rangeFilter = _RangeFilter.today.obs;
  final Rx<DateTimeRange?> _customRange = Rx<DateTimeRange?>(null);
  final Rx<_StatusTab> _statusTab = _StatusTab.all.obs;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => _searchQuery.value = _searchCtrl.text);
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customRange.value,
    );
    if (picked != null) {
      _customRange.value = picked;
      _rangeFilter.value = _RangeFilter.custom;
    }
  }

  List<BookingModel> _filtered(List<BookingModel> source) {
    final q = _searchQuery.value.toLowerCase();
    return source.where((b) {
      if (!_inRange(b.date, _rangeFilter.value, _customRange.value)) {
        return false;
      }
      if (!_matchesStatusTab(b, _statusTab.value)) return false;
      if (q.isEmpty) return true;
      return b.customerName.toLowerCase().contains(q) ||
          b.arenaName.toLowerCase().contains(q) ||
          b.courtName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = OwnerBookingController.to;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(c),
            _buildSearchBar(),
            _buildRangeRow(),
            const SizedBox(height: 10),
            _buildStatusTabs(c),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                if (c.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: _orange),
                  );
                }
                if (c.hasError.value) {
                  return _ErrorState(onRetry: c.retry);
                }
                final items = _filtered(c.all);
                if (items.isEmpty) {
                  return _emptyState(
                    _statusTab.value == _StatusTab.pending
                        ? Icons.task_alt
                        : Icons.event_note_outlined,
                    'No bookings found',
                    'Try a different filter or search term',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _BookingCard(
                    booking: items[i],
                    controller: c,
                    onTap: () => Get.toNamed(
                      AppRoutes.bookingDetailOwner,
                      arguments: items[i].id,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: 74 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Fab(
              icon: Icons.person_add_alt,
              label: 'Walk-in',
              color: _white,
              textColor: _textDark,
              onTap: () => Get.toNamed(AppRoutes.manualBooking),
            ),
            const SizedBox(height: 10),
            _Fab(
              icon: Icons.qr_code_scanner,
              label: 'Scan QR',
              color: AppColors.primary,
              textColor: AppColors.onPrimary,
              onTap: () => Get.toNamed(AppRoutes.ownerQrScanner),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(OwnerBookingController c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bookings',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: _textDark,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 2),
                Obx(() {
                  final items = _filtered(c.all);
                  final total = items
                      .where(
                        (b) =>
                            b.status == BookingStatus.confirmed ||
                            b.status == BookingStatus.completed,
                      )
                      .fold<double>(0, (sum, b) => sum + b.totalAmount);
                  final rangeLabel = switch (_rangeFilter.value) {
                    _RangeFilter.today => 'Today',
                    _RangeFilter.week => 'This week',
                    _RangeFilter.month => 'This month',
                    _RangeFilter.custom => 'Selected range',
                  };
                  return Text(
                    '$rangeLabel · ${items.length} bookings · PKR ${total.toStringAsFixed(0)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _textMid,
                      fontSize: 13,
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.download_outlined,
            onTap: () => _exportCsv(context, c.all),
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.calendar_month_outlined,
            onTap: () => Get.toNamed(AppRoutes.ownerSchedule),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, color: _textMid, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: AppTextStyles.bodyMedium.copyWith(color: _textDark),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  hintText: 'Search by player, arena, or sport…',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: _textMid),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Obx(
              () => _searchQuery.value.isEmpty
                  ? const SizedBox(width: 14)
                  : Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _searchCtrl.clear(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _bg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: _textMid,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeRow() {
    final options = <(_RangeFilter, String)>[
      (_RangeFilter.today, 'Today'),
      (_RangeFilter.week, 'This week'),
      (_RangeFilter.month, 'This month'),
    ];
    return SizedBox(
      height: 38,
      child: Obx(
        () => ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final (filter, label) in options) ...[
              _RangePill(
                label: label,
                selected: _rangeFilter.value == filter,
                onTap: () => _rangeFilter.value = filter,
              ),
              const SizedBox(width: 8),
            ],
            _RangePill(
              label:
                  _rangeFilter.value == _RangeFilter.custom &&
                      _customRange.value != null
                  ? '${_customRange.value!.start.day}/${_customRange.value!.start.month} – ${_customRange.value!.end.day}/${_customRange.value!.end.month}'
                  : 'Range',
              icon: Icons.calendar_today_outlined,
              selected: _rangeFilter.value == _RangeFilter.custom,
              onTap: _pickCustomRange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTabs(OwnerBookingController c) {
    return SizedBox(
      height: 34,
      child: Obx(() {
        final all = _filtered0(c.all, tab: null).length;
        final tabs = <(_StatusTab, String)>[
          (_StatusTab.all, 'All $all'),
          (
            _StatusTab.pending,
            'Pending ${_filtered0(c.all, tab: _StatusTab.pending).length}',
          ),
          (
            _StatusTab.ongoing,
            'Ongoing ${_filtered0(c.all, tab: _StatusTab.ongoing).length}',
          ),
          (
            _StatusTab.confirmed,
            'Confirmed ${_filtered0(c.all, tab: _StatusTab.confirmed).length}',
          ),
          (
            _StatusTab.completed,
            'Completed ${_filtered0(c.all, tab: _StatusTab.completed).length}',
          ),
          (
            _StatusTab.refunds,
            'Refunds ${_filtered0(c.all, tab: _StatusTab.refunds).length}',
          ),
        ];
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final (tab, label) in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: GestureDetector(
                  onTap: () => _statusTab.value = tab,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.label.copyWith(
                          fontSize: 14,
                          fontWeight: _statusTab.value == tab
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: _statusTab.value == tab
                              ? AppColors.primary
                              : _textMid,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 2.5,
                        width: _statusTab.value == tab ? 22 : 0,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  // Counts bookings within the current date-range + search filter for a given
  // status tab (or the total when [tab] is null), without touching the
  // currently-selected status tab.
  List<BookingModel> _filtered0(
    List<BookingModel> source, {
    required _StatusTab? tab,
  }) {
    final q = _searchQuery.value.toLowerCase();
    return source.where((b) {
      if (!_inRange(b.date, _rangeFilter.value, _customRange.value)) {
        return false;
      }
      if (tab != null && !_matchesStatusTab(b, tab)) return false;
      if (q.isEmpty) return true;
      return b.customerName.toLowerCase().contains(q) ||
          b.arenaName.toLowerCase().contains(q) ||
          b.courtName.toLowerCase().contains(q);
    }).toList();
  }
}

// ── Range filter pill ────────────────────────────────────────────────────────

class _RangePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _RangePill({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : _white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : _outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? AppColors.onPrimary : _textMid,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? AppColors.onPrimary : _textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final OwnerBookingController controller;
  final VoidCallback? onTap;

  const _BookingCard({
    required this.booking,
    required this.controller,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final statusColor = _statusColor(b);
    final isPending =
        b.status == BookingStatus.depositSubmitted ||
        b.status == BookingStatus.pendingDeposit;
    final hasScreenshot =
        b.depositScreenshot != null && b.depositScreenshot!.startsWith('http');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: _outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Name + status pill (left) · price (right) ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: _CustomerNameText(
                          booking: b,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: _textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(
                        color: statusColor,
                        label: _statusLabel(b),
                        pulse: b.isActive,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'PKR ${b.totalAmount.toStringAsFixed(0)}',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Arena · sport ──
            Text(
              '${b.arenaName} · ${b.courtName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: _textMid,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            // ── Time / date row + trailing action icons ──
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: _textMid),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${_dateLabel(b.date)} · ${b.startTime} – ${b.endTime}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _textMid,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                if (b.bookedByRole != 'customer')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'WALK-IN',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: _orange,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                if (hasScreenshot) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _showScreenshotDialog(context, b),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      size: 18,
                      color: _orange,
                    ),
                  ),
                ],
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: FilledButton(
                        onPressed: () =>
                            _showApproveDialog(context, b, controller),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Confirm',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        onPressed: () =>
                            _showRejectDialog(context, b, controller),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textMid,
                          side: const BorderSide(color: _outline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Reject',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (b.status == BookingStatus.refundPending ||
                b.status == BookingStatus.refundSent) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: _outline),
              const SizedBox(height: 10),
              _RefundRow(booking: b, controller: controller),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Color color;
  final String label;
  final bool pulse;
  const _StatusPill({
    required this.color,
    required this.label,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefundRow extends StatelessWidget {
  final BookingModel booking;
  final OwnerBookingController controller;
  const _RefundRow({required this.booking, required this.controller});

  @override
  Widget build(BuildContext context) {
    final cx = booking.cancellation;
    final sent = booking.status == BookingStatus.refundSent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cx != null)
          Row(
            children: [
              const Icon(
                Icons.account_balance_outlined,
                size: 15,
                color: _textMid,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${cx.bankName} · ${cx.accountNumber}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _textDark,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Refund PKR ${(cx?.refundAmount ?? 0).toStringAsFixed(0)}',
              style: AppTextStyles.titleMedium.copyWith(
                color: _orange,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!sent)
              FilledButton.icon(
                onPressed: () async {
                  controller.sendRefund(booking.id);
                  final name = await _resolveCustomerName(booking);
                  Get.snackbar(
                    'Refund sent',
                    '$name will confirm receipt.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: _green,
                    colorText: _onColor,
                    margin: const EdgeInsets.all(16),
                  );
                },
                icon: const Icon(Icons.upload_outlined, size: 16),
                label: const Text('Send Refund'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              )
            else
              Text(
                'Awaiting confirmation',
                style: AppTextStyles.caption.copyWith(
                  color: _textMid,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

void _showScreenshotDialog(BuildContext context, BookingModel b) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: _white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Deposit Screenshot',
              style: AppTextStyles.titleLarge.copyWith(
                color: _textDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'PKR ${b.depositAmount.toStringAsFixed(0)}',
              style: AppTextStyles.headlineMedium.copyWith(
                color: _orange,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            if (b.depositScreenshot != null &&
                b.depositScreenshot!.startsWith('http'))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  b.depositScreenshot!,
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, e, s) => const SizedBox(
                    height: 100,
                    child: Center(
                      child: Icon(Icons.broken_image, color: _textMid),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _outline),
                ),
                child: const Center(
                  child: Icon(Icons.receipt_long, size: 48, color: _textMid),
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: Get.back,
              child: Text(
                'Close',
                style: AppTextStyles.button.copyWith(
                  color: _orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showApproveDialog(
  BuildContext context,
  BookingModel booking,
  OwnerBookingController controller,
) async {
  final name = await _resolveCustomerName(booking);
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (_) => _ActionDialog(
      icon: Icons.check_circle_outline,
      iconColor: _green,
      title: 'Approve Booking?',
      subtitle:
          'Confirm $name\'s booking for ${booking.arenaName}.\n\nThey will be notified immediately.',
      confirmLabel: 'Approve',
      confirmColor: _green,
      onConfirm: () async {
        Get.back();
        await controller.approve(booking.id);
        Get.snackbar(
          'Approved!',
          '$name\'s booking has been confirmed.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _green,
          colorText: _onColor,
          margin: const EdgeInsets.all(16),
        );
      },
    ),
  );
}

Future<void> _showRejectDialog(
  BuildContext context,
  BookingModel booking,
  OwnerBookingController controller,
) async {
  final name = await _resolveCustomerName(booking);
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (_) => _ActionDialog(
      icon: Icons.cancel_outlined,
      iconColor: _red,
      title: 'Reject Booking?',
      subtitle:
          'Reject $name\'s booking for ${booking.arenaName}.\n\nYou will need to refund the deposit manually.',
      confirmLabel: 'Reject',
      confirmColor: _red,
      onConfirm: () {
        Get.back();
        controller.reject(booking.id);
        Get.snackbar(
          'Rejected',
          '$name\'s booking has been rejected.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _red,
          colorText: _onColor,
          margin: const EdgeInsets.all(16),
        );
      },
    ),
  );
}

class _ActionDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _ActionDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.titleLarge.copyWith(
                color: _textDark,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: _textMid,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: Get.back,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textMid,
                      side: const BorderSide(color: _outline),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.button.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: _onColor,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: AppTextStyles.button.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _CustomerNameText extends StatelessWidget {
  final BookingModel booking;
  final TextStyle style;

  const _CustomerNameText({required this.booking, required this.style});

  @override
  Widget build(BuildContext context) {
    if (booking.customerName.isNotEmpty) {
      return Text(
        booking.customerName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return FutureBuilder<String>(
      future: _resolveCustomerName(booking),
      builder: (_, snap) => Text(
        snap.data ?? 'Customer',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _outline),
        ),
        child: Icon(icon, size: 20, color: _textDark),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _Fab({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _emptyState(IconData icon, String title, String subtitle) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 48, color: _orange),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            color: _textDark,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: _textMid,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined, color: _textMid, size: 40),
          const SizedBox(height: 12),
          Text(
            'Could not load bookings',
            style: AppTextStyles.bodyLarge.copyWith(color: _textDark),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: AppTextStyles.label.copyWith(color: _orange),
            ),
          ),
        ],
      ),
    );
  }
}
