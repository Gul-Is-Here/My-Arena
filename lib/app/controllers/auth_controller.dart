import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:firebase_auth/firebase_auth.dart' as fb show User;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../data/models/user_model.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/otp_service.dart';
import '../theme/app_colors.dart';

/// Phase 1 — real authentication via Firebase Auth + Firestore.
/// Providers: email/password (with email-OTP verification), phone OTP,
/// Google, and Apple (iOS). Password reset also uses an emailed OTP —
/// no verification links anywhere (see OtpService / functions/index.js).
class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final AuthService _service = AuthService();
  final OtpService _otp = OtpService();

  final GetStorage _box = GetStorage();
  static const String _sessionKey = 'session_user';
  static const String _onboardingKey = 'onboarding_seen';

  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final Rx<UserModel?> currentUser = Rxn<UserModel>();

  /// Role picked during signup ("Customer hun ya Owner?")
  final Rx<UserRole> selectedRole = UserRole.customer.obs;

  /// Signup details held while the email OTP is being verified.
  String _pendingName = '';
  String _pendingEmail = '';
  String _pendingPassword = '';

  /// Firebase phone verification session id (set on codeSent).
  String? _phoneVerificationId;

  bool get isLoggedIn => currentUser.value != null;
  bool get hasSeenOnboarding => _box.read<bool>(_onboardingKey) ?? false;
  bool get isAppleAvailable => _service.isAppleAvailable;

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  void _restoreSession() {
    // Only trust the cached session if Firebase still has a signed-in user.
    if (_service.firebaseUser == null) {
      _box.remove(_sessionKey);
      return;
    }
    final saved = _box.read<Map<String, dynamic>>(_sessionKey);
    if (saved != null) currentUser.value = UserModel.fromMap(saved);
  }

  void _saveSession(UserModel user) {
    currentUser.value = user;
    _box.write(_sessionKey, user.toMap());
  }

  void markOnboardingSeen() => _box.write(_onboardingKey, true);

  /// Splash route guard: decides where the user lands.
  Future<void> redirectFromSplash() async {
    final fbUser = _service.firebaseUser;
    if (fbUser == null) {
      Get.offAllNamed(
        hasSeenOnboarding ? AppRoutes.login : AppRoutes.onboarding,
      );
      return;
    }
    // Refresh the profile from Firestore so role changes take effect.
    // If Firestore is unavailable (rules not deployed, offline, etc.), fall
    // back to the cached session — never downgrade the role.
    try {
      final profile = await _service.fetchUser(fbUser.uid);
      if (profile != null) _saveSession(profile);
    } catch (_) {}
    if (currentUser.value == null) {
      Get.offAllNamed(AppRoutes.login);
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
  // Email & password — signup verifies the email with a 6-digit OTP
  // ---------------------------------------------------------------------

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    await _run(() async {
      // Server registers pending user and sends OTP — no Firebase Auth user
      // is created yet (server does that after OTP is verified).
      await _otp.sendEmailOtpWithData(
        email: email,
        name: name,
        password: password,
        role: selectedRole.value.name,
      );
      _pendingName = name;
      _pendingEmail = email;
      _pendingPassword = password;
      Get.toNamed(AppRoutes.emailOtp, arguments: email);
      _snack('Verify your email', 'A 6-digit code was sent to $email');
    });
  }

  /// Called from EmailOtpScreen after signup.
  /// Server creates the Firebase Auth user and Firestore doc.
  /// Flutter then signs in with the original credentials.
  Future<void> verifyEmailOtp(String otp) async {
    await _run(() async {
      await _otp.verifyEmailOtp(
        email: _pendingEmail,
        otp: otp,
        password: _pendingPassword,
      );
      // Server created the user — now sign in to get a Firebase session.
      final fbUser =
          await _service.signInWithEmail(_pendingEmail, _pendingPassword);
      await _completeSignIn(fbUser, fallbackName: _pendingName, isNew: true);
    });
  }

  Future<void> resendEmailOtp() async {
    await _run(() async {
      await _otp.resendEmailOtp(_pendingEmail);
      _snack('Code sent', 'A new code was sent to $_pendingEmail');
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _run(() async {
      final fbUser = await _service.signInWithEmail(email, password);
      await _completeSignIn(fbUser, fallbackName: email.split('@').first);
    });
  }

  // ---------------------------------------------------------------------
  // Social — Google & Apple
  // ---------------------------------------------------------------------

  Future<void> signInWithGoogle() async {
    await _run(() async {
      final fbUser = await _service.signInWithGoogle();
      await _completeSignIn(fbUser, fallbackName: 'Google User');
    });
  }

  Future<void> signInWithApple() async {
    await _run(() async {
      final fbUser = await _service.signInWithApple();
      await _completeSignIn(fbUser, fallbackName: 'Apple User');
    });
  }

  // ---------------------------------------------------------------------
  // Phone OTP
  // ---------------------------------------------------------------------

  Future<void> sendOtp(String phone) async {
    isLoading.value = true;
    error.value = '';
    await _service.sendPhoneOtp(
      phone: phone,
      onCodeSent: (verificationId) {
        isLoading.value = false;
        _phoneVerificationId = verificationId;
        if (Get.currentRoute != AppRoutes.phoneOtp) {
          Get.toNamed(AppRoutes.phoneOtp, arguments: phone);
        }
        _snack('OTP sent', 'A 6-digit code was sent to $phone');
      },
      onFailed: (message) {
        isLoading.value = false;
        error.value = message;
        _snack('Verification failed', message, isError: true);
      },
      onAutoVerified: (credential) async {
        // Android auto-retrieval: sign in without typing the code.
        final fbUser = await _service.signInWithCredential(credential);
        isLoading.value = false;
        await _completeSignIn(fbUser, fallbackName: 'Phone User');
      },
    );
  }

  Future<void> verifyOtp(String phone, String otp) async {
    final verificationId = _phoneVerificationId;
    if (verificationId == null) {
      _snack('Session expired', 'Please request a new code', isError: true);
      return;
    }
    await _run(() async {
      final fbUser = await _service.verifyPhoneOtp(verificationId, otp);
      await _completeSignIn(fbUser, fallbackName: 'Phone User');
    });
  }

  // ---------------------------------------------------------------------
  // Password reset — OTP based, no email links
  // ---------------------------------------------------------------------

  Future<void> resetPassword(String email) async {
    await _run(() async {
      await _otp.sendPasswordResetOtp(email);
      if (Get.currentRoute != AppRoutes.resetPasswordOtp) {
        Get.toNamed(AppRoutes.resetPasswordOtp, arguments: email);
      }
      _snack('Code sent', 'A password reset code was sent to $email');
    });
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _run(() async {
      await _otp.resetPasswordWithOtp(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
      Get.offAllNamed(AppRoutes.login);
      _snack('Password updated', 'Sign in with your new password');
    });
  }

  // ---------------------------------------------------------------------

  /// Shared post-auth step: load (or create) the Firestore profile,
  /// enforce isActive, persist the session and route to the dashboard.
  /// Pass [isNew] = true to force routing to profile setup (e.g. after
  /// email-OTP signup where the server already created the Firestore doc).
  Future<void> _completeSignIn(fb.User fbUser,
      {required String fallbackName, bool isNew = false}) async {
    var profile = await _service.fetchUser(fbUser.uid);
    final bool firstTime = isNew || profile == null;

    if (profile == null) {
      if (!isNew) {
        // Sign-in flow: no Firestore doc exists — this is a first-time social
        // or phone login. Use the role the user selected, but never default
        // to customer silently for an account that may have been set as admin
        // via Firestore console without going through sign-up.
        profile = await _service.createUserDoc(UserModel(
          uid: fbUser.uid,
          name: fbUser.displayName ?? fallbackName,
          email: fbUser.email ?? '',
          phone: fbUser.phoneNumber ?? '',
          role: selectedRole.value,
        ));
      } else {
        // Email signup path — server already created the Firestore doc before
        // we call _completeSignIn; if we still get null something is wrong.
        throw Exception('Profile not found. Please try signing up again.');
      }
    }

    if (!profile.isActive) {
      await _service.signOut();
      throw Exception('This account has been deactivated. Contact support.');
    }
    await _service.touchLastLogin(fbUser.uid);
    _saveSession(profile);
    if (firstTime) {
      Get.offAllNamed(AppRoutes.profileSetup);
    } else {
      goToRoleDashboard();
    }
  }

  /// Force-refreshes the current user's profile from Firestore and re-routes.
  /// Useful after an admin manually updates someone's role in the console.
  Future<void> refreshRole() async {
    final fbUser = _service.firebaseUser;
    if (fbUser == null) return;
    try {
      final profile = await _service.fetchUser(fbUser.uid);
      if (profile != null) {
        _saveSession(profile);
        goToRoleDashboard();
      }
    } catch (_) {}
  }

  Future<void> completeProfile({
    required String name,
    required String phone,
  }) async {
    await _run(() async {
      final user = currentUser.value;
      if (user != null) {
        await _service.updateUserDoc(user.uid, {
          'name': name,
          'phone': phone,
        });
        _saveSession(user.copyWith(name: name, phone: phone));
      }
      goToRoleDashboard();
    });
  }

  Future<void> signOut() async {
    await _service.signOut();
    _box.remove(_sessionKey);
    currentUser.value = null;
    Get.offAllNamed(AppRoutes.login);
  }

  // ---------------------------------------------------------------------

  Future<void> _run(Future<void> Function() action) async {
    isLoading.value = true;
    error.value = '';
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      error.value = _authMessage(e);
      _snack('Authentication failed', error.value, isError: true);
    } on Exception catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
      _snack('Something went wrong', error.value, isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  String _authMessage(FirebaseAuthException e) => switch (e.code) {
        'email-already-in-use' => 'An account already exists for this email.',
        'invalid-email' => 'That email address is not valid.',
        'weak-password' => 'Password is too weak — use at least 6 characters.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Incorrect email or password.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts — try again later.',
        'network-request-failed' => 'Network error — check your connection.',
        'invalid-verification-code' => 'Invalid OTP code — try again.',
        _ => e.message ?? 'Authentication error (${e.code})',
      };

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
