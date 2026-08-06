import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:firebase_auth/firebase_auth.dart' as fb show User;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../data/models/user_model.dart';
import '../modules/auth/auth_fx.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
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

  StreamSubscription? _profileSub;

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
        hasSeenOnboarding ? AppRoutes.roleSelect : AppRoutes.onboarding,
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
      Get.offAllNamed(AppRoutes.roleSelect);
      return;
    }
    // If user has multiple roles, let them pick which workspace to enter.
    if (currentUser.value!.hasMultipleRoles) {
      Get.offAllNamed(AppRoutes.workspaceSelector);
      return;
    }
    // Start real-time watch for already-signed-in users.
    _watchProfile(fbUser.uid);
    goToRoleDashboard();
  }

  void goToRoleDashboard() {
    final user = currentUser.value;
    final role = user?.role;
    // Pending owners get a holding screen until admin approves.
    if (role == UserRole.owner &&
        user?.accountStatus == AccountStatus.pending) {
      Get.offAllNamed(AppRoutes.ownerPendingApproval);
      return;
    }
    String route;
    if (role == UserRole.owner) {
      route = AppRoutes.ownerDashboard;
    } else if (role == UserRole.staff) {
      // Arena staff (owner-assigned) vs admin support staff
      route = (user?.isArenaStaff == true)
          ? AppRoutes.arenaStaffDashboard
          : AppRoutes.staffDashboard;
    } else if (role?.isAdminTier == true) {
      route = AppRoutes.adminDashboard;
    } else {
      route = AppRoutes.customerDashboard;
    }
    Get.offAllNamed(route);
    // Process any notification that cold-started the app. Deferred to a
    // post-frame callback so the dashboard route is fully mounted before
    // we push another route on top of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.processPendingDeepLink();
    });
  }

  /// Switch the active role for multi-role accounts and navigate to dashboard.
  void switchRole(UserRole role) {
    final user = currentUser.value;
    if (user == null) return;
    _saveSession(user.copyWith(role: role));
    goToRoleDashboard();
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
      Get.offAllNamed(AppRoutes.roleSelect);
      _snack('Password updated', 'Sign in with your new password');
    });
  }

  // ---------------------------------------------------------------------

  /// Shared post-auth step: load (or create) the Firestore profile,
  /// enforce isActive, check portal mismatch, persist the session and route.
  /// Pass [isNew] = true to force routing to profile setup (e.g. after
  /// email-OTP signup where the server already created the Firestore doc).
  Future<void> _completeSignIn(fb.User fbUser,
      {required String fallbackName, bool isNew = false}) async {
    var profile = await _service.fetchUser(fbUser.uid);
    final bool firstTime = isNew || profile == null;

    if (profile == null) {
      if (!isNew) {
        profile = await _service.createUserDoc(UserModel(
          uid: fbUser.uid,
          name: fbUser.displayName ?? fallbackName,
          email: fbUser.email ?? '',
          phone: fbUser.phoneNumber ?? '',
          role: selectedRole.value,
        ));
      } else {
        throw Exception('Profile not found. Please try signing up again.');
      }
    }

    final blockedStatuses = {
      AccountStatus.suspended,
      AccountStatus.inactive,
      AccountStatus.archived,
    };
    if (blockedStatuses.contains(profile.accountStatus)) {
      await _service.signOut();
      throw Exception(
          'This account has been ${profile.accountStatus.name}. Contact support.');
    }
    await _service.touchLastLogin(fbUser.uid);
    _saveSession(profile);
    _watchProfile(fbUser.uid);

    if (firstTime) {
      if (profile.role == UserRole.customer) {
        Get.offAllNamed(AppRoutes.profileSetup);
      } else {
        goToRoleDashboard();
      }
      return;
    }
    if (profile.hasMultipleRoles) {
      Get.offAllNamed(AppRoutes.workspaceSelector);
      return;
    }

    // Admin-tier accounts always auto-route — no portal check needed.
    if (profile.role.isAdminTier) {
      goToRoleDashboard();
      return;
    }

    // Check whether the user signed in through the correct portal.
    if (_isPortalMismatch(profile.role)) {
      isLoading.value = false; // stop spinner before showing sheet
      await PortalMismatchSheet.show(
        actualRole: profile.role,
        onSwitch: () {
          Get.back(); // close sheet
          goToRoleDashboard();
        },
        onCancel: () {
          Get.back(); // close sheet
          signOut();
        },
      );
      return;
    }

    goToRoleDashboard();
  }

  /// Returns true when the portal the user chose doesn't match their actual role.
  /// Customer portal expects [UserRole.customer].
  /// Owner portal expects [UserRole.owner] or [UserRole.staff].
  bool _isPortalMismatch(UserRole actualRole) {
    final portal = selectedRole.value;
    if (portal == UserRole.customer) {
      // Customer portal: only customer accounts fit here.
      return actualRole != UserRole.customer;
    }
    if (portal == UserRole.owner) {
      // Owner portal: owner and staff are both valid.
      return actualRole != UserRole.owner && actualRole != UserRole.staff;
    }
    // Admin entry (no portal selected) — never mismatch.
    return false;
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
      // Customers get the photo upload step; other roles go straight to dashboard.
      if (currentUser.value?.role == UserRole.customer) {
        Get.offAllNamed(AppRoutes.profilePhotoUpload);
      } else {
        goToRoleDashboard();
      }
    });
  }

  final RxDouble photoUploadProgress = 0.0.obs;

  Future<void> uploadProfilePhoto(
    dynamic file, // dart:io File
  ) async {
    await _run(() async {
      final user = currentUser.value;
      if (user == null) return;
      photoUploadProgress.value = 0;
      final url = await _service.uploadProfilePhoto(
        user.uid,
        file,
        onProgress: (p) => photoUploadProgress.value = p,
      );
      _saveSession(user.copyWith(avatar: url));
    });
  }

  Future<void> updateProfile({required String name, required String phone}) async {
    final user = currentUser.value;
    if (user == null) return;
    await _service.updateUserDoc(user.uid, {'name': name, 'phone': phone});
    _saveSession(user.copyWith(name: name, phone: phone));
  }

  /// Permanently deletes the account: calls the Cloud Function which
  /// handles Auth + Firestore + Storage cleanup, then clears local state.
  Future<void> deleteAccount() async {
    await _run(() async {
      final fbUser = _service.firebaseUser;
      if (fbUser == null) throw Exception('Not signed in.');
      final idToken = await fbUser.getIdToken();
      await _otp.deleteAccount(idToken!);
      _box.remove(_sessionKey);
      currentUser.value = null;
      Get.offAllNamed(AppRoutes.roleSelect);
    });
  }

  /// Subscribes to the user's Firestore doc for real-time status changes.
  /// If the admin suspends/deactivates the account, the stream fires and the
  /// user is force-signed-out immediately — no restart required.
  void _watchProfile(String uid) {
    _profileSub?.cancel();
    _profileSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final updated = UserModel.fromMap({...snap.data()!, 'uid': snap.id});
      // Keep local session in sync with Firestore.
      _saveSession(updated);
      // If admin toggled the account to a blocked state, force sign-out.
      const blocked = {
        AccountStatus.suspended,
        AccountStatus.inactive,
        AccountStatus.archived,
      };
      if (blocked.contains(updated.accountStatus)) {
        _profileSub?.cancel();
        _service.signOut();
        _box.remove(_sessionKey);
        currentUser.value = null;
        Get.offAllNamed(
          AppRoutes.accountSuspended,
          arguments: updated.accountStatus,
        );
      }
      // Pending owner whose admin approved — auto-route to dashboard.
      if (updated.role == UserRole.owner &&
          updated.accountStatus == AccountStatus.active &&
          Get.currentRoute == AppRoutes.ownerPendingApproval) {
        goToRoleDashboard();
      }
    });
  }

  Future<void> signOut() async {
    _profileSub?.cancel();
    await _service.signOut();
    _box.remove(_sessionKey);
    currentUser.value = null;
    Get.offAllNamed(AppRoutes.roleSelect);
  }

  @override
  void onClose() {
    _profileSub?.cancel();
    super.onClose();
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
