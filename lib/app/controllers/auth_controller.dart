import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../data/models/user_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

/// Phase 1 — UI-first placeholder logic. Simulates auth with dummy data
/// and persists the session locally; Firebase Auth will replace the
/// simulated parts later without changing the screen contracts.
class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final GetStorage _box = GetStorage();
  static const String _sessionKey = 'session_user';
  static const String _onboardingKey = 'onboarding_seen';

  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final Rx<UserModel?> currentUser = Rxn<UserModel>();

  /// Role picked during signup ("Customer hun ya Owner?")
  final Rx<UserRole> selectedRole = UserRole.customer.obs;

  bool get isLoggedIn => currentUser.value != null;
  bool get hasSeenOnboarding => _box.read<bool>(_onboardingKey) ?? false;

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  void _restoreSession() {
    final saved = _box.read<Map<String, dynamic>>(_sessionKey);
    if (saved != null) currentUser.value = UserModel.fromMap(saved);
  }

  void _saveSession(UserModel user) {
    currentUser.value = user;
    _box.write(_sessionKey, user.toMap());
  }

  void markOnboardingSeen() => _box.write(_onboardingKey, true);

  /// Splash route guard: decides where the user lands.
  void redirectFromSplash() {
    if (!isLoggedIn) {
      Get.offAllNamed(
        hasSeenOnboarding ? AppRoutes.login : AppRoutes.onboarding,
      );
      return;
    }
    goToRoleDashboard();
  }

  void goToRoleDashboard() {
    switch (currentUser.value?.role) {
      case UserRole.owner:
        Get.offAllNamed(AppRoutes.ownerDashboard);
      case UserRole.staff:
        Get.offAllNamed(AppRoutes.staffDashboard);
      case UserRole.admin:
        Get.offAllNamed(AppRoutes.adminDashboard);
      case UserRole.customer:
      case null:
        Get.offAllNamed(AppRoutes.customerDashboard);
    }
  }

  // ---------------------------------------------------------------------
  // Auth methods — placeholder implementations (Firebase in later phase)
  // ---------------------------------------------------------------------

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    await _simulate(() {
      _saveSession(UserModel(
        uid: 'mock-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email,
        role: selectedRole.value,
      ));
      Get.offAllNamed(AppRoutes.profileSetup);
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _simulate(() {
      // Dummy shortcut: email prefix decides the role for UI testing,
      // e.g. owner@x.com → owner dashboard, admin@x.com → admin.
      final prefix = email.split('@').first.toLowerCase();
      final role = UserRoleX.fromString(prefix);
      _saveSession(UserModel(
        uid: 'mock-login',
        name: prefix.capitalizeFirst ?? 'User',
        email: email,
        role: role,
      ));
      goToRoleDashboard();
    });
  }

  Future<void> signInWithGoogle() async {
    await _simulate(() {
      _saveSession(const UserModel(
        uid: 'mock-google',
        name: 'Google User',
        email: 'google.user@gmail.com',
      ));
      goToRoleDashboard();
    });
  }

  Future<void> sendOtp(String phone) async {
    await _simulate(() {
      Get.toNamed(AppRoutes.phoneOtp, arguments: phone);
      _snack('OTP sent', 'Use 123456 to verify (dummy)');
    });
  }

  Future<void> verifyOtp(String phone, String otp) async {
    await _simulate(() {
      if (otp != '123456') {
        error.value = 'Invalid OTP — try 123456';
        _snack('Verification failed', error.value, isError: true);
        return;
      }
      _saveSession(UserModel(
        uid: 'mock-phone',
        name: 'Phone User',
        email: '',
        phone: phone,
      ));
      Get.offAllNamed(AppRoutes.profileSetup);
    });
  }

  Future<void> resetPassword(String email) async {
    await _simulate(() {
      _snack('Email sent', 'Password reset link sent to $email (dummy)');
      Get.back();
    });
  }

  Future<void> completeProfile({
    required String name,
    required String phone,
  }) async {
    await _simulate(() {
      final user = currentUser.value;
      if (user != null) {
        _saveSession(user.copyWith(name: name, phone: phone));
      }
      goToRoleDashboard();
    });
  }

  void signOut() {
    _box.remove(_sessionKey);
    currentUser.value = null;
    Get.offAllNamed(AppRoutes.login);
  }

  // ---------------------------------------------------------------------

  Future<void> _simulate(VoidCallback onDone) async {
    isLoading.value = true;
    error.value = '';
    await Future.delayed(const Duration(milliseconds: 900));
    isLoading.value = false;
    onDone();
  }

  void _snack(String title, String message, {bool isError = false}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? AppColors.error : AppColors.darkCard,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
    );
  }
}
