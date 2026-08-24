import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app/bindings/initial_binding.dart';
import 'app/services/notification_service.dart';
import 'firebase_options.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.init();

  // cloud_firestore tears down a completed transaction's platform EventChannel
  // by calling "cancel" on it; if the transaction already finished (or a hot
  // reload reset plugin registration), the native side has nothing to cancel
  // and Flutter reports a MissingPluginException. The transaction/listener has
  // already done its job by then, so this specific exception is safe to drop.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final isBenignFirestoreCancel =
        details.exception is MissingPluginException &&
        details.exception.toString().contains('cancel') &&
        details.exception.toString().contains('firebase_firestore');
    if (isBenignFirestoreCancel) return;
    previousOnError?.call(details);
  };

  runApp(const MyArenaApp());
}

class MyArenaApp extends StatelessWidget {
  const MyArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Register app-wide controllers before the first frame so the
    // initial themeMode can read the persisted preference.
    InitialBinding().dependencies();
    return GetMaterialApp(
      title: 'My Arena',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeController.to.themeMode,
      initialRoute: AppPages.initial,
      getPages: AppPages.pages,
      defaultTransition: Transition.cupertino,
    );
  }
}
