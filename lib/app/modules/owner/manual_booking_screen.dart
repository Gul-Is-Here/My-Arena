import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/owner_booking_controller.dart';
import '../../controllers/owner_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/court_model.dart';
import '../../services/blocked_slot_service.dart';
import '../../services/booking_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/slot_status.dart';
import '../../widgets/slot_picker_widgets.dart';
import 'pos_receipt_screen.dart';

/// Walk-in booking created by the owner — confirmed immediately since
/// payment is taken in person. Uses the same live slot grid as the
/// customer flow so the owner can't double-book a court by accident.
class ManualBookingScreen extends StatefulWidget {
  const ManualBookingScreen({super.key});

  @override
  State<ManualBookingScreen> createState() => _ManualBookingScreenState();
}

class _ManualBookingScreenState extends State<ManualBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bookingService = BookingService();

  String _paymentMethod = 'cash'; // cash | jazzcash | easypaisa | card

  late List<ArenaModel> arenas;
  late ArenaModel _arena;
  CourtModel? _court;
  DateTime _date = DateTime.now();
  int _duration = 1;
  final Set<int> _selectedHours = {};

  List<BookingModel> _bookedSlots = [];
  Set<int> _blockedHours = {};
  Set<int> _lockedHours = {};
  StreamSubscription<Set<int>>? _slotLocksSub;
  final _blockedService = BlockedSlotService();
  bool _loadingSlots = false;
  bool _submitting = false;

  List<CourtModel> get _activeCourts =>
      _arena.courts.where((c) => c.isActive).toList();

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<OwnerController>()) {
      Get.put(OwnerController());
    }
    arenas = OwnerController.to.myArenas;
    _arena = arenas.isNotEmpty ? arenas.first : ArenaModel.empty();
    _court = _activeCourts.isNotEmpty ? _activeCourts.first : null;
    _loadBookedSlots();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _slotLocksSub?.cancel();
    super.dispose();
  }

  void _loadBookedSlots() {
    final court = _court;
    if (court == null) {
      setState(() {
        _bookedSlots = [];
        _lockedHours = {};
      });
      return;
    }
    setState(() => _loadingSlots = true);
    _slotLocksSub?.cancel();
    _slotLocksSub = _bookingService
        .bookedHoursStream(court.id, _date)
        .listen((hours) {
      if (!mounted) return;
      // If the owner had selected a slot that just became taken, deselect it.
      final conflict = _selectedHours.any(hours.contains);
      setState(() {
        _lockedHours = hours;
        _loadingSlots = false;
        if (conflict) _selectedHours.clear();
      });
      if (conflict) {
        Get.snackbar(
          'Slot no longer available',
          'Another booking just came in for this slot.',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
        );
      }
    }, onError: (_) {
      if (mounted) setState(() => _loadingSlots = false);
    });

    // Blocked hours are owner-set and change rarely — one-shot is fine.
    _blockedService
        .blockedHours(_arena.id, court.id, _date)
        .then((blocked) {
      if (mounted) setState(() => _blockedHours = blocked);
    }).catchError((_) {});
  }

  List<int> get _hourOptions {
    final c = _court;
    if (c == null) return [];
    final start = int.parse(c.startTime.split(':').first);
    var end = int.parse(c.endTime.split(':').first);
    if (end <= start) end += 24;
    return [for (var h = start; h < end; h++) h];
  }

  SlotStatus _statusFor(int hour) => computeSlotStatus(
        date: _date,
        hour: hour,
        bookedSlots: _bookedSlots,
        blockedHours: _blockedHours,
        lockedHours: _lockedHours,
      );

  void _setDuration(int hours) {
    if (_duration == hours) return;
    setState(() {
      _duration = hours;
      _selectedHours.clear();
    });
  }

  void _selectSlot(int hour) {
    final range = [for (var i = 0; i < _duration; i++) hour + i];
    setState(() {
      if (_selectedHours.length == range.length &&
          range.every(_selectedHours.contains)) {
        _selectedHours.clear();
        return;
      }
      for (final h in range) {
        if (_statusFor(h) != SlotStatus.available) return;
      }
      _selectedHours
        ..clear()
        ..addAll(range);
    });
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  double get _total => (_court?.pricePerHour ?? 0) * _selectedHours.length;

  Future<void> _submit() async {
    final court = _court;
    if (!_formKey.currentState!.validate() ||
        court == null ||
        _selectedHours.isEmpty) {
      return;
    }
    final startHour = _selectedHours.reduce((a, b) => a < b ? a : b);
    setState(() => _submitting = true);
    try {
      final booking = BookingModel(
        id: '',
        arenaId: _arena.id,
        arenaName: _arena.name,
        courtId: court.id,
        courtName: court.name,
        customerName: _nameCtrl.text.trim(),
        bookedByRole: 'owner',
        date: DateTime(_date.year, _date.month, _date.day),
        startHour: startHour,
        totalHours: _selectedHours.length,
        pricePerHour: court.pricePerHour,
        createdAt: DateTime.now(),
        posPaymentMethod: _paymentMethod,
      );
      await OwnerBookingController.to.addManualBooking(booking);
      Get.back();
      Get.to(
        () => PosReceiptScreen(
          booking: booking.copyWith(),
          arenaName: _arena.name,
          courtName: court.name,
          date: _date,
          startHour: startHour,
          totalHours: _selectedHours.length,
          total: _total,
          paymentMethod: _paymentMethod,
          customerPhone: _phoneCtrl.text.trim(),
        ),
      );
    } catch (e) {
      setState(() => _submitting = false);
      Get.snackbar('Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (arenas.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Walk-in Booking')),
        body: const Center(
          child: Text('No arenas found. Please add an arena first.'),
        ),
      );
    }

    final court = _court;

    return Scaffold(
      backgroundColor: SlotPickerColors.bg,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────
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
                            'Walk-in Booking',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: SlotPickerColors.onBg,
                            ),
                          ),
                          Text(
                            court != null
                                ? '${_arena.name} · ${court.type.label}'
                                : _arena.name,
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
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel('ARENA'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: arenas.map((a) {
                          final sel = a.id == _arena.id;
                          return _DarkChip(
                            label: a.name,
                            selected: sel,
                            onTap: () => setState(() {
                              _arena = a;
                              final active =
                                  a.courts.where((c) => c.isActive).toList();
                              _court = active.isNotEmpty ? active.first : null;
                              _selectedHours.clear();
                              _loadBookedSlots();
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      const _SectionLabel('COURT'),
                      const SizedBox(height: 10),
                      if (_activeCourts.isEmpty)
                        const Text(
                          'This arena has no available courts',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.error,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _activeCourts.map((ct) {
                            final sel = ct.id == _court?.id;
                            return _DarkChip(
                              label: ct.name,
                              selected: sel,
                              onTap: () => setState(() {
                                _court = ct;
                                _selectedHours.clear();
                                _loadBookedSlots();
                              }),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 20),

                      if (court != null) ...[
                        const _SectionLabel('DATE'),
                        const SizedBox(height: 10),
                        SlotDateStrip(
                          selected: _date,
                          days: 30,
                          onSelect: (d) {
                            setState(() {
                              _date = d;
                              _selectedHours.clear();
                            });
                            _loadBookedSlots();
                          },
                        ),
                        const SizedBox(height: 20),

                        const _SectionLabel('SELECT DURATION'),
                        const SizedBox(height: 10),
                        DurationSelector(
                          options: const [1, 2, 3, 4],
                          selected: _duration,
                          onSelect: _setDuration,
                        ),
                        const SizedBox(height: 20),

                        const SlotLegend(),
                        const SizedBox(height: 16),

                        if (_loadingSlots)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: SlotPickerColors.greenCta,
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
                            children: _hourOptions.map((h) {
                              return SlotTile(
                                hour: h,
                                pricePerHour: court.pricePerHour,
                                status: _statusFor(h),
                                isSelected: _selectedHours.contains(h),
                                onTap: () => _selectSlot(h),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 24),
                      ],

                      const _SectionLabel('PAYMENT METHOD'),
                      const SizedBox(height: 10),
                      _PaymentMethodPicker(
                        selected: _paymentMethod,
                        onSelect: (m) => setState(() => _paymentMethod = m),
                      ),
                      const SizedBox(height: 20),

                      const _SectionLabel('CUSTOMER DETAILS'),
                      const SizedBox(height: 10),
                      _DarkField(
                        label: 'Customer Name',
                        hint: 'e.g. Ali Raza',
                        controller: _nameCtrl,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _DarkField(
                        label: 'Phone (optional)',
                        hint: '03XX-XXXXXXX',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
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
                      _selectedHours.isEmpty
                          ? 'No slots selected'
                          : '${_selectedHours.length} hr${_selectedHours.length > 1 ? 's' : ''} Total',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SlotPickerColors.muted,
                      ),
                    ),
                    Text(
                      _selectedHours.isEmpty
                          ? '—'
                          : 'PKR ${_total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: SlotPickerColors.greenCta,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: (_court == null || _selectedHours.isEmpty || _submitting)
                    ? null
                    : _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: (_court == null || _selectedHours.isEmpty)
                        ? SlotPickerColors.surface
                        : SlotPickerColors.greenCta,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: SlotPickerColors.muted,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'CONFIRM BOOKING',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: (_court == null || _selectedHours.isEmpty)
                                    ? SlotPickerColors.muted
                                    : AppColors.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: (_court == null || _selectedHours.isEmpty)
                                  ? SlotPickerColors.muted
                                  : AppColors.onPrimary,
                            ),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: SlotPickerColors.muted,
      ),
    );
  }
}

class _DarkChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DarkChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? SlotPickerColors.greenCta : SlotPickerColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? SlotPickerColors.greenCta
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onPrimary : SlotPickerColors.onBg,
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _PaymentMethodPicker({required this.selected, required this.onSelect});

  static const _methods = [
    ('cash', 'Cash', Icons.payments_outlined),
    ('jazzcash', 'JazzCash', Icons.account_balance_wallet_outlined),
    ('easypaisa', 'Easypaisa', Icons.mobile_friendly_outlined),
    ('card', 'Card', Icons.credit_card_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _methods.map((m) {
        final (key, label, icon) = m;
        final sel = selected == key;
        return GestureDetector(
          onTap: () => onSelect(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? SlotPickerColors.greenCta : SlotPickerColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel
                    ? SlotPickerColors.greenCta
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 15,
                    color: sel ? AppColors.onPrimary : SlotPickerColors.muted),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? AppColors.onPrimary : SlotPickerColors.onBg,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DarkField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;

  const _DarkField({
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: SlotPickerColors.muted),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          style: const TextStyle(color: SlotPickerColors.onBg),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: SlotPickerColors.muted.withValues(alpha: 0.6),
            ),
            filled: true,
            fillColor: SlotPickerColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: SlotPickerColors.greenCta),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}
