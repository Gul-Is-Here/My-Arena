import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP-based OTP service matching the Cloud Functions in functions/.
/// Endpoints: verifyEmail, passwordReset (see functions/index.js).
class OtpService {
  // After deploying, replace with the actual region URL from Firebase console.
  // e.g. https://us-central1-arena-managment-system.cloudfunctions.net
  static const String _baseUrl =
      'https://us-central1-arena-managment-system.cloudfunctions.net';

  // ── Email verification (signup) ──────────────────────────────────────

  Future<void> sendEmailOtp(String email) => _post('verifyEmail', {
        'action': 'register_and_send_otp',
        'email': email,
      });

  Future<void> sendEmailOtpWithData({
    required String email,
    required String name,
    required String password,
    required String role,
  }) =>
      _post('verifyEmail', {
        'action': 'register_and_send_otp',
        'email': email,
        'name': name,
        'password': password,
        'role': role,
      });

  Future<void> verifyEmailOtp({
    required String email,
    required String otp,
    required String password,
  }) =>
      _post('verifyEmail', {
        'action': 'verify_otp_and_create_user',
        'email': email,
        'otp': otp,
        'password': password,
      });

  Future<void> resendEmailOtp(String email) => _post('verifyEmail', {
        'action': 'resend_otp',
        'email': email,
      });

  // ── Password reset ───────────────────────────────────────────────────

  Future<void> sendPasswordResetOtp(String email) => _post('passwordReset', {
        'action': 'send_reset_otp',
        'email': email,
      });

  Future<void> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) =>
      _post('passwordReset', {
        'action': 'verify_reset_otp',
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      });

  // ── Account deletion ─────────────────────────────────────────────────

  /// Calls the `deleteAccount` Cloud Function with the user's ID token.
  /// The function deletes Auth user, anonymises Firestore PII, and removes
  /// Storage avatar. Throws on failure.
  Future<void> deleteAccount(String idToken) async {
    final uri = Uri.parse('$_baseUrl/deleteAccount');
    if (kDebugMode) debugPrint('OtpService → POST $uri [deleteAccount]');

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({}),
        )
        .timeout(const Duration(seconds: 30));

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (kDebugMode) debugPrint('OtpService ← ${response.statusCode} $json');

    if (response.statusCode != 200 || json['success'] != true) {
      throw Exception(
          json['message'] ?? 'Failed to delete account (HTTP ${response.statusCode})');
    }
  }

  // ── Owner account activation ─────────────────────────────────────────

  /// Called from the activation screen. Validates the code server-side,
  /// enables the Firebase Auth account, and sets the owner's password.
  Future<void> activateOwnerAccount({
    required String email,
    required String code,
    required String password,
  }) =>
      _post('inviteOwner', {
        'action': 'accept_invitation',
        'email': email,
        'code': code,
        'password': password,
      });

  // ── Admin: invite / resend / revoke ──────────────────────────────────

  Future<Map<String, dynamic>> inviteOwner({
    required String email,
    required String name,
    required String phone,
    required String idToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/inviteOwner');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'action': 'invite_owner', 'email': email, 'name': name, 'phone': phone}),
        )
        .timeout(const Duration(seconds: 30));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || json['success'] != true) {
      throw Exception(json['message'] ?? 'Failed to send invitation');
    }
    return json;
  }

  Future<void> resendInvitation(String invitationId, String idToken) async {
    final uri = Uri.parse('$_baseUrl/inviteOwner');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'action': 'resend_invitation', 'invitationId': invitationId}),
        )
        .timeout(const Duration(seconds: 30));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || json['success'] != true) {
      throw Exception(json['message'] ?? 'Failed to resend invitation');
    }
  }

  Future<void> revokeInvitation(String invitationId, String idToken) async {
    final uri = Uri.parse('$_baseUrl/inviteOwner');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'action': 'revoke_invitation', 'invitationId': invitationId}),
        )
        .timeout(const Duration(seconds: 30));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || json['success'] != true) {
      throw Exception(json['message'] ?? 'Failed to revoke invitation');
    }
  }

  // ── HTTP helper ──────────────────────────────────────────────────────

  Future<void> _post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    if (kDebugMode) debugPrint('OtpService → POST $uri $body');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (kDebugMode) debugPrint('OtpService ← ${response.statusCode} $json');

    if (response.statusCode != 200 || json['success'] != true) {
      throw Exception(
          json['message'] ?? 'Something went wrong (HTTP ${response.statusCode})');
    }
  }
}
