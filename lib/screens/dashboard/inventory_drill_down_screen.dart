import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../core/utils/format_utils.dart';
import '../../services/mobile_api_service.dart';

class InventoryDrillDownScreen extends StatefulWidget {
  final String type; // 'opening', 'inward', 'outward', 'closing'
  final String? lotName;
  final String? lotNo;
  final String? dia;
  final String? setNo;
  final String? startDate;
  final String? endDate;

  const InventoryDrillDownScreen({
    super.key,
    required this.type,
    this.lotName,
    this.lotNo,
    this.dia,
    this.setNo,
    this.startDate,
    this.endDate,
  });

  @override
  State<InventoryDrillDownScreen> createState() => _InventoryDrillDownScreenState();
}

class _InventoryDrillDownScreenState extends State<InventoryDrillDownScreen> {
  final _api = MobileApiService();
  List<dynamic> _data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getInventoryDrillDown(
        type: widget.type,
        lotName: widget.lotName,
        lotNo: widget.lotNo,
        dia: widget.dia,
        setNo: widget.setNo,
        startDate: widget.startDate,
        endDate: widget.endDate,
      );
      setState(() {
        _data = res;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  String get _title {
    String t = widget.type.toUpperCase();
    if (widget.lotName != null) t = widget.lotName!;
    if (widget.lotNo != null) t = 'Lot No: ${widget.lotNo}';
    if (widget.dia != null) t = '${widget.dia} Dia Details';
    if (widget.setNo != null) t = '${widget.setNo} Details';
    return t;
  }

  String get _levelLabel {
    if (widget.lotName == null) return 'LOT NAME';
    if (widget.lotNo == null) return 'LOT NUMBER';
    if (widget.dia == null) return 'DIA';
    if (widget.setNo == null) return 'SET';
    return 'COLOR';
  }

  Color get _themeColor {
    switch (widget.type) {
      case 'inward':
        return ColorPalette.success;
      case 'outward':
        return ColorPalette.error;
      default:
        return ColorPalette.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: ColorPalette.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPathBreadcrumbs(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _data.isEmpty
                    ? _buildEmptyState()
                    : _buildDataTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildPathBreadcrumbs() {
    List<String> parts = [widget.type.toUpperCase()];
    if (widget.lotName != null) parts.add(widget.lotName!);
    if (widget.lotNo != null) parts.add('Lot ${widget.lotNo}');
    if (widget.dia != null) parts.add('${widget.dia}Φ');
    if (widget.setNo != null) parts.add(widget.setNo!);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: parts.asMap().entries.map((entry) {
            final isLast = entry.key == parts.length - 1;
            return Row(
              children: [
                Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                    color: isLast ? _themeColor : Colors.grey,
                  ),
                ),
                if (!isLast)
                  const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.packageOpen, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No inventory data found',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return Column(
      children: [
        // Header Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _themeColor.withOpacity(0.05),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(_levelLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              ),
              Expanded(
                flex: 1,
                child: Text('ROLLS',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text('WEIGHT',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text('VALUE',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
        ),
        // Data Body
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: _data.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final item = _data[index];
              return InkWell(
                onTap: widget.setNo != null ? null : () => _navigateToNextLevel(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] ?? 'N/A',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.setNo != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Rack: ${item['rack'] ?? 'N/A'} | Pallet: ${item['pallet'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              Text(
                                'GSM: ${item['gsm'] ?? 'N/A'} | Inw: ${item['inwardNo'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                            if (widget.setNo == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Tap to view details',
                                  style: TextStyle(fontSize: 10, color: _themeColor.withOpacity(0.7)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          item['totalRolls'].toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${item['totalWeight']} Kg',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₹${FormatUtils.formatCurrency(item['totalValue'])}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: ColorPalette.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _navigateToNextLevel(dynamic item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryDrillDownScreen(
          type: widget.type,
          startDate: widget.startDate,
          endDate: widget.endDate,
          lotName: widget.lotName ?? item['name'],
          lotNo: widget.lotName != null ? (widget.lotNo ?? item['name']) : null,
          dia: (widget.lotName != null && widget.lotNo != null) ? (widget.dia ?? item['name']) : null,
          setNo: (widget.lotName != null && widget.lotNo != null && widget.dia != null) ? (widget.setNo ?? item['name']) : null,
        ),
      ),
    );
  }
}
