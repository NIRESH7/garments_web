class ApiConstants {
  static const String baseUrl =
      'http://13.220.94.83:5001/api'; 
  static const String serverUrl =
      'http://13.220.94.83:5001';  

  // static const String baseUrl = 'http://localhost:5001/api';
  // static const String serverUrl = 'http://localhost:5001';
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
  static const String stockLimits = '/master/stock-limits';

  // Inventory
  static const String inward = '/inventory/inward';
  static const String fifoRecommendation =
      '/inventory/inward/fifo-recommendation';
  static const String qualityAuditReport = '/inventory/reports/quality-audit';
  static const String outward = '/inventory/outward';
  static const String agingReport = '/inventory/reports/aging';
  static const String overviewReport = '/inventory/reports/overview';
  static const String inwardOutwardReport = '/inventory/reports/inward-outward';
  static const String monthlyReport = '/inventory/reports/monthly';
  static const String clientReport = '/inventory/reports/client';
  static const String godownStockReport = '/inventory/reports/godown-stock';
  static const String shadeCardReport = '/inventory/reports/shade-card';
  static const String rackPalletStockReport = '/inventory/reports/rack-pallet';

  // Production
  static const String assignments = '/production/assignments';
  static const String cuttingOrders = '/production/cutting-orders';
  static const String fifoAllocation =
      '/production/cutting-orders/fifo-allocation';
  static const String allocateLots =
      '/production/cutting-orders'; // will append /:id/allocate

  // User
  static const String profile = '/users/profile';

  static const String colorPredict = '/color-predict';
  static const String colorPredictFromImage = '/color-predict/from-image';

  // Notifications
  static const String notifications = '/notifications';

  // AI Chat
  static const String aiChat = '/ai/chat';

  // Tasks
  static const String tasks = '/tasks';

  // Upload
  static const String upload = '/upload';
}
