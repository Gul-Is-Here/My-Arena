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
import '../data/models/booking_model.dart';
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

  // Payload from getInitialMessage (cold start). Cannot navigate at init() time
  // because the navigator and controllers don't exist yet. Processed after the
  // auth flow routes the user to their dashboard.
  static Map<String, String?>? _pendingDeepLink;

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
    // Store the payload — don't navigate yet. At this point runApp() hasn't
    // been called, so there is no navigator and no GetX controllers. Navigation
    // is deferred to processPendingDeepLink(), called from goToRoleDashboard()
    // after auth resolves and the dashboard route is on screen.
    final initialMsg = await _fcm.getInitialMessage();
    if (initialMsg != null) {
      debugPrint('FCM getInitialMessage (stored): data=${initialMsg.data}');
      _pendingDeepLink = initialMsg.data.map((k, v) => MapEntry(k, v?.toString()));
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

  /// Call this after the user is authenticated and their dashboard is rendered.
  /// Processes any notification that launched the app from a terminated state.
  static void processPendingDeepLink() {
    final data = _pendingDeepLink;
    if (data == null) return;
    _pendingDeepLink = null;
    debugPrint('NotificationService: processing pending deep-link: $data');
    _navigate(data);
  }

  static void _navigate(Map<String, String?> data) {
    final type = data['type'];
    final relatedId = data['relatedId'];
    debugPrint('_navigate: type=$type relatedId=$relatedId');
    if (type == null || relatedId == null || relatedId.isEmpty) return;
    _navigateAsync(type, relatedId);
  }

  static Future<void> _navigateAsync(String type, String relatedId) async {
    switch (type) {
      case 'booking':
      case 'booking_reminder':
        final role = Get.isRegistered<AuthController>()
            ? AuthController.to.currentUser.value?.role
            : null;
        if (role == UserRole.owner || role == UserRole.staff) {
          Get.toNamed(AppRoutes.bookingDetailOwner, arguments: relatedId);
        } else {
          // Try in-memory cache first; fall back to a Firestore fetch so
          // deep-links work even on cold start before bookings are loaded.
          BookingModel? booking;
          if (Get.isRegistered<BookingController>()) {
            booking = Get.find<BookingController>()
                .bookings
                .firstWhereOrNull((b) => b.id == relatedId);
          }
          if (booking == null) {
            try {
              final snap = await _firestore.collection('bookings').doc(relatedId).get();
              if (snap.exists) {
                booking = BookingModel.fromMap({...snap.data()!, 'id': snap.id});
              }
            } catch (e) {
              debugPrint('_navigateAsync: Firestore fetch failed: $e');
            }
          }
          if (booking != null) {
            Get.toNamed(AppRoutes.bookingDetail, arguments: booking);
          }
        }
        break;
      case 'tournament':
        Get.toNamed(AppRoutes.tournamentDetail, arguments: relatedId);
        break;
      default:
        // Unknown type — open the notification inbox as a fallback.
        Get.toNamed(AppRoutes.notifications);
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
