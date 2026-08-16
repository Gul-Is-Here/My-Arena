import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/owner_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../data/models/arena_model.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/court_model.dart';
import '../../../data/models/pos_product_model.dart';
import '../../../data/models/pos_transaction_model.dart';
import '../../../services/blocked_slot_service.dart';
import '../../../services/booking_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/slot_status.dart';
import '../../../widgets/slot_picker_widgets.dart';
import '../pos_receipt_screen.dart';

final _pkr = NumberFormat('#,##0');

class PosWalkInScreen extends StatefulWidget {
  const PosWalkInScreen({super.key});

  @override
  State<PosWalkInScreen> createState() => _PosWalkInScreenState();
}

class _PosWalkInScreenState extends State<PosWalkInScreen> {
  // ── Step management ───────────────────────────────────────────────────
  int _step = 0; // 0=Court 1=Time 2=Customer 3=AddOns 4=Payment

  // ── Court/Arena ───────────────────────────────────────────────────────
  late List<ArenaModel> _arenas;
  late ArenaModel _arena;
  CourtModel? _court;

  // ── Slot ──────────────────────────────────────────────────────────────
  DateTime _date = DateTime.now();
  final Set<int> _selectedHours = {};
  int _duration = 1;
  List<BookingModel> _bookedSlots = [];
  Set<int> _blockedHours = {};
  Set<int> _lockedHours = {};
  StreamSubscription<Set<int>>? _slotLocksSub;
  bool _loadingSlots = false;

  // ── Customer ──────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // ── Add-ons ───────────────────────────────────────────────────────────
  final Map<PosProductModel, int> _addOns = {};

  // ── Payment ───────────────────────────────────────────────────────────
  PosPaymentMethod _paymentMethod = PosPaymentMethod.cash;
  final _amountPaidCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _refNoCtrl = TextEditingController();
  bool _fullPayment = true;

  // ── State ─────────────────────────────────────────────────────────────
  bool _submitting = false;
  final _bookingService = BookingService();
  final _blockedService = BlockedSlotService();

