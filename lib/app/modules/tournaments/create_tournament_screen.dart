import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/tournament_controller.dart';
import '../../data/models/tournament_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// 5-step tournament creation. Owners submit for admin approval;
/// admin-created tournaments open registration immediately.
/// Optional route argument: 'admin' to create as admin.
class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() =>
      _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  int _step = 0;

  // Step 1 — basics
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _sport = 'Padel';
  XFile? _banner;
  bool _submitting = false;

  // Step 2 — format
  TournamentFormat _format = TournamentFormat.elimination;
  ParticipationType _participation = ParticipationType.individual;
  final _maxCtrl = TextEditingController(text: '8');

  // Step 3 — schedule
  DateTime _start = DateTime.now().add(const Duration(days: 7));
  DateTime _end = DateTime.now().add(const Duration(days: 9));
  DateTime _deadline = DateTime.now().add(const Duration(days: 5));

  // Step 4 — fee & prize
  bool _isFree = true;
  final _feeCtrl = TextEditingController(text: '1000');
  final _prizeCtrl = TextEditingController();

  late final bool _isAdmin = Get.arguments == 'admin';

  static const _sports = ['Padel', 'Football', 'Cricket', 'Other'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _maxCtrl.dispose();
    _feeCtrl.dispose();
    _prizeCtrl.dispose();
    super.dispose();
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  bool get _stepValid {
    switch (_step) {
      case 0:
        return _nameCtrl.text.trim().isNotEmpty;
      case 1:
        return (int.tryParse(_maxCtrl.text) ?? 0) >= 2;
      case 3:
        return _isFree || (double.tryParse(_feeCtrl.text) ?? 0) > 0;
      default:
        return true;
    }
  }

  Future<void> _next() async {
    if (!_stepValid) {
      Get.snackbar('Incomplete', 'Fill the required fields to continue.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
      return;
    }
    if (_step < 4) {
      setState(() => _step++);
    } else {
      await _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await TournamentController.to.create(
        TournamentModel(
          id: '',
          createdBy: uid,
          createdByRole: _isAdmin ? 'admin' : 'owner',
          arenaId: _isAdmin ? null : uid,
          arenaName: _isAdmin ? 'Multiple venues' : '',
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          sport: _sport,
          format: _format,
          participationType: _participation,
          maxParticipants: int.parse(_maxCtrl.text),
          registrationFee: _isFree ? 0 : double.parse(_feeCtrl.text),
          startDate: _start,
          endDate: _end,
          registrationDeadline: _deadline,
          status: _isAdmin
              ? TournamentStatus.registrationOpen
              : TournamentStatus.pendingApproval,
          prizeDetails: _prizeCtrl.text.trim(),
          createdAt: DateTime.now(),
        ),
        banner: _banner != null ? File(_banner!.path) : null,
      );
      Get.back();
      Get.snackbar(
        _isAdmin ? 'Tournament live' : 'Submitted for approval',
        _isAdmin
            ? 'Registration is now open platform-wide.'
            : 'Admin will review your tournament shortly.',
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

  Future<void> _pickDate(int which) async {
    final initial = which == 0 ? _start : (which == 1 ? _end : _deadline);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked == null) return;
    setState(() {
      if (which == 0) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else if (which == 1) {
        _end = picked;
      } else {
        _deadline = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Tournament')),
      body: Column(
        children: [
          // ── Step indicator ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: List.generate(5, (i) {
                final done = i <= _step;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: done
                          ? AppColors.primary
                          : AppColors.textGrey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                [
                  'Step 1 · Basic Info',
                  'Step 2 · Format',
                  'Step 3 · Schedule',
                  'Step 4 · Fee & Prize',
                  'Step 5 · Review',
                ][_step],
                style: AppTextStyles.titleLarge,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _stepContent(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: AppButton(
                    label: 'Back',
                    outlined: true,
                    onPressed: () => setState(() => _step--),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: _step == 4
                      ? (_isAdmin ? 'Publish Tournament' : 'Submit for Approval')
                      : 'Continue',
                  isLoading: _submitting,
                  onPressed: _submitting ? null : _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _stepContent() {
    switch (_step) {
      case 0:
        return [
          AppTextField(
            label: 'Tournament Name',
            hint: 'e.g. Lahore Padel Cup',
            controller: _nameCtrl,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Description',
            hint: 'What makes this tournament special?',
            controller: _descCtrl,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Text('Sport', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _sports
                .map((s) => ChoiceChip(
                      label: Text(s),
                      selected: _sport == s,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _sport == s ? Colors.white : null,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _sport = s),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final picked = await TournamentController.to.pickBanner();
              if (picked != null) setState(() => _banner = picked);
            },
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: _banner != null
                    ? AppColors.success.withValues(alpha: 0.08)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _banner != null
                      ? AppColors.success
                      : AppColors.textGrey.withValues(alpha: 0.3),
                ),
              ),
              child: _banner != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(File(_banner!.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 110),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image_outlined,
                              color: AppColors.textGrey),
                          const SizedBox(height: 6),
                          Text(
                            'Tap to attach banner (optional)',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ];
      case 1:
        return [
          Text('Format', style: AppTextStyles.label),
          const SizedBox(height: 8),
          ...TournamentFormat.values.map(
            (f) => _radioCard(
              title: f.label,
              subtitle: f == TournamentFormat.elimination
                  ? 'Knockout — lose once and you\'re out'
                  : 'Everyone plays everyone, points table decides',
              selected: _format == f,
              onTap: () => setState(() => _format = f),
            ),
          ),
          const SizedBox(height: 16),
          Text('Participation', style: AppTextStyles.label),
          const SizedBox(height: 8),
          ...ParticipationType.values.map(
            (p) => _radioCard(
              title: p.label,
              subtitle: p == ParticipationType.individual
                  ? 'Players register solo'
                  : 'Captains register a full squad',
              selected: _participation == p,
              onTap: () => setState(() => _participation = p),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Max participants',
            controller: _maxCtrl,
            keyboardType: TextInputType.number,
          ),
        ];
      case 2:
        return [
          _dateTile('Start date', _start, () => _pickDate(0)),
          const SizedBox(height: 12),
          _dateTile('End date', _end, () => _pickDate(1)),
          const SizedBox(height: 12),
          _dateTile('Registration deadline', _deadline, () => _pickDate(2)),
          const SizedBox(height: 16),
          Text(
            'Court assignment per match happens from the Manage screen once the bracket is generated.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey),
          ),
        ];
      case 3:
        return [
          _radioCard(
            title: 'Free entry',
            subtitle: 'Registrations confirm instantly',
            selected: _isFree,
            onTap: () => setState(() => _isFree = true),
          ),
          _radioCard(
            title: 'Paid entry',
            subtitle: 'JazzCash payment verified by you',
            selected: !_isFree,
            onTap: () => setState(() => _isFree = false),
          ),
          if (!_isFree) ...[
            const SizedBox(height: 8),
            AppTextField(
              label: 'Registration fee (PKR)',
              controller: _feeCtrl,
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 16),
          AppTextField(
            label: 'Prize details (optional)',
            hint: 'e.g. PKR 50,000 + trophy',
            controller: _prizeCtrl,
          ),
        ];
      default:
        return [
          _reviewRow('Name', _nameCtrl.text.trim()),
          _reviewRow('Sport', _sport),
          _reviewRow('Format', _format.label),
          _reviewRow('Participation', _participation.label),
          _reviewRow('Max participants', _maxCtrl.text),
          _reviewRow('Dates', '${_fmtDate(_start)} – ${_fmtDate(_end)}'),
          _reviewRow('Register by', _fmtDate(_deadline)),
          _reviewRow('Entry',
              _isFree ? 'Free' : 'PKR ${_feeCtrl.text.trim()}'),
          if (_prizeCtrl.text.trim().isNotEmpty)
            _reviewRow('Prize', _prizeCtrl.text.trim()),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isAdmin
                  ? 'Admin tournaments go live immediately — no approval needed.'
                  : 'Your tournament will be reviewed by the admin before registration opens.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
            ),
          ),
        ];
    }
  }

  Widget _radioCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.textGrey.withValues(alpha: 0.2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.textGrey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textGrey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTile(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            Text(_fmtDate(date), style: AppTextStyles.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.textGrey)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end, style: AppTextStyles.titleMedium),
          ),
        ],
      ),
    );
  }
}
