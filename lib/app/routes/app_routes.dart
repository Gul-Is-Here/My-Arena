/// Route names for the whole app. Phase 1 routes are live;
/// later phases will extend this list.
abstract class AppRoutes {
  // Phase 1 — Auth
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String phoneOtp = '/phone-otp';
  static const String forgotPassword = '/forgot-password';
  static const String profileSetup = '/profile-setup';

  // Role dashboards
  static const String customerDashboard = '/customer';
  static const String ownerDashboard = '/owner';
  static const String staffDashboard = '/staff';
  static const String adminDashboard = '/admin';
}
