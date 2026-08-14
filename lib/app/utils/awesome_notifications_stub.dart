// Stub for awesome_notifications on web — provides empty classes/enums so
// the import in notification_service.dart compiles. All call sites are already
// guarded with `if (!kIsWeb)` so none of these stubs are ever executed.

class AwesomeNotifications {
  Future<void> initialize(_, __, {bool debug = false}) async {}
  Future<void> setListeners({dynamic onActionReceivedMethod}) async {}
  Future<bool> isNotificationAllowed() async => true;
  Future<void> requestPermissionToSendNotifications() async {}
  Future<void> createNotification({required dynamic content}) async {}
  factory AwesomeNotifications() => _instance;
  static final AwesomeNotifications _instance = AwesomeNotifications._();
  AwesomeNotifications._();
}

class NotificationChannel {
  const NotificationChannel({
    required String channelKey,
    required String channelName,
    required String channelDescription,
    dynamic defaultColor,
    dynamic importance,
  });
}

class NotificationContent {
  const NotificationContent({
    required int id,
    required String channelKey,
    String? title,
    String? body,
    Map<String, String?>? payload,
  });
}

class ReceivedAction {
  final Map<String, String?> payload;
  const ReceivedAction({this.payload = const {}});
}

class NotificationImportance {
  // ignore: constant_identifier_names
  static const NotificationImportance High = NotificationImportance._();
  const NotificationImportance._();
}
