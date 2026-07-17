import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/tournament_controller.dart';
import '../../data/models/tournament_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Individual or team registration, with a JazzCash payment step for
/// paid tournaments. Route argument: tournament id.
class TournamentRegistrationScreen extends StatefulWidget {
  const TournamentRegistrationScreen({super.key});

  @override
  State<TournamentRegistrationScreen> createState() =>
      _TournamentRegistrationScreenState();
}

class _TournamentRegistrationScreenState
    extends State<TournamentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final List<TextEditingController> _memberCtrls =
      List.generate(4, (_) => TextEditingController());
  XFile? _paymentScreenshot;
  bool _submitting = false;

  late final String id = Get.arguments as String;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    for (final ctrl in _memberCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(TournamentModel t) async {
    if (!_formKey.currentState!.validate()) return;
    if (!t.isFree && _paymentScreenshot == null) {
      Get.snackbar('Payment required',
          'Attach your JazzCash payment screenshot to continue.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
      return;
    }
    setState(() => _submitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await TournamentController.to.register(
        RegistrationModel(
          id: '',
          tournamentId: t.id,
          userId: uid,
          type: t.participationType,
          playerName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          members: t.participationType == ParticipationType.team
              ? _memberCtrls
                  .map((c) => c.text.trim())
                  .where((m) => m.isNotEmpty)
                  .toList()
              : const [],
          paymentStatus: t.isFree ? 'free' : 'pending',
          status: t.isFree ? 'confirmed' : 'pending',
          isMine: true,
          registeredAt: DateTime.now(),
        ),
        paymentScreenshot:
            _paymentScreenshot != null ? File(_paymentScreenshot!.path) : null,
      );
      Get.offNamed(AppRoutes.myTournaments);
      Get.snackbar(
        t.isFree ? 'Registered!' : 'Registration submitted',
        t.isFree
            ? 'Your entry pass is ready.'
            : 'Your pass activates once the organizer verifies payment.',
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
    final t = TournamentController.to.byId(id);
    if (t == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Tournament not found')));
    }
    final isTeam = t.participationType == ParticipationType.team;

    return Scaffold(
      appBar: AppBar(title: Text('Register — ${t.name}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              label: isTeam ? 'Team Name' : 'Player Name',
              hint: isTeam ? 'e.g. Thunder FC' : 'e.g. Ali Raza',
              controller: _nameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Phone',
              hint: '03XX-XXXXXXX',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().length < 10) ? 'Invalid phone' : null,
            ),
            if (isTeam) ...[
              const SizedBox(height: 24),
              Text('Team Members', style: AppTextStyles.titleMedium),
              const SizedBox(height: 4),
              Text('Captain is added automatically. Add up to 4 more.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textGrey)),
              const SizedBox(height: 12),
              for (var i = 0; i < _memberCtrls.length; i++) ...[
                AppTextField(
                  label: 'Member ${i + 1}${i == 0 ? '' : ' (optional)'}',
                  hint: 'Full name',
                  controller: _memberCtrls[i],
                  validator: i == 0
                      ? (v) => (v == null || v.trim().isEmpty)
                          ? 'At least one member required'
                          : null
                      : null,
                ),
                const SizedBox(height: 12),
              ],
            ],
            if (!t.isFree) ...[
              const SizedBox(height: 24),
              Text('Entry Fee Payment', style: AppTextStyles.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Send PKR ${t.registrationFee.toStringAsFixed(0)} via JazzCash to 0300-1234567, then attach the screenshot.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textGrey),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 70,
                  );
                  if (picked != null) {
                    setState(() => _paymentScreenshot = picked);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 120,
                  decoration: BoxDecoration(
                    color: _paymentScreenshot != null
                        ? AppColors.success.withValues(alpha: 0.08)
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _paymentScreenshot != null
                          ? AppColors.success
                          : AppColors.textGrey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: _paymentScreenshot != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(File(_paymentScreenshot!.path),
                              fit: BoxFit.cover,
                              width: double.infinity),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_outlined,
                                  size: 32, color: AppColors.textGrey),
                              const SizedBox(height: 6),
                              Text(
                                'Tap to attach payment screenshot',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textGrey),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppButton(
            label: t.isFree ? 'Confirm Registration' : 'Submit Registration',
            icon: Icons.how_to_reg_outlined,
            isLoading: _submitting,
            onPressed: _submitting ? null : () => _submit(t),
          ),
        ),
      ),
    );
  }
}
