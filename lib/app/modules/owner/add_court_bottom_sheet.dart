import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/court_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class AddCourtBottomSheet extends StatefulWidget {
  final void Function(CourtModel court) onAdd;

  /// When set, the sheet opens in edit mode prefilled with this court.
  final CourtModel? initial;

  const AddCourtBottomSheet({super.key, required this.onAdd, this.initial});

  static Future<void> show(
    BuildContext context, {
    required void Function(CourtModel) onAdd,
    CourtModel? initial,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddCourtBottomSheet(onAdd: onAdd, initial: initial),
    );
  }

  @override
  State<AddCourtBottomSheet> createState() => _AddCourtBottomSheetState();
}

class _AddCourtBottomSheetState extends State<AddCourtBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '10');
  final _priceCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController(text: '14');

  CourtType _type = CourtType.football;
  CourtSurface _surface = CourtSurface.artificial;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 0);
  final Set<CourtAmenity> _amenities = {};

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final court = widget.initial;
    if (court != null) {
      _nameCtrl.text = court.name;
      _descCtrl.text = court.description;
      _capacityCtrl.text = court.capacity.toString();
      _priceCtrl.text = court.pricePerHour.toStringAsFixed(0);
      _advanceCtrl.text = court.advanceBookingDays.toString();
      _type = court.type;
      _surface = court.surface;
      _startTime = _parseTime(court.startTime, const TimeOfDay(hour: 8, minute: 0));
      _endTime = _parseTime(court.endTime, const TimeOfDay(hour: 23, minute: 0));
      _amenities.addAll(court.amenities);
      if (court.hasFloodlights) _amenities.add(CourtAmenity.floodlights);
    }
  }

  TimeOfDay _parseTime(String hhmm, TimeOfDay fallback) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h % 24, minute: m % 60);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onAdd(
      CourtModel(
        id: widget.initial?.id ??
            'court-${DateTime.now().millisecondsSinceEpoch}',
        arenaId: widget.initial?.arenaId ?? '',
        images: widget.initial?.images ?? const [],
        isActive: widget.initial?.isActive ?? true,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        type: _type,
        surface: _surface,
        capacity: int.tryParse(_capacityCtrl.text) ?? 10,
        pricePerHour: double.tryParse(_priceCtrl.text) ?? 0,
        startTime: _fmt(_startTime),
        endTime: _fmt(_endTime),
        advanceBookingDays: int.tryParse(_advanceCtrl.text) ?? 14,
        hasFloodlights: _amenities.contains(CourtAmenity.floodlights),
        amenities: _amenities.toList(),
      ),
    );
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textGrey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(_isEdit ? 'Edit Court' : 'Add Court',
                  style: AppTextStyles.headlineMedium),
              const SizedBox(height: 20),

              // ── Court Type ──────────────────────────────────────────────
              Text('Court Type', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CourtType.values.map((t) {
                  final sel = _type == t;
                  return ChoiceChip(
                    label: Text(t.label),
                    selected: sel,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: sel ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _type = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Surface ─────────────────────────────────────────────────
              Text('Surface', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CourtSurface.values.map((s) {
                  final sel = _surface == s;
                  return ChoiceChip(
                    label: Text(s.label),
                    selected: sel,
                    selectedColor: AppColors.accent,
                    labelStyle: TextStyle(
                      color: sel ? Colors.black : null,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _surface = s),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Basic Info ───────────────────────────────────────────────
              AppTextField(
                label: 'Court Name',
                hint: 'e.g. Padel Court A',
                controller: _nameCtrl,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Court name is required'
                    : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Description (optional)',
                hint: 'e.g. Professional-grade turf, suitable for 5-a-side',
                controller: _descCtrl,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Capacity (players)',
                      hint: '10',
                      controller: _capacityCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Invalid',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      label: 'Price / hour (PKR)',
                      hint: '3000',
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (double.tryParse(v ?? '') ?? 0) > 0
                              ? null
                              : 'Invalid',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Operating Hours ──────────────────────────────────────────
              Text('Operating Hours', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _timeButton('Opens', _startTime, true)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 16),
                  ),
                  Expanded(child: _timeButton('Closes', _endTime, false)),
                ],
              ),
              const SizedBox(height: 16),

              // ── Advance Booking ──────────────────────────────────────────
              AppTextField(
                label: 'Advance booking (days)',
                hint: '14',
                controller: _advanceCtrl,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? -1) >= 0 ? null : 'Invalid',
              ),
              const SizedBox(height: 20),

              // ── Amenities ────────────────────────────────────────────────
              Text('Amenities', style: AppTextStyles.label),
              const SizedBox(height: 4),
              Text(
                'Select all that apply',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textGrey),
              ),
              const SizedBox(height: 12),
              _AmenitiesGrid(
                selected: _amenities,
                onToggle: (a) => setState(() => _amenities.contains(a)
                    ? _amenities.remove(a)
                    : _amenities.add(a)),
              ),
              const SizedBox(height: 28),

              AppButton(
                  label: _isEdit ? 'Save Changes' : 'Add Court',
                  onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeButton(String label, TimeOfDay time, bool isStart) {
    return OutlinedButton(
      onPressed: () => _pickTime(isStart),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: AppColors.textGrey.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey)),
          Text(_fmt(time), style: AppTextStyles.titleMedium),
        ],
      ),
    );
  }
}

class _AmenitiesGrid extends StatelessWidget {
  final Set<CourtAmenity> selected;
  final void Function(CourtAmenity) onToggle;

  const _AmenitiesGrid({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CourtAmenity.values.map((a) {
        final sel = selected.contains(a);
        return GestureDetector(
          onTap: () => onToggle(a),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.textGrey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel
                    ? AppColors.primary
                    : AppColors.textGrey.withValues(alpha: 0.25),
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  a.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: sel ? AppColors.primary : AppColors.textGrey,
                    fontWeight:
                        sel ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                if (sel) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check_circle,
                      size: 14, color: AppColors.primary),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
