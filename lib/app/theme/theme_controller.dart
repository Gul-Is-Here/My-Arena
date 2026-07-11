import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Persists the user's theme choice. Dark is the default per scope.
class ThemeController extends GetxController {
  static ThemeController get to => Get.find();

  final GetStorage _box = GetStorage();
  static const String _key = 'isDarkMode';

  final RxBool isDarkMode = true.obs;

  ThemeMode get themeMode =>
      isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  @override
  void onInit() {
    super.onInit();
    isDarkMode.value = _box.read<bool>(_key) ?? true;
  }

  void toggleTheme() {
    isDarkMode.value = !isDarkMode.value;
    Get.changeThemeMode(themeMode);
    _box.write(_key, isDarkMode.value);
  }
}
