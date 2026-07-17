/// Route names for the whole app. Phase 1 routes are live;
/// later phases will extend this list.
abstract class AppRoutes {
  // Phase 1 — Auth
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String phoneOtp = '/phone-otp';
  static const String emailOtp = '/email-otp';
  static const String forgotPassword = '/forgot-password';
  static const String resetPasswordOtp = '/reset-password-otp';
  static const String profileSetup = '/profile-setup';

  // Role dashboards
  static const String customerDashboard = '/customer';
  static const String ownerDashboard = '/owner';
  static const String staffDashboard = '/staff';
  static const String adminDashboard = '/admin';

  // Phase 2 — Owner module
  static const String myArenas = '/owner/my-arenas';
  static const String addArena = '/owner/add-arena';
  static const String editArena = '/owner/edit-arena';
  static const String arenaDetailOwner = '/owner/arena-detail';
  static const String boostRequest = '/owner/boost-request';
  static const String boostStatus = '/owner/boost-status';

  // Phase 2 — Customer module
  static const String arenaList = '/customer/arena-list';
  static const String arenaDetailCustomer = '/customer/arena-detail';

  // Phase 3 — Booking
  static const String bookingSlot = '/booking/slot';
  static const String bookingSummary = '/booking/summary';
  static const String depositPayment = '/booking/deposit';
  static const String bookingConfirmation = '/booking/confirmation';
  static const String bookingCancellation = '/booking/cancel';
  static const String bookingDetail = '/booking/detail';

  // Phase 3 — Owner booking management
  static const String ownerBookings = '/owner/bookings';
  static const String manualBooking = '/owner/manual-booking';
  static const String bookingDetailOwner = '/owner/booking-detail';
  static const String ownerQrScanner = '/owner/qr-scanner';

  // Phase 4 — Chat
  static const String myChats = '/chat/my-chats';
  static const String chatRoom = '/chat/room';

  // Phase 4 — Admin panel
  static const String adminArenas = '/admin/arenas';
  static const String adminBoosts = '/admin/boosts';
  static const String adminUsers = '/admin/users';
  static const String adminSettings = '/admin/settings';
  static const String adminAuditLogs = '/admin/audit-logs';
  static const String adminArenaDetail = '/admin/arena-detail';
  static const String adminChats = '/admin/chats';
  static const String adminChatView = '/admin/chat-view';
  static const String adminTickets = '/admin/tickets';
  static const String adminTicketDetail = '/admin/ticket-detail';
  static const String adminBookingAnalytics = '/admin/analytics/bookings';
  static const String adminRevenueAnalytics = '/admin/analytics/revenue';
  static const String adminStaffAnalytics = '/admin/analytics/staff';
  static const String adminNotifications = '/admin/notifications';

  // Phase 5 — Tournaments
  static const String tournamentsHome = '/tournaments';
  static const String tournamentDetail = '/tournaments/detail';
  static const String tournamentRegistration = '/tournaments/register';
  static const String myTournaments = '/tournaments/mine';
  static const String bracket = '/tournaments/bracket';
  static const String ownerTournaments = '/owner/tournaments';
  static const String createTournament = '/tournaments/create';
  static const String tournamentManage = '/tournaments/manage';
  static const String adminTournaments = '/admin/tournaments';
}
