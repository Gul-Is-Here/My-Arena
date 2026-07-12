import 'package:get/get.dart';

import '../modules/admin/admin_arena_detail_screen.dart';
import '../modules/admin/admin_arenas_screen.dart';
import '../modules/admin/admin_booking_analytics_screen.dart';
import '../modules/admin/admin_chat_view_screen.dart';
import '../modules/admin/admin_chats_screen.dart';
import '../modules/admin/admin_notifications_screen.dart';
import '../modules/admin/admin_revenue_analytics_screen.dart';
import '../modules/admin/admin_staff_analytics_screen.dart';
import '../modules/admin/admin_ticket_detail_screen.dart';
import '../modules/admin/admin_tickets_screen.dart';
import '../modules/admin/admin_audit_logs_screen.dart';
import '../modules/admin/admin_boosts_screen.dart';
import '../modules/admin/admin_dashboard_screen.dart';
import '../modules/admin/admin_settings_screen.dart';
import '../modules/admin/admin_users_screen.dart';
import '../modules/auth/forgot_password_screen.dart';
import '../modules/booking/booking_confirmation_screen.dart';
import '../modules/booking/booking_slot_screen.dart';
import '../modules/booking/booking_summary_screen.dart';
import '../modules/booking/cancellation_screen.dart';
import '../modules/booking/deposit_payment_screen.dart';
import '../modules/chat/chat_room_screen.dart';
import '../modules/chat/my_chats_screen.dart';
import '../modules/auth/login_screen.dart';
import '../modules/auth/onboarding_screen.dart';
import '../modules/auth/email_otp_screen.dart';
import '../modules/auth/phone_otp_screen.dart';
import '../modules/auth/reset_password_otp_screen.dart';
import '../modules/auth/profile_setup_screen.dart';
import '../modules/auth/signup_screen.dart';
import '../modules/auth/splash_screen.dart';
import '../modules/customer/arena_detail_customer_screen.dart';
import '../modules/customer/arena_list_screen.dart';
import '../modules/customer/customer_dashboard_screen.dart';
import '../modules/owner/add_arena_screen.dart';
import '../modules/owner/arena_detail_owner_screen.dart';
import '../modules/owner/boost_request_screen.dart';
import '../modules/owner/booking_detail_owner_screen.dart';
import '../modules/owner/boost_status_screen.dart';
import '../modules/owner/manual_booking_screen.dart';
import '../modules/owner/owner_bookings_screen.dart';
import '../modules/owner/owner_dashboard_screen.dart';
import '../modules/admin/admin_tournaments_screen.dart';
import '../modules/staff/staff_dashboard_screen.dart';
import '../modules/tournaments/bracket_screen.dart';
import '../modules/tournaments/create_tournament_screen.dart';
import '../modules/tournaments/my_tournaments_screen.dart';
import '../modules/tournaments/owner_tournaments_screen.dart';
import '../modules/tournaments/tournament_detail_screen.dart';
import '../modules/tournaments/tournament_manage_screen.dart';
import '../modules/tournaments/tournament_registration_screen.dart';
import '../modules/tournaments/tournaments_home_screen.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const String initial = AppRoutes.splash;

  static final List<GetPage> pages = [
    // Auth
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.onboarding, page: () => const OnboardingScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
    GetPage(name: AppRoutes.signup, page: () => const SignupScreen()),
    GetPage(name: AppRoutes.phoneOtp, page: () => const PhoneOtpScreen()),
    GetPage(name: AppRoutes.emailOtp, page: () => const EmailOtpScreen()),
    GetPage(
      name: AppRoutes.resetPasswordOtp,
      page: () => const ResetPasswordOtpScreen(),
    ),
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

    // Phase 2 — Owner module
    GetPage(name: AppRoutes.addArena, page: () => const AddArenaScreen()),
    GetPage(
      name: AppRoutes.arenaDetailOwner,
      page: () => const ArenaDetailOwnerScreen(),
    ),
    GetPage(
      name: AppRoutes.boostRequest,
      page: () => const BoostRequestScreen(),
    ),
    GetPage(
      name: AppRoutes.boostStatus,
      page: () => const BoostStatusScreen(),
    ),

    // Phase 2 — Customer module
    GetPage(name: AppRoutes.arenaList, page: () => const ArenaListScreen()),
    GetPage(
      name: AppRoutes.arenaDetailCustomer,
      page: () => const ArenaDetailCustomerScreen(),
    ),

    // Phase 3 — Booking
    GetPage(name: AppRoutes.bookingSlot, page: () => const BookingSlotScreen()),
    GetPage(
      name: AppRoutes.bookingSummary,
      page: () => const BookingSummaryScreen(),
    ),
    GetPage(
      name: AppRoutes.depositPayment,
      page: () => const DepositPaymentScreen(),
    ),
    GetPage(
      name: AppRoutes.bookingConfirmation,
      page: () => const BookingConfirmationScreen(),
    ),
    GetPage(
      name: AppRoutes.bookingCancellation,
      page: () => const CancellationScreen(),
    ),

    // Phase 3 — Owner booking management
    GetPage(
      name: AppRoutes.ownerBookings,
      page: () => const OwnerBookingsScreen(),
    ),
    GetPage(
      name: AppRoutes.manualBooking,
      page: () => const ManualBookingScreen(),
    ),
    GetPage(
      name: AppRoutes.bookingDetailOwner,
      page: () => const BookingDetailOwnerScreen(),
    ),

    // Phase 4 — Chat
    GetPage(name: AppRoutes.myChats, page: () => const MyChatsScreen()),
    GetPage(name: AppRoutes.chatRoom, page: () => const ChatRoomScreen()),

    // Phase 4 — Admin panel
    GetPage(name: AppRoutes.adminArenas, page: () => const AdminArenasScreen()),
    GetPage(name: AppRoutes.adminBoosts, page: () => const AdminBoostsScreen()),
    GetPage(name: AppRoutes.adminUsers, page: () => const AdminUsersScreen()),
    GetPage(
      name: AppRoutes.adminSettings,
      page: () => const AdminSettingsScreen(),
    ),
    GetPage(
      name: AppRoutes.adminAuditLogs,
      page: () => const AdminAuditLogsScreen(),
    ),
    GetPage(
      name: AppRoutes.adminArenaDetail,
      page: () => const AdminArenaDetailScreen(),
    ),
    GetPage(name: AppRoutes.adminChats, page: () => const AdminChatsScreen()),
    GetPage(
      name: AppRoutes.adminChatView,
      page: () => const AdminChatViewScreen(),
    ),
    GetPage(
      name: AppRoutes.adminTickets,
      page: () => const AdminTicketsScreen(),
    ),
    GetPage(
      name: AppRoutes.adminTicketDetail,
      page: () => const AdminTicketDetailScreen(),
    ),
    GetPage(
      name: AppRoutes.adminBookingAnalytics,
      page: () => const AdminBookingAnalyticsScreen(),
    ),
    GetPage(
      name: AppRoutes.adminRevenueAnalytics,
      page: () => const AdminRevenueAnalyticsScreen(),
    ),
    GetPage(
      name: AppRoutes.adminStaffAnalytics,
      page: () => const AdminStaffAnalyticsScreen(),
    ),
    GetPage(
      name: AppRoutes.adminNotifications,
      page: () => const AdminNotificationsScreen(),
    ),

    // Phase 5 — Tournaments
    GetPage(
      name: AppRoutes.tournamentsHome,
      page: () => const TournamentsHomeScreen(),
    ),
    GetPage(
      name: AppRoutes.tournamentDetail,
      page: () => const TournamentDetailScreen(),
    ),
    GetPage(
      name: AppRoutes.tournamentRegistration,
      page: () => const TournamentRegistrationScreen(),
    ),
    GetPage(
      name: AppRoutes.myTournaments,
      page: () => const MyTournamentsScreen(),
    ),
    GetPage(name: AppRoutes.bracket, page: () => const BracketScreen()),
    GetPage(
      name: AppRoutes.ownerTournaments,
      page: () => const OwnerTournamentsScreen(),
    ),
    GetPage(
      name: AppRoutes.createTournament,
      page: () => const CreateTournamentScreen(),
    ),
    GetPage(
      name: AppRoutes.tournamentManage,
      page: () => const TournamentManageScreen(),
    ),
    GetPage(
      name: AppRoutes.adminTournaments,
      page: () => const AdminTournamentsScreen(),
    ),
  ];
}
