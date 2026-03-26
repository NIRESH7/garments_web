import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../services/mobile_api_service.dart';
import '../masters/masters_dashboard.dart';
import '../transactions/lot_inward_screen.dart';
import '../transactions/lot_outward_screen.dart';
import '../transactions/inward_list_screen.dart';
import '../transactions/outward_list_screen.dart';
import '../reports/reports_dashboard.dart';
import '../auth/login_screen.dart';
import '../dashboard/notifications_screen.dart';
import '../assessment/item_assignment_list_screen.dart';
import '../transactions/lot_complaint_solution_screen.dart';
import '../transactions/cutting_order_planning_screen.dart';
import '../transactions/lot_requirement_allocation_screen.dart';
import '../tasks/worker_task_dashboard_screen.dart';
import '../../widgets/app_drawer.dart';
import '../reports/godown_stock_report_screen.dart';
import '../reports/monthly_summary_report.dart';
// ── New Module Imports ──────────────────────────────────────────────────
import '../cutting_entry/cutting_entry_list_screen.dart';
import '../cutting_entry/cutting_daily_plan_screen.dart';
import '../stitching/stitching_delivery_screen.dart';
import '../packing/iron_packing_dc_screen.dart';
import '../assessment/accessories_item_assign_screen.dart';
import '../reports/cut_stock_report_screen.dart';
import '../reports/cutting_entry_report_screen.dart';
// ────────────────────────────────────────────────────────────────────────

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
                  ? Theme.of(context).primaryColor
                  : ColorPalette.textSecondary,
            ),
            Icon(
              LucideIcons.database,
              size: 26,
              color: _pageIndex == 1
                  ? Theme.of(context).primaryColor
                  : ColorPalette.textSecondary,
            ),
            Icon(
              LucideIcons.arrowUpDown,
              size: 26,
              color: _pageIndex == 2
                  ? Theme.of(context).primaryColor
                  : ColorPalette.textSecondary,
            ),
            Icon(
              LucideIcons.clipboardCheck,
              size: 26,
              color: _pageIndex == 3
                  ? Theme.of(context).primaryColor
                  : ColorPalette.textSecondary,
            ),
            Icon(
              LucideIcons.barChart3,
              size: 26,
              color: _pageIndex == 4
                  ? Theme.of(context).primaryColor
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
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
                            builder: (context) => const InwardListScreen(),
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
                            builder: (context) => const OutwardListScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _TransactionTile(
                      title: 'Complaint Solution',
                      subtitle: 'Resolve and clear quality issues',
                      icon: LucideIcons.shieldCheck,
                      color: Theme.of(context).primaryColor,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LotComplaintSolutionScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _TransactionTile(
                      title: 'Cutting Planning',
                      subtitle: 'Create monthly/yearly plans',
                      icon: LucideIcons.calendar,
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CuttingOrderPlanningScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _TransactionTile(
                      title: 'Lot Requirement',
                      subtitle: 'FIFO Lot Assignment',
                      icon: LucideIcons.layoutGrid,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const LotRequirementAllocationScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _TransactionTile(
                      title: 'Task Management',
                      subtitle: 'Assign & track lab/factory tasks',
                      icon: LucideIcons.checkSquare,
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WorkerTaskDashboardScreen(),
                          ),
                        );
                      },
                    ),
                    // ── NEW PRODUCTION MODULE TILES ─────────────────────────
                    const Padding(
                      padding: EdgeInsets.only(top: 24, bottom: 8),
                      child: Text('Production Modules',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2)),
                    ),
                    _TransactionTile(
                      title: 'Cutting Entry',
                      subtitle: 'Colour-wise lay & weight tracking',
                      icon: LucideIcons.scissors,
                      color: Colors.teal,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CuttingEntryListScreen()));
                      },
                    ),
                    const SizedBox(height: 12),
                    _TransactionTile(
                      title: 'Cutting Daily Plan',
                      subtitle: 'Daily cutting schedule board',
                      icon: LucideIcons.calendarDays,
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CuttingDailyPlanScreen()));
                      },
                    ),
                    const SizedBox(height: 12),
                    _TransactionTile(
                      title: 'Stitching Delivery DC',
                      subtitle: 'DC for cut pieces to stitching',
                      icon: LucideIcons.truck,
                      color: Colors.cyan.shade700,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const StitchingDeliveryScreen()));
                      },
                    ),
                    const SizedBox(height: 12),
                    _TransactionTile(
                      title: 'Iron & Packing DC',
                      subtitle: 'Packing outward DC / inward GRN',
                      icon: LucideIcons.box,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const IronPackingDcScreen()));
                      },
                    ),
                    const SizedBox(height: 12),
                    _TransactionTile(
                      title: 'Accessories Assignment',
                      subtitle: 'Link accessories to items',
                      icon: LucideIcons.link2,
                      color: Colors.pink,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AccessoriesItemAssignScreen()));
                      },
                    ),
                    const SizedBox(height: 12),
                    _TransactionTile(
                      title: 'Cut Stock Report',
                      subtitle: 'Size-wise cut dozen inventory',
                      icon: LucideIcons.barChart2,
                      color: Colors.green.shade700,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CutStockReportScreen()));
                      },
                    ),
                    const SizedBox(height: 12),
                    _TransactionTile(
                      title: 'Cutting Entry Report',
                      subtitle: 'Detailed cut colour-wise report',
                      icon: LucideIcons.fileText,
                      color: Colors.indigo.shade400,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CuttingEntryReportScreen()));
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DynamicDataHomeTab extends ConsumerStatefulWidget {
  const _DynamicDataHomeTab();

  @override
  ConsumerState<_DynamicDataHomeTab> createState() =>
      _DynamicDataHomeTabState();
}

