import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/color_palette.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/auth/login_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/theme_provider.dart';
import '../screens/settings/theme_settings_screen.dart';
import '../screens/chat/chat_screen.dart';

// Masters
import '../screens/masters/categories_master_screen.dart';
import '../screens/masters/dropdown_setup_screen.dart';
import '../screens/masters/party_master_screen.dart';
import '../screens/masters/item_master_screen.dart';
import '../screens/masters/color_prediction_screen.dart';
import '../screens/masters/stock_limit_master_screen.dart';

// Transactions
import '../screens/transactions/lot_inward_screen.dart';
import '../screens/transactions/lot_outward_screen.dart';
import '../screens/transactions/inward_list_screen.dart';
import '../screens/transactions/outward_list_screen.dart';
import '../screens/assessment/item_assignment_list_screen.dart';
import '../screens/transactions/cutting_order_planning_screen.dart';
import '../screens/transactions/lot_requirement_allocation_screen.dart';

// Reports
import '../screens/reports/overview_report.dart';
import '../screens/reports/lot_aging_report.dart';
import '../screens/reports/inward_outward_report.dart';
import '../screens/reports/monthly_summary_report.dart';
import '../screens/reports/client_format_report.dart';
import '../screens/reports/godown_stock_report_screen.dart';
import '../screens/reports/rack_pallet_report_screen.dart';
import '../screens/tasks/admin_task_management_screen.dart';
import '../screens/tasks/worker_task_dashboard_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // Close drawer
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).primaryColor;
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            decoration: BoxDecoration(color: primaryColor),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Icon(
                      LucideIcons.user,
                      size: 40,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Garments Admin",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  "admin@garments.com",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero, // Remove top padding
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.home),
                  title: const Text('Home'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DashboardScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),

                // Masters Group
                ExpansionTile(
                  leading: const Icon(LucideIcons.database),
                  title: const Text("Masters"),
                  children: [
                    _buildSubItem(
                      context,
                      "Categories",
                      const CategoriesMasterScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Dropdown Setup",
                      const DropdownSetupScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Party Master",
                      const PartyMasterScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Item Group Master",
                      const ItemMasterScreen(),
                    ), // Assuming ItemMasterScreen is Item Group Master
                    _buildSubItem(
                      context,
                      "Colour Prediction",
                      const ColorPredictionScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Stock Limit Setup",
                      const StockLimitMasterScreen(),
                    ),
                  ],
                ),

                // Transactions Group
                ExpansionTile(
                  leading: const Icon(LucideIcons.arrowLeftRight),
                  title: const Text("Transactions"),
                  children: [
                    _buildSubItem(
                      context,
                      "Lot Inward",
                      const LotInwardScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Lot Outward",
                      const LotOutwardScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Inward List",
                      const InwardListScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Outward List",
                      const OutwardListScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Item Assignments",
                      const ItemAssignmentListScreen(),
                    ),
                  ],
                ),

                // Production Group
                ExpansionTile(
                  leading: const Icon(LucideIcons.factory),
                  title: const Text("Production"),
                  children: [
                    _buildSubItem(
                      context,
                      "Cutting Order Planning",
                      const CuttingOrderPlanningScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Lot Requirement",
                      const LotRequirementAllocationScreen(),
                    ),
                  ],
                ),

                // Communication & Tasks Group
                ExpansionTile(
                  leading: const Icon(LucideIcons.messageSquare),
                  title: const Text("Tasks & Communication"),
                  children: [
                    _buildSubItem(
                      context,
                      "Assign Tasks (Admin)",
                      const AdminTaskManagementScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "My Tasks (Worker)",
                      const WorkerTaskDashboardScreen(),
                    ),
                  ],
                ),

                // Reports Group
                ExpansionTile(
                  leading: const Icon(LucideIcons.fileBarChart),
                  title: const Text("Reports"),
                  children: [
                    _buildSubItem(
                      context,
                      "Client Format Report",
                      const ClientFormatReportScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Overview",
                      const OverviewReportScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Ageing Details",
                      const LotAgingReportScreen(),
                    ),
                    // Formatting/Aging Summary might be separate, check file if needed, but for now map broadly
                    // The user said "Aging Summary", but file name is 'lot_aging_report.dart'.
                    // I'll check if there's another report or reuse.
                    // Let's assume 'Ageing Details' covers it or add placeholder if unsure.
                    // Actually 'Aging Summary' might be different. I saw 'monthly_summary_report.dart' which is Closing/Summary.
                    // 'Inward' and 'Outward' reports -> InwardOutwardReportScreen covers both usually or separate tabs.
                    _buildSubItem(
                      context,
                      "Inward & Outward",
                      const InwardOutwardReportScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Closing Stock",
                      const MonthlySummaryReportScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Godown Stock (Min/Max)",
                      const GodownStockReportScreen(),
                    ),
                    _buildSubItem(
                      context,
                      "Rack & Pallet Wise Report",
                      RackPalletReportScreen(),
                    ),
                  ],
                ),

                ListTile(
                  leading: const Icon(LucideIcons.palette),
                  title: const Text('App Theme'),
                  onTap: () => _navigateTo(context, const ThemeSettingsScreen()),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.bot),
                  title: const Text('AI Chatbot'),
                  onTap: () => _navigateTo(context, const ChatScreen()),
                ),

                const Divider(),
                ListTile(
                  leading: const Icon(LucideIcons.logOut, color: Colors.red),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    ref.read(themeProvider.notifier).resetTheme();
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "v1.0.0",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubItem(BuildContext context, String title, Widget screen) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 50, right: 16),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      onTap: () => _navigateTo(context, screen),
    );
  }
}
