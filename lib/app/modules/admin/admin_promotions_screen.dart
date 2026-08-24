import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/auth_controller.dart';
import '../../data/models/promotion_model.dart';
import '../../services/promotion_service.dart';
import '../../theme/app_colors.dart';

class AdminPromotionsScreen extends StatefulWidget {
  const AdminPromotionsScreen({super.key});

  @override
  State<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends State<AdminPromotionsScreen> {
  final _service = PromotionService();
  List<PromotionModel> _promos = [];
  double _maxOwnerPct = 100.0;
  StreamSubscription? _sub;
  StreamSubscription? _capSub;

  @override
  void initState() {
    super.initState();
    _sub = _service.platformPromotions().listen((list) {
      if (mounted) setState(() => _promos = list);
    });
    _capSub = _service.streamMaxOwnerDiscountPct().listen((v) {
      if (mounted) setState(() => _maxOwnerPct = v);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _capSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Platform Promotions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New platform promo',
            onPressed: () => _showForm(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CapCard(
            currentPct: _maxOwnerPct,
            onSave: (v) => _service.setMaxOwnerDiscountPct(v),
          ),
          const SizedBox(height: 20),
          const Text(
            'PLATFORM CODES',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          if (_promos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No platform promotions yet.\nTap + to create one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...List.generate(
              _promos.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AdminPromoCard(
                  promo: _promos[i],
                  onEdit: () => _showForm(context, promo: _promos[i]),
                  onToggle: () => _toggle(_promos[i]),
                  onDelete: () => _confirmDelete(context, _promos[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggle(PromotionModel p) {
    final next = p.status == PromotionStatus.active
        ? PromotionStatus.paused
        : PromotionStatus.active;
    _service.setStatus(p.id, next);
  }

  Future<void> _confirmDelete(BuildContext ctx, PromotionModel p) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete promotion?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Permanently delete "${p.title}"? Code "${p.code}" will stop working immediately.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true) _service.delete(p.id);
  }

  void _showForm(BuildContext ctx, {PromotionModel? promo}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PlatformPromoForm(existing: promo, service: _service),
    );
  }
}

// ── Max owner discount cap card ────────────────────────────────────────────

class _CapCard extends StatefulWidget {
  final double currentPct;
  final Future<void> Function(double) onSave;

  const _CapCard({required this.currentPct, required this.onSave});

  @override
  State<_CapCard> createState() => _CapCardState();
}

class _CapCardState extends State<_CapCard> {
  late TextEditingController _ctrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentPct.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(_CapCard old) {
    super.didUpdateWidget(old);
    if (!_editing) {
      _ctrl.text = widget.currentPct.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Max Owner Discount Cap',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Owners cannot set percentage discounts above this limit.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  onTap: () => setState(() => _editing = true),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    suffixText: '%',
                    suffixStyle: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.warning),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final v = double.tryParse(_ctrl.text.trim());
                          if (v == null || v < 0 || v > 100) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Enter a value between 0 and 100',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() => _saving = true);
                          await widget.onSave(v);
                          setState(() {
                            _saving = false;
                            _editing = false;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cap updated')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Admin promo card (same as owner card but with platform badge) ──────────

class _AdminPromoCard extends StatelessWidget {
  final PromotionModel promo;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _AdminPromoCard({
    required this.promo,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final active = promo.isActive;
    final paused = promo.status == PromotionStatus.paused;
    final expired =
        promo.status == PromotionStatus.expired ||
        (promo.expiresAt != null && promo.expiresAt!.isBefore(DateTime.now()));

    final statusColor = expired
        ? AppColors.textSecondary
        : active
        ? AppColors.success
        : AppColors.warning;
    final statusLabel = expired
        ? 'Expired'
        : active
        ? 'Active'
        : 'Paused';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PLATFORM',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  promo.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  promo.code,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                promo.discountType == DiscountType.percentage
                    ? '${promo.discountValue.toStringAsFixed(0)}% off'
                    : 'PKR ${promo.discountValue.toStringAsFixed(0)} off',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (promo.maxDiscountAmount != null &&
                  promo.discountType == DiscountType.percentage)
                Text(
                  ' (max PKR ${promo.maxDiscountAmount!.toStringAsFixed(0)})',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.bar_chart,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${promo.usageCount} used${promo.maxUses != null ? ' / ${promo.maxUses}' : ''}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (promo.expiresAt != null) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Expires ${DateFormat('d MMM y').format(promo.expiresAt!)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          if (promo.description != null && promo.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              promo.description!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!expired) ...[
                OutlinedButton.icon(
                  onPressed: onToggle,
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause, size: 16),
                  label: Text(paused ? 'Resume' : 'Pause'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.textSecondary),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.error,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Platform promo form ───────────────────────────────────────────────────

class _PlatformPromoForm extends StatefulWidget {
  final PromotionModel? existing;
  final PromotionService service;

  const _PlatformPromoForm({this.existing, required this.service});

  @override
  State<_PlatformPromoForm> createState() => _PlatformPromoFormState();
}

class _PlatformPromoFormState extends State<_PlatformPromoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _code;
  late final TextEditingController _desc;
  late final TextEditingController _value;
  late final TextEditingController _maxDiscount;
  late final TextEditingController _maxUses;
  late DiscountType _type;
  DateTime? _expiresAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _title = TextEditingController(text: p?.title ?? '');
    _code = TextEditingController(text: p?.code ?? '');
    _desc = TextEditingController(text: p?.description ?? '');
    _value = TextEditingController(
      text: p != null ? p.discountValue.toStringAsFixed(0) : '',
    );
    _maxDiscount = TextEditingController(
      text: p?.maxDiscountAmount?.toStringAsFixed(0) ?? '',
    );
    _maxUses = TextEditingController(text: p?.maxUses?.toString() ?? '');
    _type = p?.discountType ?? DiscountType.percentage;
    _expiresAt = p?.expiresAt;
  }

  @override
  void dispose() {
    for (final c in [_title, _code, _desc, _value, _maxDiscount, _maxUses]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.public, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Edit Platform Promo' : 'New Platform Promo',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'This code will work across all arenas on the platform.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _field('Title', _title, hint: 'e.g. Eid Special', required: true),
              const SizedBox(height: 12),
              _field(
                'Promo Code',
                _code,
                hint: 'e.g. EID20',
                required: true,
                onChanged: (v) =>
                    _code.value = _code.value.copyWith(text: v.toUpperCase()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!RegExp(r'^[A-Z0-9_-]{3,20}$').hasMatch(v.trim())) {
                    return '3–20 chars, letters/numbers only';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<DiscountType>(
                segments: const [
                  ButtonSegment(
                    value: DiscountType.percentage,
                    label: Text('Percentage'),
                  ),
                  ButtonSegment(
                    value: DiscountType.flat,
                    label: Text('Flat PKR'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.primary;
                    }
                    return AppColors.elevated;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.black;
                    }
                    return AppColors.textSecondary;
                  }),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _type == DiscountType.percentage
                          ? 'Discount %'
                          : 'Discount Amount (PKR)',
                      _value,
                      keyboardType: TextInputType.number,
                      required: true,
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Enter a valid number';
                        if (_type == DiscountType.percentage && n > 100) {
                          return 'Max 100%';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (_type == DiscountType.percentage) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        'Max Discount (PKR)',
                        _maxDiscount,
                        keyboardType: TextInputType.number,
                        hint: 'Optional cap',
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Max Total Uses',
                      _maxUses,
                      keyboardType: TextInputType.number,
                      hint: 'Blank = unlimited',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Expires On',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _pickDate(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.elevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _expiresAt != null
                                        ? DateFormat(
                                            'd MMM y',
                                          ).format(_expiresAt!)
                                        : 'No expiry',
                                    style: TextStyle(
                                      color: _expiresAt != null
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (_expiresAt != null)
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _expiresAt = null),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field('Description', _desc, hint: 'Internal note', maxLines: 2),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          isEdit ? 'Save Changes' : 'Create Platform Promo',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final adminUid = AuthController.to.currentUser.value?.uid ?? '';
    final code = _code.text.trim().toUpperCase();
    final value = double.parse(_value.text.trim());
    final maxDis = _maxDiscount.text.trim().isNotEmpty
        ? double.tryParse(_maxDiscount.text.trim())
        : null;
    final maxU = _maxUses.text.trim().isNotEmpty
        ? int.tryParse(_maxUses.text.trim())
        : null;

    try {
      if (widget.existing != null) {
        await widget.service.update(widget.existing!.id, {
          'title': _title.text.trim(),
          'code': code,
          'codeNormalized': code,
          if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
          'discountType': _type.name,
          'discountValue': value,
          'maxDiscountAmount': maxDis,
          'maxUses': maxU,
          if (_expiresAt != null)
            'expiresAt': _expiresAt!.millisecondsSinceEpoch,
        });
      } else {
        final promo = PromotionModel(
          id: '',
          arenaId: null,
          ownerId: adminUid,
          scope: PromotionScope.platform,
          title: _title.text.trim(),
          code: code,
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          discountType: _type,
          discountValue: value,
          maxDiscountAmount: maxDis,
          maxUses: maxU,
          expiresAt: _expiresAt,
          createdAt: DateTime.now(),
        );
        await widget.service.create(promo);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.elevated,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          validator:
              validator ??
              (required
                  ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                  : null),
        ),
      ],
    );
  }
}