class _DynamicDataHomeTabState extends ConsumerState<_DynamicDataHomeTab> {
  final _api = MobileApiService();
  Map<String, dynamic> _summary = {
    'opening': {'weight': '0.00', 'rolls': 0},
    'inward': {'weight': '0.00', 'rolls': 0},
    'outward': {'weight': '0.00', 'rolls': 0},
    'closing': {'weight': '0.00', 'rolls': 0},
  };
  List<dynamic> _recentInwards = [];
  Map<String, dynamic> _stats = {
    'total_lots': 0,
    'total_inward_weight': '0.00',
    'total_outward_weight': '0.00',
    'total_assignments': 0,
    'low_stock_count': 0,
  };
  String _userName = 'User';
  String? _avatarUrl;
  String _unreadCount = '0';
  DateTime? _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime? _endDate = DateTime.now();
  String? _lotNameFilter;
  String? _diaFilter;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getHomeDashboard(
        startDate: _startDate?.toIso8601String(),
        endDate: _endDate?.toIso8601String(),
        lotName: _lotNameFilter,
        dia: _diaFilter,
      );
      setState(() {
        _stats = res['metrics'] ?? _stats;
        _summary = res['summary'] ?? _summary;
        _recentInwards = res['recentInwards'] ?? [];
        _userName = res['user']?['name'] ?? 'User';
        _avatarUrl = res['user']?['avatar'];
        _unreadCount = (res['unreadNotificationsCount'] ?? 0).toString();
        _isLoading = false;
      });
      _fetchStockAlerts();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchStats();
    }
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Stock Summary',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: ColorPalette.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.filter),
                    onPressed: _showFilterDialog,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
              if (_startDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Chip(
                    label: Text(
                      '${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month}',
                    ),
                    onDeleted: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      _fetchStats();
                    },
                  ),
                ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildStockSummaryGrid(),
              if ((_stats['low_stock_count'] ?? 0) > 0) ...[
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
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.1),
                backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? NetworkImage(ApiConstants.getImageUrl(_avatarUrl))
                    : null,
                child: _avatarUrl == null || _avatarUrl!.isEmpty
                    ? Text(
                        _userName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      )
                    : null,
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
                          ref.read(themeProvider.notifier).resetTheme();
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Dashboard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Select Date Range'),
              trailing: const Icon(LucideIcons.calendar),
              subtitle: _startDate != null
                  ? Text(
                      '${_startDate!.day}/${_startDate!.month} to ${_endDate!.day}/${_endDate!.month}',
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                _selectDateRange();
              },
            ),
            const Divider(),
            TextField(
              decoration: const InputDecoration(labelText: 'Lot Name'),
              onChanged: (val) => _lotNameFilter = val,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'DIA'),
              onChanged: (val) => _diaFilter = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _lotNameFilter = null;
                _diaFilter = null;
                _startDate = null;
                _endDate = null;
              });
              Navigator.pop(context);
              _fetchStats();
            },
            child: const Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _fetchStats();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSummaryGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.9,
      children: [
        _StockCard(
          title: 'Opening Stock',
          weight: _summary['opening']['weight'],
          rolls: _summary['opening']['rolls'],
          color: Theme.of(context).primaryColor,
          icon: LucideIcons.box,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MonthlySummaryReportScreen(),
              ),
            );
          },
        ),
        _StockCard(
          title: 'Inward',
          weight: _summary['inward']['weight'],
          rolls: _summary['inward']['rolls'],
          color: ColorPalette.success,
          icon: LucideIcons.arrowDownCircle,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InwardListScreen(),
              ),
            );
          },
        ),
        _StockCard(
          title: 'Outward',
          weight: _summary['outward']['weight'],
          rolls: _summary['outward']['rolls'],
          color: ColorPalette.error,
          icon: LucideIcons.arrowUpCircle,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OutwardListScreen(),
              ),
            );
          },
        ),
        _StockCard(
          title: 'Closing Stock',
          weight: _summary['closing']['weight'],
          rolls: _summary['closing']['rolls'],
          color: Theme.of(context).primaryColor.withOpacity(0.8),
          icon: LucideIcons.layers,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MonthlySummaryReportScreen(),
              ),
            );
          },
        ),
      ],
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
                  '${_stats['low_stock_count'] ?? 0} Items Low in Stock',
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
                    '${FormatUtils.formatWeight(inward['total_weight'])} Kg',
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

class _StockCard extends StatelessWidget {
  final String title;
  final dynamic weight;
  final dynamic rolls;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StockCard({
    required this.title,
    required this.weight,
    required this.rolls,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: ColorPalette.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${FormatUtils.formatWeight(weight)} Kg',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ColorPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${FormatUtils.formatQuantity(rolls)} Rolls',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
