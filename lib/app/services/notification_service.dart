import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled by the OS notification tray — no action needed.
  debugPrint('FCM background: ${message.messageId}');
}

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null) {
        Get.snackbar(n.title ?? 'MyArena', n.body ?? '',
            duration: const Duration(seconds: 4));
      }
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await _saveToken(uid);

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) await _saveToken(user.uid);
    });
  }

  static Future<void> _saveToken(String uid) async {
    // On iOS, the APNS token may not be ready at app start.
    // Attempt to get the FCM token; if APNS isn't set yet, skip silently —
    // onTokenRefresh will fire once the device registers.
    if (Platform.isIOS) {
      try {
        final apns = await _fcm.getAPNSToken();
        if (apns == null) {
          _fcm.onTokenRefresh.listen((t) => _persistToken(uid, t));
          return;
        }
      } catch (_) {
        _fcm.onTokenRefresh.listen((t) => _persistToken(uid, t));
        return;
      }
    }

    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await _persistToken(uid, token);
    } catch (_) {}

    _fcm.onTokenRefresh.listen((t) => _persistToken(uid, t));
  }

  static Future<void> _persistToken(String uid, String token) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }
}