  void _onTextChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<OwnerController>()) Get.put(OwnerController());
    if (!Get.isRegistered<PosController>()) Get.put(PosController(), permanent: true);

    _nameCtrl.addListener(_onTextChanged);
    _phoneCtrl.addListener(_onTextChanged);

    _arenas = OwnerController.to.myArenas;
    // Pre-select from POS context or first arena
    final posArena = PosController.to.selectedArena.value;
    _arena = posArena ?? (_arenas.isNotEmpty ? _arenas.first : ArenaModel.empty());

    // Pre-select court if passed from live court screen
    final args = Get.arguments as Map<String, dynamic>?;
    final preCourtId = args?['courtId'] as String?;
    if (preCourtId != null) {
      _court = _activeCourts.firstWhereOrNull((c) => c.id == preCourtId);
    }
    _court ??= _activeCourts.isNotEmpty ? _activeCourts.first : null;

    _loadBookedSlots();
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onTextChanged);
    _phoneCtrl.removeListener(_onTextChanged);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _amountPaidCtrl.dispose();
    _discountCtrl.dispose();
    _refNoCtrl.dispose();
    _slotLocksSub?.cancel();
    super.dispose();
  }

  List<CourtModel> get _activeCourts =>
      _arena.courts.where((c) => c.isActive).toList();

  void _loadBookedSlots() {
    final court = _court;
    if (court == null) return;
    setState(() => _loadingSlots = true);
    _slotLocksSub?.cancel();
    _slotLocksSub = _bookingService
        .bookedHoursStream(court.id, _date)
        .listen((hours) {
      if (!mounted) return;
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

  int? get _startHour => _selectedHours.isEmpty ? null : _selectedHours.reduce((a, b) => a < b ? a : b);

  double get _courtTotal {
    final c = _court;
    if (c == null || _selectedHours.isEmpty) return 0;
    double total = 0;
    for (final h in _selectedHours) {
      total += c.priceAt(h);
    }
    return total;
  }

  double get _addOnsTotal => _addOns.entries.fold(0.0, (sum, e) => sum + e.key.price * e.value);

  double get _discount {
    if (_discountCtrl.text.isEmpty) return 0;
    return double.tryParse(_discountCtrl.text) ?? 0;
  }

  double get _grandTotal => (_courtTotal + _addOnsTotal - _discount).clamp(0, double.infinity);

  double get _amountPaid {
    if (_fullPayment) return _grandTotal;
    return double.tryParse(_amountPaidCtrl.text) ?? 0;
  }

  // ── Validation ────────────────────────────────────────────────────────

  bool get _courtValid => _court != null;
  bool get _timeValid => _selectedHours.length == _duration;
  bool get _customerValid => _nameCtrl.text.trim().isNotEmpty;
  bool get _paymentValid => _amountPaid >= 0 && _amountPaid <= _grandTotal;

  // ── Submit ────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting) return;
    final court = _court;
    final startHr = _startHour;
    if (court == null || startHr == null) return;

    setState(() => _submitting = true);
    try {
      final user = AuthController.to.currentUser.value;
      final uid = user?.uid ?? '';
      final userName = user?.name ?? 'Owner';

      final booking = BookingModel(
        id: '',
        arenaId: _arena.id,
        arenaName: _arena.name,
        courtId: court.id,
        courtName: court.name,
        customerName: _nameCtrl.text.trim(),
        customerId: '',
        ownerId: uid,
        bookedByRole: 'owner',
        date: _date,
        startHour: startHr,
        totalHours: _duration,
        pricePerHour: court.pricePerHour,
        status: BookingStatus.confirmed,
        createdAt: DateTime.now(),
        posPaymentMethod: _paymentMethod.key,
        isPosBooking: true,
        amountPaid: _amountPaid,
        posDiscount: _discount,
        posAddOnIds: _addOns.keys.map((p) => p.id).toList(),
        posAddOnsTotal: _addOnsTotal,
        totalAmountStored: _courtTotal,
      );

      final bookingId = await _bookingService.createManualBooking(booking);

      // Record POS transaction
      final txn = PosTransactionModel(
        id: '',
        arenaId: _arena.id,
        arenaName: _arena.name,
        bookingId: bookingId,
        courtId: court.id,
        courtName: court.name,
        customerName: _nameCtrl.text.trim(),
        type: PosTransactionType.booking,
        paymentMethod: _paymentMethod,
        totalAmount: _grandTotal,
        amountPaid: _amountPaid,
        remainingAmount: _grandTotal - _amountPaid,
        discount: _discount,
        refNo: _refNoCtrl.text.trim().isEmpty ? null : _refNoCtrl.text.trim(),
        processedById: uid,
        processedByName: userName,
        processedByRole: user?.role.name ?? 'owner',
        createdAt: DateTime.now(),
        shiftId: PosController.to.openShift.value?.id,
      );

      await PosController.to.recordTransaction(txn);

      // Show receipt
      await Get.to(() => PosReceiptScreen(
            booking: booking.copyWith(),
            arenaName: _arena.name,
            courtName: court.name,
            date: _date,
            startHour: startHr,
            totalHours: _duration,
            total: _grandTotal,
            paymentMethod: _paymentMethod.key,
            customerPhone: _phoneCtrl.text.trim(),
            amountPaid: _amountPaid,
            remainingAmount: _grandTotal - _amountPaid,
            discount: _discount,
            addOns: _addOns,
          ));

      Get.back(); // back to POS dashboard
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('New Walk-in'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _StepIndicator(current: _step),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildStep()),
          _BottomBar(),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _CourtStep(
          arenas: _arenas,
          selectedArena: _arena,
          selectedCourt: _court,
          onArenaChanged: (a) {
            setState(() {
              _arena = a;
              _court = _activeCourts.isNotEmpty ? _activeCourts.first : null;
              _selectedHours.clear();
            });
            _loadBookedSlots();
          },
          onCourtChanged: (c) {
            setState(() {
              _court = c;
              _selectedHours.clear();
            });
            _loadBookedSlots();
          },
        );
      case 1:
        return _TimeStep(
          court: _court,
          date: _date,
          duration: _duration,
          selectedHours: _selectedHours,
          hourOptions: _hourOptions,
          loadingSlots: _loadingSlots,
          statusFor: _statusFor,
          onDateChanged: (d) {
            setState(() {
              _date = d;
              _selectedHours.clear();
            });
            _loadBookedSlots();
          },
          onDurationChanged: (d) => setState(() {
            _duration = d;
            _selectedHours.clear();
          }),
          onSlotToggle: (h) => setState(() {
            if (_selectedHours.contains(h)) {
              _selectedHours.remove(h);
            } else if (_selectedHours.length < _duration) {
              // Only allow consecutive slots
              if (_selectedHours.isEmpty || _isConsecutive(h)) {
                _selectedHours.add(h);
              }
            }
          }),
        );
      case 2:
        return _CustomerStep(nameCtrl: _nameCtrl, phoneCtrl: _phoneCtrl);
      case 3:
        return _AddOnsStep(
          products: PosController.to.products,
          addOns: _addOns,
          onChanged: (product, qty) => setState(() {
            if (qty <= 0) {
              _addOns.remove(product);
            } else {
              _addOns[product] = qty;
            }
          }),
        );
      case 4:
        return _PaymentStep(
          grandTotal: _grandTotal,
          courtTotal: _courtTotal,
          addOnsTotal: _addOnsTotal,
          discount: _discount,
          paymentMethod: _paymentMethod,
          fullPayment: _fullPayment,
          amountPaidCtrl: _amountPaidCtrl,
          discountCtrl: _discountCtrl,
          refNoCtrl: _refNoCtrl,
          onMethodChanged: (m) => setState(() => _paymentMethod = m),
          onFullPaymentChanged: (v) => setState(() {
            _fullPayment = v;
            if (v) _amountPaidCtrl.clear();
          }),
          onChanged: () => setState(() {}),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  bool _isConsecutive(int h) {
    if (_selectedHours.isEmpty) return true;
    final sorted = _selectedHours.toList()..sort();
    return h == sorted.first - 1 || h == sorted.last + 1;
  }

  Widget _BottomBar() {
    final canNext = switch (_step) {
      0 => _courtValid,
      1 => _timeValid,
      2 => _customerValid,
      3 => true,
      4 => _paymentValid,
      _ => false,
    };

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: canNext
                  ? () {
                      if (_step < 4) {
                        setState(() => _step++);
                      } else {
                        _submit();
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                disabledBackgroundColor: AppColors.border,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : Text(_step == 4 ? 'Confirm & Pay' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step Indicator ────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    final labels = ['Court', 'Time', 'Customer', 'Add-ons', 'Payment'];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: i ~/ 2 < current ? AppColors.primary : AppColors.border,
              ),
            );
          }
          final idx = i ~/ 2;
          final done = idx < current;
          final active = idx == current;
          return Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.primary
                      : active
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.border,
                  shape: BoxShape.circle,
                ),
                child: done
                    ? const Icon(Icons.check, color: AppColors.onPrimary, size: 14)
                    : Center(
                        child: Text('${idx + 1}',
                            style: TextStyle(
                              color: active ? AppColors.primary : AppColors.textDisabled,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
              ),
              const SizedBox(height: 2),
              Text(labels[idx],
                  style: AppTextStyles.caption.copyWith(
                    color: active ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  )),
            ],
          );
        }),
      ),
    );
  }
}

