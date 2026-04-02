class ApiConstants {
  // For release/live builds:
  // flutter build apk --release --dart-define=API_BASE_URL=http://your-server:5001/api --dart-define=SERVER_URL=http://your-server:5001
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5001/api',
  );
  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://localhost:5001',
  );
  static const String s3BaseUrl =
      'https://garments-app-storage.s3.us-east-1.amazonaws.com';

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
  static const String inwardImport = '/inventory/inward/import';
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
  static const String inventoryDrillDown = '/inventory/drill-down';
  static const String aiTranscribe = '/ai/transcribe';

  static const String assignments = '/production/assignments';
  static const String cuttingMaster = '/production/cutting-master';
  static const String accessoriesMaster = '/production/accessories-master';
  static const String cuttingOrders = '/production/cutting-orders';
  static const String fifoAllocation =
      '/production/cutting-orders/fifo-allocation';
  static const String allocateLots =
      '/production/cutting-orders'; // will append /:id/allocate
  static const String previousPlanningEntries =
      '/production/cutting-orders/previous-entries';
  static const String cuttingPlanReport = '/production/cutting-orders/report';

  // New Module API Constants (Additive Only)
  static const String cuttingEntry = '/production/cutting-entry';
  static const String cuttingEntryReportCutStock =
      '/production/cutting-entry/reports/cut-stock';
  static const String cuttingEntryReportList =
      '/production/cutting-entry/reports/entry-report';
  static const String stitchingDelivery = '/production/stitching-delivery';
  static const String cuttingDailyPlan = '/production/cutting-daily-plan';
  static const String stitchingGrn = '/production/stitching-grn';
  static const String ironPackingDc = '/production/iron-packing-dc';
  static const String accessoriesItemAssign =
      '/production/accessories-item-assign';

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

  static String getImageUrl(dynamic path) {
    if (path == null || path.toString().isEmpty) return '';
    String imageUrl = path.toString();

    // If it's a full S3 URL or already absolute, return as is
    if (imageUrl.startsWith('http')) return imageUrl;

    // Handle relative paths: remove leading slash
    imageUrl = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;

    // Special Check for S3 URLs to solve CORS on Web
    if (imageUrl.startsWith('https://garments-app-storage.s3.us-east-1.amazonaws.com')) {
        // Return proxied URL
        return '${ApiConstants.serverUrl}/api/proxy-image?url=$imageUrl';
    }

    // If the path starts with 'uploads/', it's already properly formatted relative to serverUrl
    return '${ApiConstants.serverUrl}/$imageUrl';
  }
}
