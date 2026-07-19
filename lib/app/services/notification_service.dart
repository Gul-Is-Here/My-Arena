import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/booking_controller.dart';
import '../data/models/user_model.dart';
import '../routes/app_routes.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The OS shows the notification from the message's `notification` payload
  // automatically while the app is backgrounded/terminated — no action needed here.
  debugPrint('FCM background: ${message.messageId}');
}

class NotificationService {
  static const _channelKey = 'my_arena_channel';
  static final _fcm = FirebaseMessaging.instance;
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> init() async {
    await AwesomeNotifications().initialize(
      null, // default app icon
      [
        NotificationChannel(
          channelKey: _channelKey,
          channelName: 'MyArena notifications',
          channelDescription: 'Booking, review and tournament updates',
          defaultColor: const Color(0xFF2979FF),
          importance: NotificationImportance.High,
        ),
      ],
      debug: kDebugMode,
    );

    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onActionReceived,
    );

    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // App in foreground: FCM does not surface a system notification by
    // itself, so show one locally via awesome_notifications instead.
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
          channelKey: _channelKey,
          title: n.title ?? 'MyArena',
          body: n.body ?? '',
          payload: msg.data.map((k, v) => MapEntry(k, v?.toString())),
        ),
      );
    });

    // App opened by tapping a notification while backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('FCM onMessageOpenedApp: data=${msg.data}');
      _navigate(msg.data.map((k, v) => MapEntry(k, v?.toString())));
    });

    // App launched (cold start) by tapping a notification.
    final initialMsg = await _fcm.getInitialMessage();
    if (initialMsg != null) {
      debugPrint('FCM getInitialMessage: data=${initialMsg.data}');
      _navigate(initialMsg.data.map((k, v) => MapEntry(k, v?.toString())));
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await _saveToken(uid);

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) await _saveToken(user.uid);
    });
  }

  @pragma('vm:entry-point')
  static Future<void> _onActionReceived(ReceivedAction action) async {
    debugPrint('awesome_notifications tap: payload=${action.payload}');
    _navigate(action.payload ?? {});
  }

  static void _navigate(Map<String, String?> data) {
    final type = data['type'];
    final relatedId = data['relatedId'];
    debugPrint('_navigate: type=$type relatedId=$relatedId');
    if (type == null || relatedId == null || relatedId.isEmpty) {
      debugPrint('_navigate: aborting, missing type/relatedId');
      return;
    }

    switch (type) {
      case 'booking':
        final role = AuthController.to.currentUser.value?.role;
        debugPrint('_navigate: role=$role');
        if (role == UserRole.owner || role == UserRole.staff) {
          debugPrint('_navigate: going to bookingDetailOwner with id=$relatedId');
          Get.toNamed(AppRoutes.bookingDetailOwner, arguments: relatedId);
        } else {
          final bc = Get.find<BookingController>();
          final booking = bc.bookings.firstWhereOrNull((b) => b.id == relatedId);
          if (booking != null) {
            Get.toNamed(AppRoutes.bookingDetail, arguments: booking);
          }
        }
        break;
      case 'tournament':
        Get.toNamed(AppRoutes.tournamentDetail, arguments: relatedId);
        break;
      default:
        break;
    }
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
