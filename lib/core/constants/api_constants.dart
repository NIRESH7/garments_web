class ApiConstants {
  static const String baseUrl =
      'http://localhost:5001/api'; // Update to your production IP
  static const String serverUrl = 'http://localhost:5001';

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
  static const String clientReport = '/inventory/reports/client';

  // Production
  static const String assignments = '/production/assignments';

  // User
  static const String profile = '/users/profile';

  static const String colorPredict = '/color-predict';
  static const String colorPredictFromImage = '/color-predict/from-image';

  // Upload
  static const String upload = '/upload';
}
