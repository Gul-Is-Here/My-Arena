import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/owner_booking_controller.dart';
import '../../controllers/owner_controller.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/court_model.dart';
import '../../services/booking_service.dart';
import '../../utils/slot_status.dart';
import '../../widgets/slot_picker_widgets.dart';

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

  late final List<ArenaModel> arenas = OwnerController.to.myArenas;
  late ArenaModel _arena = arenas.first;
  CourtModel? _court;
  DateTime _date = DateTime.now();
  int _duration = 1;
  final Set<int> _selectedHours = {};

  List<BookingModel> _bookedSlots = [];
  bool _loadingSlots = false;
  bool _submitting = false;

  List<CourtModel> get _activeCourts =>
      _arena.courts.where((c) => c.isActive).toList();

  @override
  void initState() {
    super.initState();
    _court = _activeCourts.isNotEmpty ? _activeCourts.first : null;
    _loadBookedSlots();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBookedSlots() async {
    final court = _court;
    if (court == null) {
      setState(() => _bookedSlots = []);
      return;
    }
    setState(() => _loadingSlots = true);
    try {
      final slots = await _bookingService.bookedSlots(court.id, _date);
      if (!mounted) return;
      setState(() => _bookedSlots = slots);
    } catch (_) {
      if (!mounted) return;
      setState(() => _bookedSlots = []);
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
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
      await OwnerBookingController.to.addManualBooking(
        BookingModel(
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
        ),
      );
      Get.back();
      Get.snackbar(
        'Walk-in booked',
        '${court.name} · ${_fmtDate(_date)} · ${fmtHour12(startHour)}',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
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
                            color: Color(0xFFEF4444),
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
                        color: SlotPickerColors.green,
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
                                    : const Color(0xFF0A1628),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: (_court == null || _selectedHours.isEmpty)
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
          color: selected ? SlotPickerColors.green : SlotPickerColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? SlotPickerColors.green
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF0A1628) : SlotPickerColors.onBg,
          ),
        ),
      ),
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
              borderSide: const BorderSide(color: SlotPickerColors.green),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }
}
