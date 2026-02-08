class ApiConstants {
  static const String baseUrl =
      'http://127.0.0.1:5001/api'; // Update to your production IP

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String verifyOtp = '/auth/verify-otp';
  static const String forgotPassword = '/auth/forgot-password';

  // Home
  static const String home = '/home';
  static const String splash = '/home/splash';

  // Master
  static const String categories = '/master/categories';
  static const String parties = '/master/parties';
  static const String itemGroups = '/master/item-groups';
  static const String lots = '/master/lots';

  // Inventory
  static const String inward = '/inventory/inward';
  static const String outward = '/inventory/outward';
  static const String agingReport = '/inventory/reports/aging';
  static const String overviewReport = '/inventory/reports/overview';
  static const String inwardOutwardReport = '/inventory/reports/inward-outward';
  static const String monthlyReport = '/inventory/reports/monthly';

  // Production
  static const String assignments = '/production/assignments';

  // User
  static const String profile = '/users/profile';
}
