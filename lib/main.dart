import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app/bindings/initial_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
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
