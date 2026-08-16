import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/owner_booking_controller.dart';
import '../../data/models/booking_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

// ── Breakpoints ───────────────────────────────────────────────────────────────
const _kTablet = 720.0;
const _kDesktop = 1100.0;
const _kMaxContent = 1200.0;

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg = AppColors.background;
const _surface = AppColors.surface;
const _card = AppColors.elevated;
const _outline = AppColors.border;
const _green = AppColors.success;
const _amber = AppColors.warning;
const _red = AppColors.error;
const _primary = AppColors.primary;
const _textPrimary = AppColors.textPrimary;
const _textSecondary = AppColors.textSecondary;
const _secondary = AppColors.secondary;

// ── Status helpers ────────────────────────────────────────────────────────────

Color _statusColor(BookingModel b) {
  if (b.isActive) return _primary;
  switch (b.status) {
    case BookingStatus.depositSubmitted:
    case BookingStatus.pendingDeposit:
    case BookingStatus.rescheduleRequested:
      return _amber;
    case BookingStatus.confirmed:
    case BookingStatus.completed:
    case BookingStatus.refundConfirmed:
    case BookingStatus.ongoing:
      return _green;
    case BookingStatus.cancelled:
    case BookingStatus.rejected:
    case BookingStatus.refundPending:
    case BookingStatus.refundSent:
      return _red;
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
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${wd[d.weekday - 1]} ${d.day} ${mo[d.month - 1]}';
}

// ── Customer name resolution — instance-level cache on the state ──────────────
class _CustomerInfo {
  final String name;
  final String phone;
  const _CustomerInfo(this.name, this.phone);
}

// ── Date range filter ─────────────────────────────────────────────────────────
enum _RangeFilter { all, today, week, month, custom }

bool _inRange(DateTime d, _RangeFilter f, DateTimeRange? custom) {
  final now = DateTime.now();
  final that = DateTime(d.year, d.month, d.day);
  switch (f) {
    case _RangeFilter.all:
      return true;
    case _RangeFilter.today:
      return that == DateTime(now.year, now.month, now.day);
    case _RangeFilter.week:
      final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      return !that.isBefore(start) && !that.isAfter(start.add(const Duration(days: 6)));
    case _RangeFilter.month:
      return d.year == now.year && d.month == now.month;
    case _RangeFilter.custom:
      if (custom == null) return true;
      final s = DateTime(custom.start.year, custom.start.month, custom.start.day);
      final e = DateTime(custom.end.year, custom.end.month, custom.end.day);
      return !that.isBefore(s) && !that.isAfter(e);
  }
}

// ── Status tab ────────────────────────────────────────────────────────────────
enum _StatusTab { all, pending, confirmed, ongoing, completed, refunds }

bool _matchesStatusTab(BookingModel b, _StatusTab t) {
  switch (t) {
    case _StatusTab.all:       return true;
    case _StatusTab.pending:   return b.status == BookingStatus.depositSubmitted || b.status == BookingStatus.pendingDeposit;
    case _StatusTab.confirmed: return b.status == BookingStatus.confirmed && !b.isActive;
    case _StatusTab.ongoing:   return b.isActive;
    case _StatusTab.completed: return b.status == BookingStatus.completed;
    case _StatusTab.refunds:   return b.status == BookingStatus.refundPending || b.status == BookingStatus.refundSent;
  }
}

bool _matchesSearch(BookingModel b, String q) =>
    b.customerName.toLowerCase().contains(q) ||
    b.arenaName.toLowerCase().contains(q) ||
    b.courtName.toLowerCase().contains(q) ||
    b.id.toLowerCase().contains(q);

// ── CSV export ────────────────────────────────────────────────────────────────
void _exportCsv(BuildContext context, List<BookingModel> bookings) {
  final rows = [
    'Date,Arena,Court,Customer,Start,Hours,Total (PKR),Deposit (PKR),Status',
    ...bookings.where((b) =>
        b.status == BookingStatus.confirmed || b.status == BookingStatus.completed).map((b) {
      String esc(String s) => s.contains(',') ? '"${s.replaceAll('"', '""')}"' : s;
      final d = b.date;
      return [
        '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}',
        esc(b.arenaName), esc(b.courtName),
        esc(b.customerName.isNotEmpty ? b.customerName : 'Customer'),
        '${b.startHour.toString().padLeft(2,'0')}:00',
        '${b.totalHours}',
        b.totalAmount.toStringAsFixed(0),
        b.depositAmount.toStringAsFixed(0),
        b.status.label,
      ].join(',');
    }),
  ];
  Clipboard.setData(ClipboardData(text: rows.join('\n')));
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('CSV copied (${rows.length - 1} bookings)'),
    duration: const Duration(seconds: 3),
  ));
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
  final Rx<_RangeFilter> _rangeFilter = _RangeFilter.all.obs;
  final Rx<DateTimeRange?> _customRange = Rx<DateTimeRange?>(null);
  final Rx<_StatusTab> _statusTab = _StatusTab.all.obs;

  // Instance-level cache — no stale/race issues from global state
  final Map<String, _CustomerInfo> _customerCache = {};

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    if (!Get.isRegistered<OwnerBookingController>()) {
      Get.put(OwnerBookingController(), permanent: true);
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchQuery.value = _searchCtrl.text;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customRange.value,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _primary,
            onPrimary: AppColors.onPrimary,
            surface: _surface,
            onSurface: _textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _customRange.value = picked;
      _rangeFilter.value = _RangeFilter.custom;
    }
  }

  List<BookingModel> _filtered(List<BookingModel> source) {
    final q = _searchQuery.value.toLowerCase();
    return source.where((b) {
      if (!_inRange(b.date, _rangeFilter.value, _customRange.value)) return false;
      if (!_matchesStatusTab(b, _statusTab.value)) return false;
      if (q.isNotEmpty && !_matchesSearch(b, q)) return false;
      return true;
    }).toList();
  }

  // Single-pass computation of all tab counts — replaces 6 separate _filtered0 calls
  Map<_StatusTab, int> _computeCounts(List<BookingModel> source) {
    final q = _searchQuery.value.toLowerCase();
    final counts = {for (final t in _StatusTab.values) t: 0};
    for (final b in source) {
      if (!_inRange(b.date, _rangeFilter.value, _customRange.value)) continue;
      if (q.isNotEmpty && !_matchesSearch(b, q)) continue;
      counts[_StatusTab.all] = counts[_StatusTab.all]! + 1;
      for (final t in _StatusTab.values) {
        if (t != _StatusTab.all && _matchesStatusTab(b, t)) {
          counts[t] = counts[t]! + 1;
        }
      }
    }
    return counts;
  }

  Future<_CustomerInfo> _resolveCustomer(BookingModel b) async {
    final cached = _customerCache[b.customerId];
    if (cached != null) return cached;
    try {
      final user = await AuthService().fetchUser(b.customerId);
      final name = b.customerName.isNotEmpty
          ? b.customerName
          : (user?.name.isNotEmpty == true ? user!.name : 'Customer');
      final info = _CustomerInfo(name, user?.phone ?? '');
      _customerCache[b.customerId] = info;
      return info;
    } catch (_) {
      return _CustomerInfo(b.customerName.isNotEmpty ? b.customerName : 'Customer', '');
    }
  }

  Future<String> _resolveCustomerName(BookingModel b) async {
    if (b.customerName.isNotEmpty) return b.customerName;
    return (await _resolveCustomer(b)).name;
  }

  @override
  Widget build(BuildContext context) {
    final c = OwnerBookingController.to;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isTablet = w >= _kTablet;
        final isDesktop = w >= _kDesktop;
        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxContent),
                child: Column(
                  children: [
                    _Header(
                      controller: c,
                      getFiltered: () => _filtered(c.all),
                      rangeFilter: _rangeFilter,
                      onExport: () => _exportCsv(context, c.all),
                    ),
                    _FiltersBar(
                      searchCtrl: _searchCtrl,
                      searchQuery: _searchQuery,
                      rangeFilter: _rangeFilter,
                      customRange: _customRange,
                      statusTab: _statusTab,
                      onPickRange: _pickCustomRange,
                      computeCounts: () => _computeCounts(c.all),
                      bookings: c.bookings,
                      isTablet: isTablet,
                    ),
                    Expanded(
                      child: Obx(() {
                        if (c.isLoading.value) return _LoadingSkeleton(isTablet: isTablet);
                        if (c.hasError.value) return _ErrorState(onRetry: c.retry);
                        final items = _filtered(c.all);
                        if (items.isEmpty) {
                          return _EmptyState(statusTab: _statusTab.value);
                        }
                        return RefreshIndicator(
                          color: _primary,
                          backgroundColor: _surface,
                          onRefresh: () async => c.retry(),
                          child: isDesktop
                              ? _DesktopList(
                                  items: items,
                                  controller: c,
                                  resolveCustomerName: _resolveCustomerName,
                                )
                              : isTablet
                                  ? _TabletGrid(
                                      items: items,
                                      controller: c,
                                      resolveCustomerName: _resolveCustomerName,
                                    )
                                  : _MobileList(
                                      items: items,
                                      controller: c,
                                      resolveCustomerName: _resolveCustomerName,
                                    ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: isDesktop
              ? null
              : _ActionFabs(isTablet: isTablet),
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final OwnerBookingController controller;
  final List<BookingModel> Function() getFiltered;
  final Rx<_RangeFilter> rangeFilter;
  final VoidCallback onExport;

  const _Header({
    required this.controller,
    required this.getFiltered,
    required this.rangeFilter,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bookings',
                    style: AppTextStyles.headlineLarge
                        .copyWith(color: _textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Obx(() {
                  final items = getFiltered();
                  final confirmed = items
                      .where((b) =>
                          b.status == BookingStatus.confirmed ||
                          b.status == BookingStatus.completed)
                      .fold<double>(0, (s, b) => s + b.totalAmount);
                  final label = switch (rangeFilter.value) {
                    _RangeFilter.all => 'All time',
                    _RangeFilter.today => 'Today',
                    _RangeFilter.week => 'This week',
                    _RangeFilter.month => 'This month',
                    _RangeFilter.custom => 'Custom range',
                  };
                  return Text(
                    '$label · ${items.length} bookings · PKR ${confirmed.toStringAsFixed(0)}',
                    style: AppTextStyles.bodySmall.copyWith(color: _textSecondary, fontSize: 12.5),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SmallBtn(icon: Icons.download_outlined, onTap: onExport, tooltip: 'Export CSV'),
          const SizedBox(width: 8),
          _SmallBtn(
            icon: Icons.calendar_month_outlined,
            onTap: () => Get.toNamed(AppRoutes.ownerSchedule),
            tooltip: 'Schedule',
          ),
        ],
      ),
    );
  }
}

// ── Filters bar (search + date pills + status tabs) ───────────────────────────
class _FiltersBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final RxString searchQuery;
  final Rx<_RangeFilter> rangeFilter;
  final Rx<DateTimeRange?> customRange;
  final Rx<_StatusTab> statusTab;
  final VoidCallback onPickRange;
  final Map<_StatusTab, int> Function() computeCounts;
  final RxList<BookingModel> bookings;
  final bool isTablet;

  const _FiltersBar({
    required this.searchCtrl,
    required this.searchQuery,
    required this.rangeFilter,
    required this.customRange,
    required this.statusTab,
    required this.onPickRange,
    required this.computeCounts,
    required this.bookings,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _SearchBar(ctrl: searchCtrl, query: searchQuery),
        ),
        // Date range pills
        SizedBox(
          height: 36,
          child: Obx(() => ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final (f, label) in [
                (_RangeFilter.all, 'All'),
                (_RangeFilter.today, 'Today'),
                (_RangeFilter.week, 'This week'),
                (_RangeFilter.month, 'This month'),
              ]) ...[
                _Chip(
                  label: label,
                  selected: rangeFilter.value == f,
                  onTap: () => rangeFilter.value = f,
                ),
                const SizedBox(width: 8),
              ],
              _Chip(
                icon: Icons.date_range_outlined,
                label: rangeFilter.value == _RangeFilter.custom && customRange.value != null
                    ? '${customRange.value!.start.day}/${customRange.value!.start.month}–${customRange.value!.end.day}/${customRange.value!.end.month}'
                    : 'Range',
                selected: rangeFilter.value == _RangeFilter.custom,
                onTap: onPickRange,
              ),
            ],
          )),
        ),
        const SizedBox(height: 12),
        // Status tabs — single Obx, single-pass count computation
        SizedBox(
          height: 38,
          child: Obx(() {
            // Single pass — not 6×
            final counts = computeCounts();
            const tabs = [
              (_StatusTab.all, 'All'),
              (_StatusTab.pending, 'Pending'),
              (_StatusTab.ongoing, 'Ongoing'),
              (_StatusTab.confirmed, 'Confirmed'),
              (_StatusTab.completed, 'Completed'),
              (_StatusTab.refunds, 'Refunds'),
            ];
            return ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final (tab, label) in tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: GestureDetector(
                      onTap: () => statusTab.value = tab,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 13.5,
                                  fontWeight: statusTab.value == tab ? FontWeight.w800 : FontWeight.w500,
                                  color: statusTab.value == tab ? _primary : _textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _CountBadge(
                                count: counts[tab] ?? 0,
                                active: statusTab.value == tab,
                                urgent: tab == _StatusTab.pending && (counts[tab] ?? 0) > 0,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 2.5,
                            width: statusTab.value == tab ? 24 : 0,
                            decoration: BoxDecoration(
                              color: _primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: _outline.withValues(alpha: 0.6)),
      ],
    );
  }
}

// ── Count badge ───────────────────────────────────────────────────────────────
class _CountBadge extends StatelessWidget {
  final int count;
  final bool active;
  final bool urgent;
  const _CountBadge({required this.count, required this.active, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final bg = urgent ? _amber : active ? _primary.withValues(alpha: 0.18) : _card;
    final fg = urgent ? AppColors.onPrimary : active ? _primary : _textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

// ── Mobile list ───────────────────────────────────────────────────────────────
class _MobileList extends StatelessWidget {
  final List<BookingModel> items;
  final OwnerBookingController controller;
  final Future<String> Function(BookingModel) resolveCustomerName;

  const _MobileList({required this.items, required this.controller, required this.resolveCustomerName});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: items.length,
      itemBuilder: (_, i) => _BookingCard(
        booking: items[i],
        controller: controller,
        resolveCustomerName: resolveCustomerName,
        compact: false,
      ),
    );
  }
}

// ── Tablet 2-column grid ──────────────────────────────────────────────────────
class _TabletGrid extends StatelessWidget {
  final List<BookingModel> items;
  final OwnerBookingController controller;
  final Future<String> Function(BookingModel) resolveCustomerName;

  const _TabletGrid({required this.items, required this.controller, required this.resolveCustomerName});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.55,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _BookingCard(
        booking: items[i],
        controller: controller,
        resolveCustomerName: resolveCustomerName,
        compact: true,
      ),
    );
  }
}

// ── Desktop table-style list ──────────────────────────────────────────────────
class _DesktopList extends StatelessWidget {
  final List<BookingModel> items;
  final OwnerBookingController controller;
  final Future<String> Function(BookingModel) resolveCustomerName;

  const _DesktopList({required this.items, required this.controller, required this.resolveCustomerName});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Table header
        Container(
          color: _surface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Expanded(flex: 3, child: _ColHeader('Customer')),
              const Expanded(flex: 3, child: _ColHeader('Arena / Court')),
              const Expanded(flex: 2, child: _ColHeader('Date & Time')),
              const Expanded(flex: 2, child: _ColHeader('Amount')),
              const Expanded(flex: 2, child: _ColHeader('Status')),
              const SizedBox(width: 80), // actions
            ],
          ),
        ),
        Divider(height: 1, color: _outline),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: _outline.withValues(alpha: 0.5)),
            itemBuilder: (_, i) => _DesktopRow(
              booking: items[i],
              controller: controller,
              resolveCustomerName: resolveCustomerName,
            ),
          ),
        ),
      ],
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: AppTextStyles.caption.copyWith(
            color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5));
  }
}

