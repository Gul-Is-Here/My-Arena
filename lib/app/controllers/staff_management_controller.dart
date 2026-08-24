import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../controllers/auth_controller.dart';
import '../data/models/arena_model.dart';
import '../data/models/staff_invitation_model.dart';
import '../data/models/staff_permission_request_model.dart';
import '../data/models/user_model.dart';
import '../theme/app_colors.dart';

class StaffManagementController extends GetxController {
  static StaffManagementController get to => Get.find();

  static const String _baseUrl =
      'https://us-central1-arena-managment-system.cloudfunctions.net';

  final _db = FirebaseFirestore.instance;

  final RxList<UserModel> myStaff = <UserModel>[].obs;
  final RxList<StaffInvitationModel> pendingInvitations = <StaffInvitationModel>[].obs;
  final RxList<StaffPermissionRequestModel> permissionRequests =
      <StaffPermissionRequestModel>[].obs;
  final RxBool isLoading = false.obs;

  StreamSubscription? _staffSub;
  StreamSubscription? _inviteSub;
  StreamSubscription? _permSub;

  String get _uid => AuthController.to.currentUser.value?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    _listenStaff();
    _listenPendingInvitations();
    _listenPermissionRequests();
  }

  @override
  void onClose() {
    _staffSub?.cancel();
    _inviteSub?.cancel();
    _permSub?.cancel();
    super.onClose();
  }

  void _listenStaff() {
    if (_uid.isEmpty) return;
    _staffSub = _db
        .collection('users')
        .where('ownerId', isEqualTo: _uid)
        .where('role', isEqualTo: 'staff')
        .snapshots()
        .listen((snap) {
      myStaff.assignAll(snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['uid'] = d.id;
        return UserModel.fromMap(data);
      }));
    });
  }

  void _listenPendingInvitations() {
    if (_uid.isEmpty) return;
    _inviteSub = _db
        .collection('staffInvitations')
        .where('ownerId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      pendingInvitations.assignAll(snap.docs
          .map((d) => StaffInvitationModel.fromMap(d.id, d.data())));
    });
  }

  void _listenPermissionRequests() {
    if (_uid.isEmpty) return;
    _permSub = _db
        .collection('staffPermissionRequests')
        .where('ownerId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      permissionRequests.assignAll(snap.docs.map(
          (d) => StaffPermissionRequestModel.fromMap(d.id, d.data())));
    });
  }

  int get pendingRequestCount => permissionRequests.length;

  Future<void> inviteStaff({
    required String email,
    required List<ArenaModel> arenas,
  }) async {
    await _run(() async {
      final token = await _idToken();
      await _post(token, {
        'action': 'invite_staff',
        'email': email.trim(),
        'assignedArenas': arenas.map((a) => a.id).toList(),
        'arenaNames': arenas.map((a) => a.name).toList(),
      });
      _snack('Invitation Sent', 'Staff invitation sent to ${email.trim()}');
    });
  }

  Future<void> revokeInvitation(String invitationId) async {
    await _run(() async {
      final token = await _idToken();
      await _post(token, {
        'action': 'revoke_staff_invitation',
        'invitationId': invitationId,
      });
      _snack('Revoked', 'Invitation has been revoked');
    });
  }

  Future<void> updateStaffArenas(
      String staffUid, List<String> arenaIds) async {
    await _run(() async {
      final token = await _idToken();
      await _post(token, {
        'action': 'update_staff_assignment',
        'staffUid': staffUid,
        'assignedArenas': arenaIds,
      });
      _snack('Updated', 'Arena assignment updated');
    });
  }

  Future<void> setSuspended(String staffUid, {required bool suspend}) async {
    await _run(() async {
      final token = await _idToken();
      await _post(token, {
        'action': 'update_staff_assignment',
        'staffUid': staffUid,
        'suspend': suspend,
      });
      _snack(
        suspend ? 'Suspended' : 'Reactivated',
        suspend ? 'Staff member has been suspended.' : 'Staff member reactivated.',
      );
    });
  }

  Future<void> revokePermission({
    required String staffUid,
    required String arenaId,
    required String permission,
  }) async {
    await _run(() async {
      final token = await _idToken();
      await _post(token, {
        'action': 'revoke_permission',
        'staffUid': staffUid,
        'arenaId': arenaId,
        'permission': permission,
      });
      _snack('Access Removed', 'Permission has been revoked.');
    });
  }

  Future<void> resolvePermission(String requestId,
      {required bool approved}) async {
    await _run(() async {
      final token = await _idToken();
      await _post(token, {
        'action': 'resolve_permission',
        'requestId': requestId,
        'approved': approved,
      });
      _snack(
        approved ? 'Access Granted' : 'Request Denied',
        approved ? 'Edit access has been granted.' : 'Permission request denied.',
      );
    });
  }

  // ── Staff-side: request a permission ──────────────────────────────────

  Future<void> requestPermission({
    required String arenaId,
    required String arenaName,
    required List<String> permissions,
    String reason = '',
  }) async {
    await _run(() async {
      final token = await _idToken();
      await _post(token, {
        'action': 'request_permission',
        'arenaId': arenaId,
        'arenaName': arenaName,
        'permissions': permissions,
        'reason': reason,
      });
      _snack('Request Sent', 'Your permission request was sent to your owner.');
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Future<String> _idToken() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final token = await user.getIdToken();
    return token!;
  }

  Future<void> _post(String token, Map<String, dynamic> body) async {
    final resp = await http
        .post(
          Uri.parse('$_baseUrl/staffManagement'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200 || json['success'] != true) {
      throw Exception(json['message'] ?? 'Request failed (HTTP ${resp.statusCode})');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    isLoading.value = true;
    try {
      await action();
    } catch (e) {
      _snack('Error', e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      isLoading.value = false;
    }
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
