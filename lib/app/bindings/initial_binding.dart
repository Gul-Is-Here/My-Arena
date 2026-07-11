import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../theme/theme_controller.dart';

/// App-wide controllers, alive for the whole session.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ThemeController(), permanent: true);
    Get.put(AuthController(), permanent: true);
  }
}