class _DesktopRow extends StatelessWidget {
  final BookingModel booking;
  final OwnerBookingController controller;
  final Future<String> Function(BookingModel) resolveCustomerName;

  const _DesktopRow({required this.booking, required this.controller, required this.resolveCustomerName});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final color = _statusColor(b);
    final isPending = b.status == BookingStatus.depositSubmitted || b.status == BookingStatus.pendingDeposit;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Get.toNamed(AppRoutes.bookingDetailOwner, arguments: b.id),
        hoverColor: _surface.withValues(alpha: 0.6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _CustomerNameWidget(
                  booking: b,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: _textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.arenaName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(color: _textPrimary, fontSize: 13)),
                    Text(b.courtName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(color: _textSecondary, fontSize: 11.5)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dateLabel(b.date),
                        style: AppTextStyles.caption.copyWith(color: _textPrimary, fontSize: 12)),
                    Text('${b.startTime} – ${b.endTime}',
                        style: AppTextStyles.caption.copyWith(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text('PKR ${b.totalAmount.toStringAsFixed(0)}',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: _textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                flex: 2,
                child: _StatusPill(color: color, label: _statusLabel(b), pulse: b.isActive),
              ),
              SizedBox(
                width: 80,
                child: isPending
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MiniActionBtn(
                            icon: Icons.check,
                            color: _green,
                            onTap: () => _showApproveDialog(context, b, controller, resolveCustomerName),
                          ),
                          const SizedBox(width: 6),
                          _MiniActionBtn(
                            icon: Icons.close,
                            color: _red,
                            onTap: () => _showRejectDialog(context, b, controller, resolveCustomerName),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Booking card (mobile + tablet) ────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final OwnerBookingController controller;
  final Future<String> Function(BookingModel) resolveCustomerName;
  final bool compact;

  const _BookingCard({
    required this.booking,
    required this.controller,
    required this.resolveCustomerName,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final color = _statusColor(b);
    final isPending = b.status == BookingStatus.depositSubmitted || b.status == BookingStatus.pendingDeposit;
    final hasScreenshot = b.depositScreenshot?.startsWith('http') == true;
    final isRefund = b.status == BookingStatus.refundPending || b.status == BookingStatus.refundSent;

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.bookingDetailOwner, arguments: b.id),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left status accent bar
              Container(width: 4, color: color),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Name + Status + Amount
                      Row(
                        children: [
                          Expanded(
                            child: _CustomerNameWidget(
                              booking: b,
                              style: AppTextStyles.titleMedium.copyWith(
                                  color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusPill(color: color, label: _statusLabel(b), pulse: b.isActive),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Row 2: Arena · Court
                      Row(
                        children: [
                          const Icon(Icons.stadium_outlined, size: 13, color: _textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${b.arenaName} · ${b.courtName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(color: _textSecondary, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Recurring badge
                      if (b.isRecurring) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.repeat, size: 11, color: _secondary),
                            const SizedBox(width: 3),
                            Text(
                              'Week ${b.recurringWeek ?? '?'} of ${b.recurringTotal ?? '?'} · Recurring',
                              style: AppTextStyles.caption.copyWith(
                                  color: _secondary, fontSize: 10.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),

                      // Row 3: Date + Time + Amount
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 13, color: _textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_dateLabel(b.date)} · ${b.startTime} – ${b.endTime}',
                              style: AppTextStyles.caption.copyWith(color: _textSecondary, fontSize: 12),
                            ),
                          ),
                          if (b.bookedByRole != 'customer')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _secondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('WALK-IN',
                                  style: AppTextStyles.caption.copyWith(
                                      fontSize: 9, color: _secondary, fontWeight: FontWeight.w800)),
                            ),
                          if (hasScreenshot) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showScreenshotDialog(context, b),
                              child: const Icon(Icons.receipt_long_outlined, size: 16, color: _secondary),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            'PKR ${b.totalAmount.toStringAsFixed(0)}',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: _textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),

                      // Pending action buttons
                      if (isPending && !compact) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 40,
                                child: FilledButton(
                                  onPressed: b.isRecurring && b.recurringGroupId != null
                                      ? () => _showApproveSeriesDialog(context, b, controller, resolveCustomerName)
                                      : () => _showApproveDialog(context, b, controller, resolveCustomerName),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: Text(b.isRecurring ? 'Confirm All' : 'Confirm',
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 40,
                                child: OutlinedButton(
                                  onPressed: b.isRecurring && b.recurringGroupId != null
                                      ? () => _showRejectSeriesDialog(context, b, controller, resolveCustomerName)
                                      : () => _showRejectDialog(context, b, controller, resolveCustomerName),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _red,
                                    side: BorderSide(color: _red.withValues(alpha: 0.5)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: Text(b.isRecurring ? 'Reject All' : 'Reject',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Compact pending indicator
                      if (isPending && compact) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.touch_app_outlined, size: 13, color: _amber),
                              const SizedBox(width: 5),
                              Text('Tap to review',
                                  style: AppTextStyles.caption.copyWith(
                                      color: _amber, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],

                      // Refund row
                      if (isRefund) ...[
                        const SizedBox(height: 10),
                        Divider(height: 1, color: _outline),
                        const SizedBox(height: 10),
                        _RefundRow(booking: b, controller: controller, resolveCustomerName: resolveCustomerName),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final Color color;
  final String label;
  final bool pulse;

  const _StatusPill({required this.color, required this.label, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse) ...[
            Container(
              width: 5, height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ── Refund row ────────────────────────────────────────────────────────────────
class _RefundRow extends StatelessWidget {
  final BookingModel booking;
  final OwnerBookingController controller;
  final Future<String> Function(BookingModel) resolveCustomerName;

  const _RefundRow({required this.booking, required this.controller, required this.resolveCustomerName});

  @override
  Widget build(BuildContext context) {
    final cx = booking.cancellation;
    final sent = booking.status == BookingStatus.refundSent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cx != null)
          Row(children: [
            const Icon(Icons.account_balance_outlined, size: 14, color: _textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${cx.bankName} · ${cx.accountNumber}',
                  style: AppTextStyles.bodySmall.copyWith(color: _textPrimary, fontSize: 12.5)),
            ),
          ]),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Refund PKR ${(cx?.refundAmount ?? 0).toStringAsFixed(0)}',
                style: AppTextStyles.titleMedium.copyWith(
                    color: _secondary, fontSize: 14, fontWeight: FontWeight.w800)),
            if (!sent)
              FilledButton.icon(
                onPressed: () async {
                  controller.sendRefund(booking.id);
                  final name = await resolveCustomerName(booking);
                  Get.snackbar('Refund sent', '$name will confirm receipt.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: _green,
                      colorText: Colors.white,
                      margin: const EdgeInsets.all(16));
                },
                icon: const Icon(Icons.upload_outlined, size: 15),
                label: const Text('Send Refund'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              )
            else
              Text('Awaiting confirmation',
                  style: AppTextStyles.caption.copyWith(color: _textSecondary, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────
class _LoadingSkeleton extends StatelessWidget {
  final bool isTablet;
  const _LoadingSkeleton({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: isTablet ? 6 : 5,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(top: 10),
        height: 90,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _outline),
        ),
        child: Row(
          children: [
            Container(width: 4, decoration: BoxDecoration(
              color: _outline,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            )),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Shimmer(width: 140, height: 13),
                    _Shimmer(width: 200, height: 11),
                    _Shimmer(width: 160, height: 11),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  final double width;
  final double height;
  const _Shimmer({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _outline.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final _StatusTab statusTab;
  const _EmptyState({required this.statusTab});

  @override
  Widget build(BuildContext context) {
    final (icon, title, sub) = switch (statusTab) {
      _StatusTab.pending  => (Icons.task_alt, 'All caught up!', 'No bookings need your approval'),
      _StatusTab.ongoing  => (Icons.sports_outlined, 'No active games', 'Courts are free right now'),
      _StatusTab.refunds  => (Icons.payments_outlined, 'No refund requests', 'No pending refunds in this period'),
      _          => (Icons.event_note_outlined, 'No bookings found', 'Try a different filter or date range'),
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: _primary),
          ),
          const SizedBox(height: 18),
          Text(title,
              style: AppTextStyles.titleMedium.copyWith(
                  color: _textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(sub,
              style: AppTextStyles.bodySmall.copyWith(color: _textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_outlined, color: _red, size: 36),
          ),
          const SizedBox(height: 14),
          Text('Could not load bookings',
              style: AppTextStyles.bodyLarge.copyWith(color: _textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Check your connection and try again',
              style: AppTextStyles.bodySmall.copyWith(color: _textSecondary)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── FABs (mobile + tablet only) ───────────────────────────────────────────────
class _ActionFabs extends StatelessWidget {
  final bool isTablet;
  const _ActionFabs({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    // No bottom nav on tablet — don't add the 74px offset
    final extra = isTablet ? 0.0 : 74.0 + MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: extra),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Fab(icon: Icons.person_add_alt, label: 'Walk-in',
              color: _surface, textColor: _textPrimary,
              onTap: () => Get.toNamed(AppRoutes.manualBooking)),
          const SizedBox(height: 10),
          _Fab(icon: Icons.qr_code_scanner, label: 'Scan QR',
              color: _primary, textColor: AppColors.onPrimary,
              onTap: () => Get.toNamed(AppRoutes.ownerQrScanner)),
        ],
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

  const _Fab({required this.icon, required this.label, required this.color, required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          border: color == _surface ? Border.all(color: _outline) : null,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 17),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ── Mini icon action button (desktop rows) ────────────────────────────────────
class _MiniActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final RxString query;
  const _SearchBar({required this.ctrl, required this.query});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search, color: _textSecondary, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: AppTextStyles.bodyMedium.copyWith(color: _textPrimary),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search by customer, arena, court or ID…',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: _textSecondary, fontSize: 13.5),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Obx(() => query.value.isEmpty
              ? const SizedBox(width: 14)
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: ctrl.clear,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: _card, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 13, color: _textSecondary),
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _primary : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _primary : _outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? AppColors.onPrimary : _textSecondary),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: AppTextStyles.label.copyWith(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? AppColors.onPrimary : _textSecondary,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Small icon button ─────────────────────────────────────────────────────────
class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _SmallBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _outline),
          ),
          child: Icon(icon, size: 19, color: _textPrimary),
        ),
      ),
    );
  }
}

// ── Customer name (async resolve) ─────────────────────────────────────────────
class _CustomerNameWidget extends StatelessWidget {
  final BookingModel booking;
  final TextStyle style;
  const _CustomerNameWidget({required this.booking, required this.style});

  @override
  Widget build(BuildContext context) {
    if (booking.customerName.isNotEmpty) {
      return Text(booking.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    return FutureBuilder<String>(
      future: AuthService().fetchUser(booking.customerId).then((u) =>
          u?.name.isNotEmpty == true ? u!.name : 'Customer'),
      builder: (_, snap) => Text(
        snap.data ?? (booking.customerName.isNotEmpty ? booking.customerName : 'Customer'),
        maxLines: 1, overflow: TextOverflow.ellipsis, style: style,
      ),
    );
  }
}

// ── Dialogs ───────────────────────────────────────────────────────────────────
void _showScreenshotDialog(BuildContext context, BookingModel b) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Deposit Screenshot',
                style: AppTextStyles.titleLarge.copyWith(color: _textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('PKR ${b.depositAmount.toStringAsFixed(0)}',
                style: AppTextStyles.headlineMedium.copyWith(
                    color: _green, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            if (b.depositScreenshot?.startsWith('http') == true)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(b.depositScreenshot!, height: 300, width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 100,
                        child: Center(child: Icon(Icons.broken_image, color: _textSecondary)))),
              )
            else
              Container(
                height: 140, width: double.infinity,
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _outline)),
                child: const Center(child: Icon(Icons.receipt_long, size: 48, color: _textSecondary)),
              ),
            const SizedBox(height: 16),
            TextButton(onPressed: Get.back,
                child: Text('Close', style: AppTextStyles.button.copyWith(color: _secondary))),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showApproveDialog(
    BuildContext context, BookingModel b, OwnerBookingController c,
    Future<String> Function(BookingModel) resolveName) async {
  final name = await resolveName(b);
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (_) => _ConfirmDialog(
      icon: Icons.check_circle_outline, iconColor: _green,
      title: 'Approve Booking?',
      subtitle: 'Confirm $name\'s booking at ${b.arenaName}.\nThey will be notified immediately.',
      confirmLabel: 'Approve', confirmColor: _green,
      onConfirm: () async {
        Get.back();
        await c.approve(b.id);
        Get.snackbar('Approved!', '$name\'s booking confirmed.',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: _green, colorText: Colors.white,
            margin: const EdgeInsets.all(16));
      },
    ),
  );
}

Future<void> _showRejectDialog(
    BuildContext context, BookingModel b, OwnerBookingController c,
    Future<String> Function(BookingModel) resolveName) async {
  final name = await resolveName(b);
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (_) => _ConfirmDialog(
      icon: Icons.cancel_outlined, iconColor: _red,
      title: 'Reject Booking?',
      subtitle: 'Reject $name\'s booking at ${b.arenaName}.\nYou\'ll need to refund the deposit manually.',
      confirmLabel: 'Reject', confirmColor: _red,
      onConfirm: () {
        Get.back();
        c.reject(b.id);
        Get.snackbar('Rejected', '$name\'s booking has been rejected.',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: _red, colorText: Colors.white,
            margin: const EdgeInsets.all(16));
      },
    ),
  );
}

Future<void> _showApproveSeriesDialog(
    BuildContext context, BookingModel b, OwnerBookingController c,
    Future<String> Function(BookingModel) resolveName) async {
  final name = await resolveName(b);
  final total = b.recurringTotal ?? 1;
  final seriesBookings = c.seriesFor(b.recurringGroupId!);
  final totalDeposit = seriesBookings.fold<double>(0, (s, x) => s + x.totalAmount);
  final screenshotUrl = b.depositScreenshot;
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.repeat_on_outlined, color: _green, size: 22),
              const SizedBox(width: 10),
              Text('Approve Recurring Series',
                  style: AppTextStyles.titleMedium.copyWith(color: _textPrimary)),
            ]),
            const SizedBox(height: 12),
            Text('$name · ${b.arenaName}',
                style: AppTextStyles.bodySmall.copyWith(color: _textSecondary)),
            const SizedBox(height: 4),
            Text('$total sessions · PKR ${totalDeposit.toStringAsFixed(0)} total deposit',
                style: AppTextStyles.bodySmall.copyWith(
                    color: _green, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('1 payment screenshot covers all $total sessions.',
                style: AppTextStyles.bodySmall.copyWith(
                    color: _textSecondary, fontSize: 12)),
            if (screenshotUrl != null) ...[
              const SizedBox(height: 16),
              Text('Deposit Screenshot',
                  style: AppTextStyles.caption.copyWith(color: _textSecondary)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  screenshotUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Screenshot unavailable',
                        style: AppTextStyles.caption.copyWith(color: _textSecondary)),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _amber.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_outlined, color: _amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('No payment screenshot attached.',
                      style: AppTextStyles.caption.copyWith(color: _amber))),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: Get.back,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _outline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Cancel',
                      style: AppTextStyles.label.copyWith(color: _textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Get.back();
                    await c.approveSeries(b.recurringGroupId!);
                    Get.snackbar('All Sessions Approved!',
                        '$total sessions confirmed for $name.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: _green,
                        colorText: Colors.white,
                        margin: const EdgeInsets.all(16));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Approve All',
                      style: AppTextStyles.label.copyWith(color: Colors.white)),
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showRejectSeriesDialog(
    BuildContext context, BookingModel b, OwnerBookingController c,
    Future<String> Function(BookingModel) resolveName) async {
  final name = await resolveName(b);
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (_) => _ConfirmDialog(
      icon: Icons.cancel_outlined, iconColor: _red,
      title: 'Reject All Sessions?',
      subtitle: 'Reject all pending sessions in this recurring series for $name.\nYou\'ll need to refund the deposit manually.',
      confirmLabel: 'Reject All', confirmColor: _red,
      onConfirm: () {
        Get.back();
        c.rejectSeries(b.recurringGroupId!);
        Get.snackbar('Series Rejected', 'All pending sessions for $name have been rejected.',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: _red, colorText: Colors.white,
            margin: const EdgeInsets.all(16));
      },
    ),
  );
}

class _ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.icon, required this.iconColor, required this.title, required this.subtitle,
    required this.confirmLabel, required this.confirmColor, required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 34),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: AppTextStyles.titleLarge.copyWith(
                    color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: _textSecondary, fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: Get.back,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: _textSecondary,
                        side: const BorderSide(color: _outline),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Cancel', style: AppTextStyles.button.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(confirmLabel, style: AppTextStyles.button.copyWith(fontWeight: FontWeight.w800)),
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
