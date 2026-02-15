import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';
import '../masters/masters_dashboard.dart';
import '../transactions/lot_inward_screen.dart';
import '../transactions/lot_outward_screen.dart';
import '../reports/reports_dashboard.dart';
import '../auth/login_screen.dart';
import '../dashboard/notifications_screen.dart';
import '../assessment/item_assignment_list_screen.dart';
import '../transactions/inward_list_screen.dart';
import '../transactions/outward_list_screen.dart';
import '../../widgets/app_drawer.dart';
import '../reports/godown_stock_report_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.background,
      body: IndexedStack(
        index: _pageIndex,
        children: [
          const _DynamicDataHomeTab(),
          const MastersDashboard(),
          const _TransactionPlaceholder(),
          const ItemAssignmentListScreen(),
          const ReportsDashboard(),
        ],
      ),
      drawer: const AppDrawer(),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: CurvedNavigationBar(
          backgroundColor: Colors.transparent,
          color: Colors.white,
          buttonBackgroundColor: Colors.white,
          height: 65,
          index: _pageIndex,
          items: <Widget>[
            Icon(
              LucideIcons.home,
              size: 26,
              color: _pageIndex == 0
                  ? ColorPalette.primary
                  : ColorPalette.textSecondary,
            ),
            Icon(
              LucideIcons.database,
              size: 26,
              color: _pageIndex == 1
                  ? ColorPalette.primary
                  : ColorPalette.textSecondary,
            ),
            Icon(
              LucideIcons.arrowUpDown,
              size: 26,
              color: _pageIndex == 2
                  ? ColorPalette.primary
                  : ColorPalette.textSecondary,
            ),
            Icon(
              LucideIcons.clipboardCheck,
              size: 26,
              color: _pageIndex == 3
                  ? ColorPalette.primary
                  : ColorPalette.textSecondary,
            ),
            Icon(
              LucideIcons.barChart3,
              size: 26,
              color: _pageIndex == 4
                  ? ColorPalette.primary
                  : ColorPalette.textSecondary,
            ),
          ],
          animationDuration: const Duration(milliseconds: 300),
          onTap: (index) {
            if (index == 2) {
              _showTransactionsMenu(context);
            } else {
              setState(() {
                _pageIndex = index;
              });
            }
          },
        ),
      ),
    );
  }

  void _showTransactionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Stock Transactions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ColorPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            _TransactionTile(
              title: 'Lot Inward',
              subtitle: 'Add new rolls to inventory',
              icon: LucideIcons.download,
              color: ColorPalette.success,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LotInwardScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _TransactionTile(
              title: 'Lot Outward',
              subtitle: 'Dispatch items and create DC',
              icon: LucideIcons.upload,
              color: ColorPalette.error,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LotOutwardScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DynamicDataHomeTab extends StatefulWidget {
  const _DynamicDataHomeTab();

  @override
  State<_DynamicDataHomeTab> createState() => _DynamicDataHomeTabState();
}

class _DynamicDataHomeTabState extends State<_DynamicDataHomeTab> {
  final _api = MobileApiService();
  List<dynamic> _recentInwards = [];
  Map<String, dynamic> _stats = {
    'total_lots': 0,
    'total_inward_weight': '0.00',
    'total_outward_weight': '0.00',
    'total_assignments': 0,
    'low_stock_count': 0,
  };
  String _userName = 'User';
  String _unreadCount = '0';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final res = await _api.getHomeDashboard();
      setState(() {
        _stats = res['metrics'] ?? _stats;
        _recentInwards = res['recentInwards'] ?? [];
        _userName = res['user']?['name'] ?? 'User';
        _unreadCount = (res['unreadNotificationsCount'] ?? 0).toString();
        _isLoading = false;
      });
      _fetchStockAlerts();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchStockAlerts() async {
    try {
      final stockData = await _api.getGodownStockReport();
      final lowStock = stockData
          .where((d) => d['status'] == 'LOW STOCK')
          .length;
      setState(() {
        _stats['low_stock_count'] = lowStock;
      });
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchStats,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 32),
              const Text(
                'Inventory Overview',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ColorPalette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Real-time metrics from your manufacturing process',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildStatsGrid(),
              if (_stats['low_stock_count'] > 0) ...[
                const SizedBox(height: 24),
                _buildStockAlertBanner(),
              ],
              const SizedBox(height: 40),
              _buildRecentInwards(),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(LucideIcons.menu, size: 24),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: ColorPalette.softShadow,
              ),
              child: const CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(
                  'https://i.pravatar.cc/150?u=deepak',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRODUCTION',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Hi, $_userName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: ColorPalette.softShadow,
                ),
                child: Badge(
                  label: Text(_unreadCount),
                  child: const Icon(
                    LucideIcons.bell,
                    size: 22,
                    color: ColorPalette.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          'Logout',
                          style: TextStyle(color: ColorPalette.error),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: ColorPalette.softShadow,
                ),
                child: const Icon(
                  LucideIcons.logOut,
                  size: 22,
                  color: ColorPalette.error,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _StatCard(
          title: 'Total Lots',
          value: _stats['total_lots'].toString(),
          icon: LucideIcons.package,
          color: ColorPalette.primary,
        ),
        _StatCard(
          title: 'Stock Weight',
          value: '${_stats['total_inward_weight']} Kg',
          icon: LucideIcons.layers,
          color: ColorPalette.success,
        ),
        _StatCard(
          title: 'Dispatched',
          value: '${_stats['total_outward_weight']} Kg',
          icon: LucideIcons.truck,
          color: Colors.orange,
        ),
        _StatCard(
          title: 'Assignments',
          value: _stats['total_assignments'].toString(),
          icon: LucideIcons.clipboardCheck,
          color: Colors.purple,
        ),
      ].animate(interval: 50.ms).fadeIn().slideY(begin: 0.1),
    );
  }

  Widget _buildStockAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.alertTriangle,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_stats['low_stock_count']} Items Low in Stock',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const Text(
                  'Replenishment required immediately.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // Navigate to report
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GodownStockReportScreen(),
                ),
              );
            },
            child: const Text(
              'VIEW',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentInwards() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: ColorPalette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Inwards',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ColorPalette.textPrimary,
                ),
              ),
              Icon(LucideIcons.history, size: 16, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 20),
          if (_recentInwards.isEmpty)
            const Text(
              'No recent inward transactions found.',
              style: TextStyle(color: ColorPalette.textMuted, fontSize: 13),
            ),
          ..._recentInwards.map(
            (inward) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lot #${inward['lot_number']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${inward['from_party']}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${inward['total_weight']} Kg',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ColorPalette.success,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: ColorPalette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ColorPalette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TransactionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade100),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: ColorPalette.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionPlaceholder extends StatelessWidget {
  const _TransactionPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
