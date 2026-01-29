import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import '../../core/theme/color_palette.dart';
import '../../services/database_service.dart';
import '../masters/masters_dashboard.dart';
import '../transactions/lot_inward_screen.dart';
import '../transactions/lot_outward_screen.dart';
import '../reports/reports_dashboard.dart';
import '../auth/login_screen.dart';
import '../dashboard/notifications_screen.dart';
import '../assessment/item_assignment_list_screen.dart';

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
  final _db = DatabaseService();
  List<Map<String, dynamic>> _recentInwards = [];
  Map<String, dynamic> _stats = {
    'total_lots': 0,
    'total_inward_weight': 0.0,
    'total_outward_weight': 0.0,
    'total_assignments': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final db = await _db.database;

    final lotsRes = await db.rawQuery('SELECT COUNT(*) as count FROM lots');
    final inwardRes = await db.rawQuery(
      'SELECT SUM(weight) as total FROM inward_rows',
    );
    final outwardRes = await db.rawQuery(
      'SELECT SUM(weight) as total FROM outward_items',
    );
    final assignRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM item_assignments',
    );

    final recentIn = await db.rawQuery('''
      SELECT i.lot_number, i.from_party, i.created_at, SUM(r.weight) as total_weight 
      FROM inwards i
      JOIN inward_rows r ON i.id = r.inward_id
      GROUP BY i.id
      ORDER BY i.created_at DESC
      LIMIT 3
    ''');

    setState(() {
      _stats = {
        'total_lots': lotsRes.first['count'] ?? 0,
        'total_inward_weight': inwardRes.first['total'] ?? 0.0,
        'total_outward_weight': outwardRes.first['total'] ?? 0.0,
        'total_assignments': assignRes.first['count'] ?? 0,
      };
      _recentInwards = recentIn;
      _isLoading = false;
    });
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
                const Text(
                  'Hi, Sudha',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                child: const Badge(
                  label: Text('1'),
                  child: Icon(
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
