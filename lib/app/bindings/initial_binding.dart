import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/notification_controller.dart';
import '../services/audit_service.dart';
import '../services/permission_service.dart';
import '../theme/theme_controller.dart';

/// App-wide controllers and services, alive for the whole session.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ThemeController(), permanent: true);
    Get.put(AuthController(), permanent: true);
    Get.put(NotificationController(), permanent: true);
    // Phase 1 — Security services (registered before any route loads)
    Get.put(AuditService(), permanent: true);
    Get.put(PermissionService(), permanent: true);
  }
}
