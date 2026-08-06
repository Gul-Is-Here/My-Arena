import 'package:get/get.dart';

import '../data/models/user_model.dart';
import '../modules/admin/admin_arena_detail_screen.dart';
import '../modules/admin/admin_permissions_screen.dart';
import '../modules/admin/admin_scope_screen.dart';
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
import '../modules/booking/availability_alerts_screen.dart';
import '../modules/booking/booking_detail_screen.dart';
import '../modules/booking/booking_slot_screen.dart';
import '../modules/booking/join_group_booking_screen.dart';
import '../modules/booking/booking_summary_screen.dart';
import '../modules/booking/cancellation_screen.dart';
import '../modules/booking/deposit_payment_screen.dart';
import '../modules/chat/chat_room_screen.dart';
import '../modules/chat/my_chats_screen.dart';
import '../modules/auth/activate_admin_screen.dart';
import '../modules/auth/activate_owner_screen.dart';
import '../modules/auth/login_screen.dart';
import '../modules/auth/onboarding_screen.dart';
import '../modules/auth/email_otp_screen.dart';
import '../modules/auth/phone_otp_screen.dart';
import '../modules/auth/reset_password_otp_screen.dart';
import '../modules/auth/profile_photo_upload_screen.dart';
import '../modules/auth/profile_setup_screen.dart';
import '../modules/auth/signup_screen.dart';
import '../modules/auth/role_select_screen.dart';
import '../modules/auth/splash_screen.dart';
import '../modules/auth/workspace_selector_screen.dart';
import '../modules/customer/arena_detail_customer_screen.dart';
import '../modules/customer/arena_list_screen.dart';
import '../modules/customer/customer_dashboard_screen.dart';
import '../modules/owner/add_arena_screen.dart';
import '../modules/owner/edit_arena_screen.dart';
import '../modules/owner/arena_detail_owner_screen.dart';
import '../modules/owner/boost_request_screen.dart';
import '../modules/owner/booking_detail_owner_screen.dart';
import '../modules/owner/boost_status_screen.dart';
import '../modules/owner/manual_booking_screen.dart';
import '../modules/owner/owner_bookings_screen.dart';
import '../modules/owner/owner_dashboard_screen.dart';
import '../modules/owner/owner_qr_scanner_screen.dart';
import '../modules/owner/earnings_screen.dart';
import '../modules/owner/owner_tickets_screen.dart';
import '../modules/owner/owner_schedule_screen.dart';
import '../modules/admin/admin_tournaments_screen.dart';
import '../modules/auth/activate_staff_screen.dart';
import '../modules/owner/my_team_screen.dart';
import '../modules/owner/staff_detail_screen.dart';
import '../modules/staff/arena_staff_dashboard_screen.dart';
import '../modules/staff/staff_dashboard_screen.dart';
import '../modules/tournaments/bracket_screen.dart';
import '../modules/tournaments/create_tournament_screen.dart';
import '../modules/tournaments/my_tournaments_screen.dart';
import '../modules/tournaments/owner_tournaments_screen.dart';
import '../modules/tournaments/tournament_detail_screen.dart';
import '../modules/tournaments/tournament_manage_screen.dart';
import '../modules/tournaments/tournament_registration_screen.dart';
import '../modules/tournaments/tournaments_home_screen.dart';
import '../modules/shared/notifications_screen.dart';
import '../modules/shared/unauthorized_screen.dart';
import '../modules/shared/account_suspended_screen.dart';
import '../modules/owner/owner_pending_approval_screen.dart';
import '../modules/admin/admin_bookings_screen.dart';
import '../modules/admin/admin_booking_detail_screen.dart';
import '../modules/admin/admin_customers_screen.dart';
import '../modules/admin/admin_customer_detail_screen.dart';
import '../modules/admin/admin_finance_screen.dart';
import '../middleware/auth_middleware.dart';
import '../modules/shared/edit_profile_screen.dart';
import '../modules/shared/help_support_screen.dart';
import '../modules/support/customer_tickets_screen.dart';
import '../modules/support/customer_ticket_detail_screen.dart';
import '../modules/support/submit_ticket_screen.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const String initial = AppRoutes.splash;

  static final List<GetPage> pages = [
    // Access control — no middleware (must always be reachable)
    GetPage(
      name: AppRoutes.unauthorized,
      page: () => const UnauthorizedScreen(),
    ),
    GetPage(
      name: AppRoutes.accountSuspended,
      page: () => const AccountSuspendedScreen(),
    ),
    GetPage(
      name: AppRoutes.ownerPendingApproval,
      page: () => const OwnerPendingApprovalScreen(),
      middlewares: [AuthMiddleware()],
    ),

    // Auth
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(
      name: AppRoutes.notifications,
      page: () => const NotificationsScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(name: AppRoutes.onboarding, page: () => const OnboardingScreen()),
    GetPage(name: AppRoutes.roleSelect, page: () => const RoleSelectScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
    GetPage(
      name: AppRoutes.activateOwner,
      page: () => const ActivateOwnerScreen(),
    ),
    GetPage(
      name: AppRoutes.activateAdmin,
      page: () => const ActivateAdminScreen(),
    ),
    GetPage(
      name: AppRoutes.activateStaff,
      page: () => const ActivateStaffScreen(),
    ),
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
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.profilePhotoUpload,
      page: () => const ProfilePhotoUploadScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.editProfile,
      page: () => const EditProfileScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.workspaceSelector,
      page: () => const WorkspaceSelectorScreen(),
      middlewares: [AuthMiddleware()],
    ),

    // Role dashboards
    GetPage(
      name: AppRoutes.customerDashboard,
      page: () => const CustomerDashboardScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.ownerDashboard,
      page: () => const OwnerDashboardScreen(),
      middlewares: [OwnerMiddleware()],
    ),
    GetPage(
      name: AppRoutes.staffDashboard,
      page: () => const StaffDashboardScreen(),
      middlewares: [StaffMiddleware()],
    ),
    GetPage(
      name: AppRoutes.arenaStaffDashboard,
      page: () => const ArenaStaffDashboardScreen(),
      middlewares: [StaffMiddleware()],
    ),
    GetPage(
      name: AppRoutes.myTeam,
      page: () => const MyTeamScreen(),
      middlewares: [OwnerMiddleware()],
    ),
    GetPage(
      name: AppRoutes.staffDetail,
      page: () => const StaffDetailScreen(),
      middlewares: [OwnerMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminDashboard,
      page: () => const AdminDashboardScreen(),
      middlewares: [AdminMiddleware()],
    ),

    // Phase 2 — Owner module
    GetPage(
      name: AppRoutes.addArena,
      page: () => const AddArenaScreen(),
      middlewares: [OwnerMiddleware()],
    ),
    GetPage(
      name: AppRoutes.editArena,
      page: () => const EditArenaScreen(),
      middlewares: [OwnerOrArenaStaffMiddleware()],
    ),
    GetPage(
      name: AppRoutes.arenaDetailOwner,
      page: () => const ArenaDetailOwnerScreen(),
      middlewares: [OwnerOrArenaStaffMiddleware()],
    ),
    GetPage(
      name: AppRoutes.boostRequest,
      page: () => const BoostRequestScreen(),
      middlewares: [OwnerMiddleware()],
    ),
    GetPage(
      name: AppRoutes.boostStatus,
      page: () => const BoostStatusScreen(),
      middlewares: [OwnerMiddleware()],
    ),

    // Phase 2 — Customer module
    GetPage(
      name: AppRoutes.arenaList,
      page: () => const ArenaListScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.arenaDetailCustomer,
      page: () => const ArenaDetailCustomerScreen(),
      middlewares: [AuthMiddleware()],
    ),

    // Phase 3 — Booking
    GetPage(
      name: AppRoutes.availabilityAlerts,
      page: () => const AvailabilityAlertsScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.joinGroupBooking,
      page: () => const JoinGroupBookingScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.bookingSlot,
      page: () => const BookingSlotScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.bookingSummary,
      page: () => const BookingSummaryScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.depositPayment,
      page: () => const DepositPaymentScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.bookingConfirmation,
      page: () => const BookingConfirmationScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.bookingCancellation,
      page: () => const CancellationScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.bookingDetail,
      page: () => const BookingDetailScreen(),
      middlewares: [AuthMiddleware()],
    ),

    // Phase 3 — Owner booking management
    GetPage(
      name: AppRoutes.ownerEarnings,
      page: () => const EarningsScreen(),
      middlewares: [OwnerMiddleware()],
    ),
    GetPage(
      name: AppRoutes.ownerTickets,
      page: () => const OwnerTicketsScreen(),
      middlewares: [OwnerOrArenaStaffMiddleware()],
    ),
    GetPage(
      name: AppRoutes.ownerBookings,
      page: () => const OwnerBookingsScreen(),
      middlewares: [OwnerOrArenaStaffMiddleware()],
    ),
    GetPage(
      name: AppRoutes.manualBooking,
      page: () => const ManualBookingScreen(),
      middlewares: [OwnerOrArenaStaffMiddleware()],
    ),
    GetPage(
      name: AppRoutes.bookingDetailOwner,
      page: () => const BookingDetailOwnerScreen(),
      middlewares: [OwnerOrArenaStaffMiddleware()],
    ),
    GetPage(
      name: AppRoutes.ownerQrScanner,
      page: () => const OwnerQrScannerScreen(),
      middlewares: [OwnerOrArenaStaffMiddleware()],
    ),
    GetPage(
      name: AppRoutes.ownerSchedule,
      page: () => const OwnerScheduleScreen(),
      middlewares: [OwnerOrArenaStaffMiddleware()],
    ),

    // Phase 4 — Chat
    GetPage(
      name: AppRoutes.myChats,
      page: () => const MyChatsScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.chatRoom,
      page: () => const ChatRoomScreen(),
      middlewares: [AuthMiddleware()],
    ),

    // Phase 4 — Admin panel
    GetPage(
      name: AppRoutes.adminArenas,
      page: () => const AdminArenasScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminBoosts,
      page: () => const AdminBoostsScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminUsers,
      page: () => const AdminUsersScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminPermissions,
      page: () => AdminPermissionsScreen(user: Get.arguments as UserModel),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminScope,
      page: () => AdminScopeScreen(user: Get.arguments as UserModel),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminSettings,
      page: () => const AdminSettingsScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminAuditLogs,
      page: () => const AdminAuditLogsScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminBookings,
      page: () => const AdminBookingsScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminBookingDetail,
      page: () => const AdminBookingDetailScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminCustomers,
      page: () => const AdminCustomersScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminCustomerDetail,
      page: () => const AdminCustomerDetailScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminFinance,
      page: () => const AdminFinanceScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminArenaDetail,
      page: () => const AdminArenaDetailScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminChats,
      page: () => const AdminChatsScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminChatView,
      page: () => const AdminChatViewScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminTickets,
      page: () => const AdminTicketsScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminTicketDetail,
      page: () => const AdminTicketDetailScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminBookingAnalytics,
      page: () => const AdminBookingAnalyticsScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminRevenueAnalytics,
      page: () => const AdminRevenueAnalyticsScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminStaffAnalytics,
      page: () => const AdminStaffAnalyticsScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminNotifications,
      page: () => const AdminNotificationsScreen(),
      middlewares: [AdminMiddleware()],
    ),

    // Phase 5 — Tournaments
    GetPage(
      name: AppRoutes.tournamentsHome,
      page: () => const TournamentsHomeScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.tournamentDetail,
      page: () => const TournamentDetailScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.tournamentRegistration,
      page: () => const TournamentRegistrationScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.myTournaments,
      page: () => const MyTournamentsScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.bracket,
      page: () => const BracketScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.ownerTournaments,
      page: () => const OwnerTournamentsScreen(),
      middlewares: [OwnerMiddleware()],
    ),
    GetPage(
      name: AppRoutes.createTournament,
      page: () => const CreateTournamentScreen(),
      middlewares: [OwnerMiddleware()],
    ),
    GetPage(
      name: AppRoutes.tournamentManage,
      page: () => const TournamentManageScreen(),
      middlewares: [OwnerMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminTournaments,
      page: () => const AdminTournamentsScreen(),
      middlewares: [AdminMiddleware()],
    ),
    GetPage(
      name: AppRoutes.helpSupport,
      page: () => const HelpSupportScreen(),
      middlewares: [AuthMiddleware()],
    ),

    // Customer support tickets
    GetPage(
      name: AppRoutes.customerTickets,
      page: () => const CustomerTicketsScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.customerTicketDetail,
      page: () => const CustomerTicketDetailScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.submitTicket,
      page: () => const SubmitTicketScreen(),
      middlewares: [AuthMiddleware()],
    ),
  ];
}
