import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/responsive_layout_shell.dart';
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
import 'inventory_drill_down_screen.dart';
// ── New Module Imports ──────────────────────────────────────────────────
import '../cutting_entry/cutting_entry_list_screen.dart';
import '../cutting_entry/cutting_daily_plan_screen.dart';
import '../stitching/stitching_delivery_screen.dart';
import '../packing/iron_packing_dc_screen.dart';
import '../reports/cut_stock_report_screen.dart';
import '../reports/cutting_entry_report_screen.dart';
// ────────────────────────────────────────────────────────────────────────
import '../settings/scale_settings_screen.dart';
import '../settings/theme_settings_screen.dart';
import '../chat/chat_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _pageIndex = 0;
  final GlobalKey<InwardListScreenState> _inwardKey = GlobalKey<InwardListScreenState>();

  String _getShellTitle() {
    switch (_pageIndex) {
      case 0: return 'Executive Dashboard';
      case 1: return 'Masters Dashboard';
      case 2: return 'Inward Transactions';
      case 3: return 'Outward Transactions';
      case 4: return 'Task Management';
      case 5: return 'Item Assignments';
      case 6: return 'Cutting Planning';
      case 7: return 'Reports Dashboard';
      default: return 'Executive Dashboard';
    }
  }

  List<Widget>? _getHeaderActions() {
    if (_pageIndex == 2) {
      return [
        IconButton(
          onPressed: () => _inwardKey.currentState?.fetchInwards(),
          icon: const Icon(LucideIcons.refreshCw, size: 16, color: ColorPalette.textMuted),
          tooltip: 'REFRESH INWARDS',
        ),
      ];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutShell(
      title: _getShellTitle(),
      headerActions: _getHeaderActions(),
      selectedIndex: _pageIndex,
      onIndexChanged: (index) {
        if (LayoutConstants.isWeb(context)) {
          if (index >= 9) {
            // Handle System/Settings as Navigation
            Widget target;
            switch (index) {
              case 9: target = const ScaleSettingsScreen(); break;
              case 10: target = const ThemeSettingsScreen(); break;
              case 11: target = const ChatScreen(); break;
              default: return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (context) => target));
            return;
          }
          setState(() => _pageIndex = index);
        } else {
          if (index == 2) {
            _showTransactionsMenu(context);
          } else {
            setState(() {
              _pageIndex = index;
            });
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _pageIndex >= 9 ? 0 : _pageIndex, // Keep on home if navigating away
          children: [
            const _DynamicDataHomeTab(),              // 0
            const MastersDashboard(),                 // 1
            InwardListScreen(key: _inwardKey),        // 2
            const OutwardListScreen(),                // 3
            const WorkerTaskDashboardScreen(),        // 4
            const ItemAssignmentListScreen(),         // 5
            const CuttingOrderPlanningScreen(),       // 6
            const ReportsDashboard(),                 // 7
            const _HistoryPlaceholder(),              // 8
          ],
        ),
        bottomNavigationBar: LayoutConstants.isMobile(context) 
          ? DecoratedBox(
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
            )
          : null,
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
    final isWeb = LayoutConstants.isWeb(context);
    
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchStats,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWeb ? 32.0 : 24.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWeb ? LayoutConstants.maxContentWidth : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Stock Summary',
                      style: GoogleFonts.inter(
                        fontSize: isWeb ? 24 : 18,
                        fontWeight: FontWeight.w700,
                        color: ColorPalette.textPrimary,
                      ),
                    ),
                    InkWell(
                      onTap: _showFilterDialog,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: ColorPalette.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.filter, size: 14, color: ColorPalette.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'FILTER',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ColorPalette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_startDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Chip(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: ColorPalette.border),
                      label: Text(
                        '${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
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
                SizedBox(height: isWeb ? 32 : 20),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildStockSummaryGrid(),
                if ((_stats['low_stock_count'] ?? 0) > 0) ...[
                  SizedBox(height: isWeb ? 32 : 24),
                  _buildStockAlertBanner(),
                ],
                SizedBox(height: isWeb ? 48 : 40),
                _buildRecentInwards(),
                SizedBox(height: isWeb ? 80 : 120),
              ],
            ),
          ),
        ),
      ),
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
    final isWeb = LayoutConstants.isWeb(context);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isWeb ? 4 : 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: isWeb ? 1.6 : 2.2,
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
                builder: (context) => InventoryDrillDownScreen(
                  type: 'opening',
                  startDate: _startDate?.toIso8601String(),
                  endDate: _endDate?.toIso8601String(),
                ),
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
                builder: (context) => InventoryDrillDownScreen(
                  type: 'inward',
                  startDate: _startDate?.toIso8601String(),
                  endDate: _endDate?.toIso8601String(),
                ),
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
                builder: (context) => InventoryDrillDownScreen(
                  type: 'outward',
                  startDate: _startDate?.toIso8601String(),
                  endDate: _endDate?.toIso8601String(),
                ),
              ),
            );
          },
        ),
        _StockCard(
          title: 'Closing Stock',
          weight: _summary['closing']['weight'],
          rolls: _summary['closing']['rolls'],
          color: ColorPalette.primary,
          icon: LucideIcons.checkCircle2,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InventoryDrillDownScreen(
                  type: 'closing',
                  startDate: _startDate?.toIso8601String(),
                  endDate: _endDate?.toIso8601String(),
                ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT INWARD TRANSACTIONS',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.5,
                  color: ColorPalette.textMuted,
                ),
              ),
              Icon(LucideIcons.history, size: 14, color: ColorPalette.textMuted),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentInwards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No recent transactions found.',
                  style: GoogleFonts.inter(color: ColorPalette.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentInwards.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: ColorPalette.border, thickness: 0.5),
              itemBuilder: (context, index) {
                final inward = _recentInwards[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ColorPalette.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.package, size: 16, color: ColorPalette.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lot #${inward['lot_number']}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: ColorPalette.textPrimary,
                              ),
                            ),
                            Text(
                              '${inward['from_party']}'.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: ColorPalette.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${FormatUtils.formatWeight(inward['total_weight'])} Kg',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: ColorPalette.textPrimary,
                            ),
                          ),
                          Text(
                            'INWARD SUCCESS',
                            style: GoogleFonts.inter(
                              color: ColorPalette.success,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorPalette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: ColorPalette.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${FormatUtils.formatWeight(weight)} Kg',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ColorPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${FormatUtils.formatQuantity(rolls)} ROLLS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: ColorPalette.textSecondary,
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _HistoryPlaceholder extends StatelessWidget {
  const _HistoryPlaceholder();
  @override
  Widget build(BuildContext context) => const Center(child: Text("History Module Coming Soon"));
}
