import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../data/models/notification_model.dart';

/// Streams the signed-in user's in-app notification inbox.
class NotificationController extends GetxController {
  static NotificationController get to => Get.find();

  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxBool isLoading = true.obs;
  StreamSubscription? _sub;
  StreamSubscription? _authSub;

  int get unreadCount => notifications.where((n) => !n.read).length;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('notifications');

  @override
  void onInit() {
    super.onInit();
    _authSub = FirebaseAuth.instance
        .authStateChanges()
        .listen((user) => _listen(user?.uid));
    _listen(FirebaseAuth.instance.currentUser?.uid);
  }

  void _listen(String? uid) {
    _sub?.cancel();
    _sub = null;
    if (uid == null || uid.isEmpty) {
      notifications.clear();
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    // No orderBy: uid+createdAt would need a composite index; sorting the
    // ≤200 docs client-side avoids that deployment dependency.
    _sub = _col
        .where('uid', isEqualTo: uid)
        .limit(200)
        .snapshots()
        .listen((snap) {
      final list = snap.docs
          .map((d) => NotificationModel.fromMap({...d.data(), 'id': d.id}))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifications.assignAll(list);
      isLoading.value = false;
    }, onError: (e) {
      debugPrint('notifications stream error: $e');
      isLoading.value = false;
    });
  }

  Future<void> markRead(String id) async {
    try {
      await _col.doc(id).update({'read': true});
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final unread = notifications.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final n in unread) {
      batch.update(_col.doc(n.id), {'read': true});
    }
    try {
      await batch.commit();
    } catch (_) {}
  }

  @override
  void onClose() {
    _sub?.cancel();
    _authSub?.cancel();
    super.onClose();
  }
}
