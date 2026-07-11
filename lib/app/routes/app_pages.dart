import 'package:get/get.dart';

import '../modules/admin/admin_dashboard_screen.dart';
import '../modules/auth/forgot_password_screen.dart';
import '../modules/auth/login_screen.dart';
import '../modules/auth/onboarding_screen.dart';
import '../modules/auth/phone_otp_screen.dart';
import '../modules/auth/profile_setup_screen.dart';
import '../modules/auth/signup_screen.dart';
import '../modules/auth/splash_screen.dart';
import '../modules/customer/customer_dashboard_screen.dart';
import '../modules/owner/owner_dashboard_screen.dart';
import '../modules/staff/staff_dashboard_screen.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const String initial = AppRoutes.splash;

  static final List<GetPage> pages = [
    // Phase 1 — Auth
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.onboarding, page: () => const OnboardingScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
    GetPage(name: AppRoutes.signup, page: () => const SignupScreen()),
    GetPage(name: AppRoutes.phoneOtp, page: () => const PhoneOtpScreen()),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotPasswordScreen(),
    ),
    GetPage(
      name: AppRoutes.profileSetup,
      page: () => const ProfileSetupScreen(),
    ),

    // Role dashboards
    GetPage(
      name: AppRoutes.customerDashboard,
      page: () => const CustomerDashboardScreen(),
    ),
    GetPage(
      name: AppRoutes.ownerDashboard,
      page: () => const OwnerDashboardScreen(),
    ),
    GetPage(
      name: AppRoutes.staffDashboard,
      page: () => const StaffDashboardScreen(),
    ),
    GetPage(
      name: AppRoutes.adminDashboard,
      page: () => const AdminDashboardScreen(),
    ),
  ];
}
