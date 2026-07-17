import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models/arena_model.dart';
import '../../data/models/booking_model.dart';
import '../../services/arena_service.dart';
import '../../widgets/slot_picker_widgets.dart';
import 'my_bookings_tab.dart' show openBookingChatAndGo;
import 'rate_booking_sheet.dart';

const _red = Color(0xFFFF5252);

/// Customer booking detail screen — full booking info plus a QR code the
/// owner scans to activate (check-in) the booking at the arena.
class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  ArenaModel? _arena;
  bool _loadingArena = true;

  @override
  void initState() {
    super.initState();
    final b = Get.arguments as BookingModel;
    ArenaService().fetchArena(b.arenaId).then((a) {
      if (!mounted) return;
      setState(() {
        _arena = a;
        _loadingArena = false;
      });
    });
  }

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed:
      case BookingStatus.completed:
      case BookingStatus.refundConfirmed:
        return SlotPickerColors.green;
      case BookingStatus.rejected:
      case BookingStatus.cancelled:
        return _red;
      case BookingStatus.refundPending:
      case BookingStatus.refundSent:
        return SlotPickerColors.pending;
      default:
        return SlotPickerColors.pending;
    }
  }

  IconData _statusIcon(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed:
        return Icons.verified_outlined;
      case BookingStatus.completed:
        return Icons.done_all;
      case BookingStatus.rejected:
      case BookingStatus.cancelled:
        return Icons.cancel_outlined;
      case BookingStatus.refundPending:
      case BookingStatus.refundSent:
      case BookingStatus.refundConfirmed:
        return Icons.currency_exchange;
      default:
        return Icons.pending_outlined;
    }
  }

  String _fmtDateTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $h:$m';
  }

  Color _activeStatusColor(BookingModel b) {
    if (b.isActive) return const Color(0xFF00DBE9);
    return _statusColor(b.status);
  }

  IconData _activeStatusIcon(BookingModel b) {
    if (b.isActive) return Icons.sports_outlined;
    return _statusIcon(b.status);
  }

  @override
  Widget build(BuildContext context) {
    final b = Get.arguments as BookingModel;
    final sColor = _activeStatusColor(b);
    final hasLocation =
        _arena != null && (_arena!.location.lat != 0 || _arena!.location.lng != 0);
    final sessionExpired = b.endDateTime.isBefore(DateTime.now());

    // Show directions for confirmed+ (not just pending/rejected)
    final showDirections = b.status == BookingStatus.confirmed ||
        b.isActive ||
        b.status == BookingStatus.completed;

    return Scaffold(
      backgroundColor: SlotPickerColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(booking: b),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _HeroCard(booking: b, statusColor: sColor, statusIcon: _activeStatusIcon(b)),
                  const SizedBox(height: 14),
                  if (b.checkedIn)
                    _CheckedInSection(booking: b)
                  else if (b.status == BookingStatus.confirmed && !sessionExpired)
                    _QrSection(booking: b)
                  else if (b.status == BookingStatus.confirmed && sessionExpired)
                    const _SessionExpiredSection()
                  else
                    _QrPendingSection(),
                  const SizedBox(height: 14),
                  IntrinsicHeight(
                    child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _InfoChipTile(
                          icon: Icons.calendar_month_outlined,
                          label: 'DATE & TIME',
                          value:
                              '${b.date.day} ${_months[b.date.month - 1]} ${b.date.year}',
                          sub: b.timeRange,
                          subColor: SlotPickerColors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoChipTile(
                          icon: Icons.location_on_outlined,
                          label: 'LOCATION',
                          value: b.courtName,
                          sub: _loadingArena
                              ? 'Loading…'
                              : (_arena?.location.address.isNotEmpty == true
                                  ? _arena!.location.address
                                  : b.arenaName),
                        ),
                      ),
                    ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TotalPaidTile(booking: b),
                  if (b.checkedIn && b.checkedInAt != null) ...[
                    const SizedBox(height: 12),
                    _InfoChipTile(
                      icon: Icons.login,
                      label: 'CHECKED IN AT',
                      value: _fmtDateTime(b.checkedInAt!),
                      subColor: SlotPickerColors.green,
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (showDirections)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.directions_outlined,
                              label: 'Get Directions',
                              filled: true,
                              onTap: hasLocation
                                  ? () => MapsLauncher.launchCoordinates(
                                        _arena!.location.lat,
                                        _arena!.location.lng,
                                        _arena!.name,
                                      )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (b.status == BookingStatus.completed && !b.hasReview)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.star_outline,
                              label: 'Rate this Arena',
                              filled: true,
                              fillColor: const Color(0xFFFFB59C),
                              onTap: () => RateBookingSheet.show(b),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.support_agent_outlined,
                          label: 'Message Arena Owner',
                          filled: false,
                          onTap: () => openBookingChatAndGo(b),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: SlotPickerColors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'ID: ${b.id}',
                        style: const TextStyle(
                          color: SlotPickerColors.muted,
                          fontSize: 11,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final BookingModel booking;
  const _Header({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back, color: SlotPickerColors.onBg),
          ),
          const Expanded(
            child: Text(
              'BOOKING DETAILS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SlotPickerColors.green,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
          IconButton(
            onPressed: () => openBookingChatAndGo(booking),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble_outline,
                    color: SlotPickerColors.green),
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: SlotPickerColors.greenCta,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero card ────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final BookingModel booking;
  final Color statusColor;
  final IconData statusIcon;

  const _HeroCard({
    required this.booking,
    required this.statusColor,
    required this.statusIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SlotPickerColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -16,
                left: -16,
                right: -16,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      SlotPickerColors.green,
                      SlotPickerColors.greenCta,
                    ]),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: SlotPickerColors.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sports_soccer,
                        color: SlotPickerColors.green, size: 22),
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
                          style: const TextStyle(
                            color: SlotPickerColors.onBg,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          booking.courtName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SlotPickerColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: SlotPickerColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulseDot(color: statusColor),
                        const SizedBox(width: 5),
                        Text(
                          booking.status.label.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: FadeTransition(
          opacity: Tween(begin: 0.35, end: 1.0).animate(_ac),
          child: Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: widget.color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

// ── QR sections ──────────────────────────────────────────────────────────
class _QrSection extends StatefulWidget {
  final BookingModel booking;
  const _QrSection({required this.booking});

  @override
  State<_QrSection> createState() => _QrSectionState();
}

class _QrSectionState extends State<_QrSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: SlotPickerColors.surface2.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: SlotPickerColors.green.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: SlotPickerColors.green.withValues(alpha: 0.05),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.qr_code_2, color: SlotPickerColors.green, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Your Check-In QR',
                    style: TextStyle(
                      color: SlotPickerColors.onBg,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Show this to the arena owner when you arrive',
                textAlign: TextAlign.center,
                style: TextStyle(color: SlotPickerColors.muted, fontSize: 11.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 192,
                height: 192,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: b.id,
                        version: QrVersions.auto,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    ExcludeSemantics(
                      child: RepaintBoundary(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 192,
                            height: 192,
                            child: AnimatedBuilder(
                              animation: _scan,
                              builder: (_, child) => Transform.translate(
                                offset: Offset(0, 190 * _scan.value),
                                child: child,
                              ),
                              child: Container(
                                height: 2,
                                width: 192,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    SlotPickerColors.green.withValues(alpha: 0),
                                    SlotPickerColors.green.withValues(alpha: 0.9),
                                    SlotPickerColors.green.withValues(alpha: 0),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ..._corners(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    SlotPickerColors.green,
                    SlotPickerColors.greenCta,
                  ]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${b.arenaName} · ${b.timeRange}',
                  style: const TextStyle(
                    color: Color(0xFF0A1628),
                    fontSize: 12,
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

  List<Widget> _corners() {
    const c = SlotPickerColors.green;
    const s = 16.0;
    BoxDecoration deco({bool t = false, bool b = false, bool l = false, bool r = false}) =>
        BoxDecoration(
          border: Border(
            top: t ? const BorderSide(color: c, width: 2) : BorderSide.none,
            bottom: b ? const BorderSide(color: c, width: 2) : BorderSide.none,
            left: l ? const BorderSide(color: c, width: 2) : BorderSide.none,
            right: r ? const BorderSide(color: c, width: 2) : BorderSide.none,
          ),
        );
    return [
      Positioned(top: 0, left: 0, child: Container(width: s, height: s, decoration: deco(t: true, l: true))),
      Positioned(top: 0, right: 0, child: Container(width: s, height: s, decoration: deco(t: true, r: true))),
      Positioned(bottom: 0, left: 0, child: Container(width: s, height: s, decoration: deco(b: true, l: true))),
      Positioned(bottom: 0, right: 0, child: Container(width: s, height: s, decoration: deco(b: true, r: true))),
    ];
  }
}

class _CheckedInSection extends StatelessWidget {
  final BookingModel booking;
  const _CheckedInSection({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SlotPickerColors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SlotPickerColors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: SlotPickerColors.green, size: 52),
          const SizedBox(height: 12),
          const Text(
            "You're Checked In!",
            style: TextStyle(
              color: SlotPickerColors.green,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enjoy your session at ${booking.arenaName}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: SlotPickerColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _QrPendingSection extends StatelessWidget {
  const _QrPendingSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SlotPickerColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_empty_rounded,
              color: SlotPickerColors.pending, size: 44),
          const SizedBox(height: 12),
          const Text(
            'QR Available After Confirmation',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SlotPickerColors.onBg,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your check-in QR code will appear once the owner confirms your booking.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SlotPickerColors.muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _SessionExpiredSection extends StatelessWidget {
  const _SessionExpiredSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB4AB).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB4AB).withValues(alpha: 0.2)),
      ),
      child: const Column(
        children: [
          Icon(Icons.schedule_outlined, color: Color(0xFFFFB4AB), size: 44),
          SizedBox(height: 12),
          Text(
            'Session Time Passed',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFFB4AB),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'The session time has passed. This booking will be marked completed shortly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SlotPickerColors.muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

// ── Info tiles ───────────────────────────────────────────────────────────
class _InfoChipTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;

  const _InfoChipTile({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.subColor,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: SlotPickerColors.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: SlotPickerColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SlotPickerColors.onBg,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 1),
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: subColor ?? SlotPickerColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalPaidTile extends StatelessWidget {
  final BookingModel booking;
  const _TotalPaidTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SlotPickerColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.payments_outlined,
                      size: 14, color: SlotPickerColors.muted),
                  SizedBox(width: 6),
                  Text(
                    'TOTAL AMOUNT',
                    style: TextStyle(
                      color: SlotPickerColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                'PKR ${booking.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: SlotPickerColors.green,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
                height: 1, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Deposit Paid',
                  style: TextStyle(color: SlotPickerColors.muted, fontSize: 12.5)),
              Text('PKR ${booking.depositAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: SlotPickerColors.onBg,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Remaining at Venue',
                  style: TextStyle(color: SlotPickerColors.muted, fontSize: 12.5)),
              Text('PKR ${booking.remainingAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: SlotPickerColors.onBg,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Action buttons ───────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final Color? fillColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final activeFill = fillColor ?? SlotPickerColors.greenCta;
    final iconTextColor = fillColor != null ? Colors.black87 : const Color(0xFF0A1628);
    return Material(
      color: filled
          ? (disabled ? SlotPickerColors.surface : activeFill)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: filled
                ? null
                : Border.all(
                    color: disabled
                        ? Colors.white.withValues(alpha: 0.08)
                        : SlotPickerColors.green,
                  ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: filled
                    ? (disabled ? SlotPickerColors.muted : iconTextColor)
                    : (disabled ? SlotPickerColors.muted : SlotPickerColors.green),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: filled
                      ? (disabled ? SlotPickerColors.muted : iconTextColor)
                      : (disabled
                          ? SlotPickerColors.muted
                          : SlotPickerColors.green),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