// ── Step 0: Court ─────────────────────────────────────────────────────────

class _CourtStep extends StatelessWidget {
  final List<ArenaModel> arenas;
  final ArenaModel selectedArena;
  final CourtModel? selectedCourt;
  final ValueChanged<ArenaModel> onArenaChanged;
  final ValueChanged<CourtModel> onCourtChanged;

  const _CourtStep({
    required this.arenas,
    required this.selectedArena,
    required this.selectedCourt,
    required this.onArenaChanged,
    required this.onCourtChanged,
  });

  @override
  Widget build(BuildContext context) {
    final courts = selectedArena.courts.where((c) => c.isActive).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (arenas.length > 1) ...[
          Text('Arena', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButton<ArenaModel>(
              value: selectedArena,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: AppColors.elevated,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
              items: arenas
                  .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                  .toList(),
              onChanged: (a) { if (a != null) onArenaChanged(a); },
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('Select Court', style: AppTextStyles.titleMedium.copyWith(
          color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (courts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('No active courts', style: TextStyle(color: AppColors.textSecondary)),
            ),
          )
        else
          ...courts.map((c) => _CourtTile(
                court: c,
                selected: selectedCourt?.id == c.id,
                onTap: () => onCourtChanged(c),
              )),
      ],
    );
  }
}

class _CourtTile extends StatelessWidget {
  final CourtModel court;
  final bool selected;
  final VoidCallback onTap;
  const _CourtTile({required this.court, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.elevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.sports_outlined,
                  color: selected ? AppColors.primary : AppColors.textSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(court.name, style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                  Text(
                    '${court.type.label} · PKR ${_pkr.format(court.pricePerHour)}/hr',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── Step 1: Time ──────────────────────────────────────────────────────────

class _TimeStep extends StatelessWidget {
  final CourtModel? court;
  final DateTime date;
  final int duration;
  final Set<int> selectedHours;
  final List<int> hourOptions;
  final bool loadingSlots;
  final SlotStatus Function(int) statusFor;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<int> onSlotToggle;

  const _TimeStep({
    required this.court,
    required this.date,
    required this.duration,
    required this.selectedHours,
    required this.hourOptions,
    required this.loadingSlots,
    required this.statusFor,
    required this.onDateChanged,
    required this.onDurationChanged,
    required this.onSlotToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Date picker
        Text('Date', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 60)),
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(primary: AppColors.primary),
                ),
                child: child!,
              ),
            );
            if (picked != null) onDateChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Text(DateFormat('EEE, d MMM yyyy').format(date),
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Duration
        Text('Duration', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [1, 2, 3, 4, 5, 6].map((h) {
            final sel = duration == h;
            return Expanded(
              child: GestureDetector(
                onTap: () => onDurationChanged(h),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? AppColors.primary : AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text('$h', style: AppTextStyles.bodyMedium.copyWith(
                        color: sel ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      )),
                      Text('hr${h > 1 ? 's' : ''}', style: AppTextStyles.caption.copyWith(
                        color: sel ? AppColors.primary : AppColors.textSecondary,
                        fontSize: 10,
                      )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Slot grid
        Row(
          children: [
            Text('Select ${duration > 1 ? '$duration consecutive ' : ''}slot',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const Spacer(),
            Text('${selectedHours.length}/$duration selected',
                style: AppTextStyles.caption.copyWith(
                  color: selectedHours.length == duration ? AppColors.primary : AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        if (loadingSlots)
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hourOptions.map((h) {
              final status = statusFor(h);
              final selected = selectedHours.contains(h);
              final available = status == SlotStatus.available;
              Color bg, border, fg;
              if (selected) {
                bg = AppColors.primary;
                border = AppColors.primary;
                fg = AppColors.onPrimary;
              } else if (!available) {
                bg = AppColors.elevated;
                border = AppColors.border;
                fg = AppColors.textDisabled;
              } else {
                bg = AppColors.surface;
                border = AppColors.border;
                fg = AppColors.textPrimary;
              }
              return GestureDetector(
                onTap: available ? () => onSlotToggle(h) : null,
                child: Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: [
                      Text(fmtHour12(h),
                          style: AppTextStyles.caption.copyWith(
                              color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
                      if (!available)
                        Text(status == SlotStatus.booked ? 'Booked' : 'Closed',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textDisabled, fontSize: 9)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ── Step 2: Customer ──────────────────────────────────────────────────────

class _CustomerStep extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  const _CustomerStep({required this.nameCtrl, required this.phoneCtrl});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Customer', style: AppTextStyles.titleMedium.copyWith(
          color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Enter walk-in customer details',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        _field('Name *', 'Customer name', nameCtrl, TextInputType.name),
        const SizedBox(height: 14),
        _field('Phone', 'Phone number (optional)', phoneCtrl, TextInputType.phone),
      ],
    );
  }

  Widget _field(String label, String hint, TextEditingController ctrl, TextInputType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: type,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDisabled),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Step 3: Add-ons ───────────────────────────────────────────────────────

class _AddOnsStep extends StatelessWidget {
  final RxList<PosProductModel> products;
  final Map<PosProductModel, int> addOns;
  final Function(PosProductModel, int) onChanged;

  const _AddOnsStep({
    required this.products,
    required this.addOns,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (products.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_shopping_cart, color: AppColors.textDisabled, size: 48),
                const SizedBox(height: 12),
                Text('No add-ons configured',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                Text('Add products in POS settings',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textDisabled)),
              ],
            ),
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Add-ons & Services', style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Optional — skip if not needed',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ...products.map((p) {
            final qty = addOns[p] ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: qty > 0 ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: qty > 0 ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        Text(p.category.label, style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary)),
                        Text('PKR ${_pkr.format(p.price)}', style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _qtyBtn(Icons.remove, () => onChanged(p, qty - 1)),
                      SizedBox(
                        width: 36,
                        child: Text('$qty',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                      ),
                      _qtyBtn(Icons.add, () => onChanged(p, qty + 1)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      );
    });
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => Material(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 16, color: AppColors.textPrimary),
          ),
        ),
      );
}

// ── Step 4: Payment ───────────────────────────────────────────────────────

class _PaymentStep extends StatelessWidget {
  final double grandTotal, courtTotal, addOnsTotal, discount;
  final PosPaymentMethod paymentMethod;
  final bool fullPayment;
  final TextEditingController amountPaidCtrl, discountCtrl, refNoCtrl;
  final ValueChanged<PosPaymentMethod> onMethodChanged;
  final ValueChanged<bool> onFullPaymentChanged;
  final VoidCallback onChanged;

  const _PaymentStep({
    required this.grandTotal,
    required this.courtTotal,
    required this.addOnsTotal,
    required this.discount,
    required this.paymentMethod,
    required this.fullPayment,
    required this.amountPaidCtrl,
    required this.discountCtrl,
    required this.refNoCtrl,
    required this.onMethodChanged,
    required this.onFullPaymentChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Summary', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              _summaryRow('Court', courtTotal),
              if (addOnsTotal > 0) _summaryRow('Add-ons', addOnsTotal),
              if (discount > 0) _summaryRow('Discount', -discount, color: AppColors.success),
              const Divider(color: AppColors.border),
              Row(
                children: [
                  Text('Total', style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('PKR ${_pkr.format(grandTotal)}', style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Discount
        Text('Discount (PKR)', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: discountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => onChanged(),
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          decoration: _inputDeco('0', Icons.local_offer_outlined),
        ),
        const SizedBox(height: 16),

        // Payment method
        Text('Payment Method', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PosPaymentMethod.values.map((m) {
            final sel = paymentMethod == m;
            return GestureDetector(
              onTap: () => onMethodChanged(m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                ),
                child: Text(m.label, style: AppTextStyles.bodySmall.copyWith(
                  color: sel ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                )),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Reference number (for card/transfer)
        if (paymentMethod != PosPaymentMethod.cash) ...[
          Text('Reference / Auth Code (optional)',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: refNoCtrl,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: _inputDeco('Ref no.', Icons.numbers_outlined),
          ),
          const SizedBox(height: 16),
        ],

        // Full / partial payment
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Full Payment', style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        Text('Collect PKR ${_pkr.format(grandTotal)} now',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: fullPayment,
                    onChanged: onFullPaymentChanged,
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              if (!fullPayment) ...[
                const Divider(color: AppColors.border),
                Text('Amount Collected', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountPaidCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => onChanged(),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: _inputDeco('0', Icons.payments_outlined),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, double amount, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const Spacer(),
            Text(
              '${amount < 0 ? '-' : ''}PKR ${_pkr.format(amount.abs())}',
              style: AppTextStyles.bodySmall.copyWith(
                color: color ?? AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDisabled),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      );
}
