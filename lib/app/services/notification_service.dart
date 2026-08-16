import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// awesome_notifications is native-only — import guarded at call sites via kIsWeb.
import 'package:awesome_notifications/awesome_notifications.dart'
    if (dart.library.html) '../utils/awesome_notifications_stub.dart';

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

  // Guard so _fcm.onTokenRefresh is subscribed only once per app lifetime.
  static bool _tokenRefreshSubscribed = false;

  // Current device's FCM token — kept so we can remove it on logout.
  static String? _currentToken;

  static Future<void> init() async {
    if (!kIsWeb) {
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
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // App in foreground: FCM does not surface a system notification by
    // itself, so show one locally via awesome_notifications instead.
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      if (!kIsWeb) {
        AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
            channelKey: _channelKey,
            title: n.title ?? 'MyArena',
            body: n.body ?? '',
            payload: msg.data.map((k, v) => MapEntry(k, v?.toString())),
          ),
        );
      }
    });

    // App opened by tapping a notification while backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('FCM onMessageOpenedApp: data=${msg.data}');
      _navigate(msg.data.map((k, v) => MapEntry(k, v?.toString())));
    });

    // App launched (cold start) by tapping a notification.
    final initialMsg = await _fcm.getInitialMessage();
    if (initialMsg != null) {
      debugPrint('FCM getInitialMessage (stored): data=${initialMsg.data}');
      _pendingDeepLink = initialMsg.data.map((k, v) => MapEntry(k, v?.toString()));
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await _saveToken(uid);

    // Re-register token when auth state changes (login → new user, logout handled separately).
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await _saveToken(user.uid);
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<void> _onActionReceived(ReceivedAction action) async {
    debugPrint('awesome_notifications tap: payload=${action.payload}');
    _navigate(action.payload ?? {});
  }

  /// Call this after the user is authenticated and their dashboard is rendered.
  static void processPendingDeepLink() {
    final data = _pendingDeepLink;
    if (data == null) return;
    _pendingDeepLink = null;
    debugPrint('NotificationService: processing pending deep-link: $data');
    _navigate(data);
  }

  /// Must be called during sign-out BEFORE the Firebase Auth session is cleared.
  /// Removes this device's FCM token from the user's Firestore document so
  /// the logged-out user stops receiving pushes on this device.
  static Future<void> onSignOut(String uid) async {
    final token = _currentToken;
    if (token == null || token.isEmpty) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmTokens.$token': FieldValue.delete(),
        // Also clear legacy single-token field if it matches.
        'fcmToken': FieldValue.delete(),
      });
      debugPrint('NotificationService: removed token on sign-out for uid=$uid');
    } catch (e) {
      debugPrint('NotificationService: onSignOut cleanup failed: $e');
    }
    _currentToken = null;
  }

  static void _navigate(Map<String, String?> data) {
    final type = data['type'];
    final relatedId = data['relatedId'];
    debugPrint('_navigate: type=$type relatedId=$relatedId');
    if (type == null || relatedId == null || relatedId.isEmpty) return;
    _navigateAsync(type, relatedId);
  }

  static Future<void> _navigateAsync(String type, String relatedId) async {
    // Determine recipient role from the currently signed-in user, not from
    // any stale payload. This means deep-links always open the correct screen
    // for whoever is currently logged in.
    final user = Get.isRegistered<AuthController>()
        ? AuthController.to.currentUser.value
        : null;
    final isOwnerSide = user?.role == UserRole.owner || user?.isArenaStaff == true;

    switch (type) {
      case 'booking':
      case 'booking_reminder':
      case 'extension_request':
        if (isOwnerSide) {
          Get.toNamed(AppRoutes.bookingDetailOwner, arguments: relatedId);
        } else {
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
      case 'chat':
        Get.toNamed(AppRoutes.chatRoom, arguments: relatedId);
        break;
      case 'support':
        if (user?.role == UserRole.admin || user?.role == UserRole.superAdmin) {
          Get.toNamed(AppRoutes.notifications);
        } else if (isOwnerSide) {
          Get.toNamed(AppRoutes.ownerTickets);
        } else {
          Get.toNamed(AppRoutes.customerTicketDetail, arguments: relatedId);
        }
        break;
      case 'tournament':
        Get.toNamed(AppRoutes.tournamentDetail, arguments: relatedId);
        break;
      default:
        Get.toNamed(AppRoutes.notifications);
        break;
    }
  }

  static Future<void> _saveToken(String uid) async {
    // On iOS, the APNS token may not be ready at app start.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final apns = await _fcm.getAPNSToken();
        if (apns == null) {
          _subscribeToTokenRefresh();
          return;
        }
      } catch (_) {
        _subscribeToTokenRefresh();
        return;
      }
    }

    try {
      final token = await _fcm.getToken();
      if (token != null) await _persistToken(uid, token);
    } catch (_) {}

    _subscribeToTokenRefresh();
  }

  static void _subscribeToTokenRefresh() {
    if (_tokenRefreshSubscribed) return;
    _tokenRefreshSubscribed = true;
    _fcm.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) _persistToken(uid, token);
    });
  }

  // Store the token in a per-device map: fcmTokens.{token} = true.
  // This supports multiple devices for one user and makes stale-token
  // removal by the Cloud Function possible (it deletes the specific key).
  // The legacy `fcmToken` single-field is also updated so old Function code
  // continues to work until fully migrated.
  static Future<void> _persistToken(String uid, String token) async {
    _currentToken = token;
    await _firestore.collection('users').doc(uid).set(
      {
        'fcmTokens': {token: true},
        'fcmToken': token, // legacy field kept for backwards compat
      },
      SetOptions(merge: true),
    );
  }
}
