import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/models/user_model.dart';

/// Thin wrapper over Firebase Auth + the Firestore users/{uid} collection.
/// All auth providers (email, Google, Apple, phone) funnel through here so
/// AuthController only deals with UserModel and navigation.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  User? get firebaseUser => _auth.currentUser;

  bool get isAppleAvailable => Platform.isIOS || Platform.isMacOS;

  // ── Firestore users/{uid} ────────────────────────────────────────────

  Future<UserModel?> fetchUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap({...doc.data()!, 'uid': uid});
  }

  Future<UserModel> createUserDoc(UserModel user) async {
    await _users.doc(user.uid).set({
      ...user.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    });
    return user;
  }

  Future<void> updateUserDoc(String uid, Map<String, dynamic> data) =>
      _users.doc(uid).update(data);

  Future<void> touchLastLogin(String uid) =>
      _users.doc(uid).update({'lastLogin': FieldValue.serverTimestamp()});

  // ── Email & password ─────────────────────────────────────────────────

  Future<User> signUpWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user!;
  }

  Future<User> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user!;
  }

  // ── Google ───────────────────────────────────────────────────────────

  Future<User> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    await google.initialize();
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final cred = await _auth.signInWithCredential(credential);
    return cred.user!;
  }

  // ── Apple (iOS/macOS — native sheet via firebase_auth) ──────────────

  Future<User> signInWithApple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    final cred = await _auth.signInWithProvider(provider);
    return cred.user!;
  }

  // ── Phone OTP ────────────────────────────────────────────────────────

  /// Normalizes local PK numbers (03XX…) to E.164 (+923XX…).
  String normalizePhone(String phone) {
    var p = phone.replaceAll(RegExp(r'[\s-]'), '');
    if (p.startsWith('00')) p = '+${p.substring(2)}';
    if (p.startsWith('0')) p = '+92${p.substring(1)}';
    if (!p.startsWith('+')) p = '+$p';
    return p;
  }

  Future<void> sendPhoneOtp({
    required String phone,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onFailed,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: normalizePhone(phone),
      timeout: const Duration(seconds: 60),
      verificationCompleted: onAutoVerified,
      verificationFailed: (e) => onFailed(e.message ?? 'Verification failed'),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<User> verifyPhoneOtp(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final cred = await _auth.signInWithCredential(credential);
    return cred.user!;
  }

  Future<User> signInWithCredential(AuthCredential credential) async {
    final cred = await _auth.signInWithCredential(credential);
    return cred.user!;
  }

  // ── Session ──────────────────────────────────────────────────────────

  /// Deletes the currently signed-in Firebase Auth user.
  /// Called when signup fails mid-way so the user can retry with same email.
  Future<void> deleteCurrentUser() async {
    try {
      await _auth.currentUser?.delete();
    } catch (_) {}
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
