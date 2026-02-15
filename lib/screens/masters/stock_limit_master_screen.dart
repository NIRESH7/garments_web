import 'package:flutter/material.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/custom_dropdown_field.dart';
import 'package:lucide_icons/lucide_icons.dart';

class StockLimitMasterScreen extends StatefulWidget {
  const StockLimitMasterScreen({super.key});

  @override
  State<StockLimitMasterScreen> createState() => _StockLimitMasterScreenState();
}

class _StockLimitMasterScreenState extends State<StockLimitMasterScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();

  String? _selectedLotName;
  String? _selectedDia;
  final _minWeightController = TextEditingController();
  final _maxWeightController = TextEditingController();
  final _manualAdjustmentController = TextEditingController();

  List<String> _lotNames = [];
  List<String> _dias = [];
  List<dynamic> _currentLimits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final categories = await _api.getCategories();
      final limits = await _api.getStockLimits();

      setState(() {
        _lotNames = _getValues(categories, 'Lot Name');
        _dias = _getValues(categories, 'dia');
        _currentLimits = limits;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _getValues(List<dynamic> categories, String name) {
    try {
      final match = categories.firstWhere(
        (c) => (c['name'] ?? '').toString().toLowerCase() == name.toLowerCase(),
        orElse: () => null,
      );
      if (match == null) return [];
      final vals = match['values'] as List;
      return vals.map((v) => v['name'].toString()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final success = await _api.saveStockLimit({
        'lotName': _selectedLotName,
        'dia': _selectedDia,
        'minWeight': double.tryParse(_minWeightController.text) ?? 0,
        'maxWeight': double.tryParse(_maxWeightController.text) ?? 0,
        'manualAdjustment':
            double.tryParse(_manualAdjustmentController.text) ?? 0,
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock Limit Saved Successfully')),
        );
        _loadData();
        _formKey.currentState!.reset();
        _minWeightController.clear();
        _maxWeightController.clear();
        _manualAdjustmentController.clear();
        setState(() {
          _selectedLotName = null;
          _selectedDia = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _editLimit(dynamic limit) {
    setState(() {
      _selectedLotName = limit['lotName'];
      _selectedDia = limit['dia'];
      _minWeightController.text = limit['minWeight'].toString();
      _maxWeightController.text = limit['maxWeight'].toString();
      _manualAdjustmentController.text = (limit['manualAdjustment'] ?? 0)
          .toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Stock Limit Setup'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildForm(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.list,
                        size: 18,
                        color: ColorPalette.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'EXISTING LIMITS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: ColorPalette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildLimitList()),
              ],
            ),
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add / Update Limits',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              CustomDropdownField(
                label: 'Lot Name',
                value: _selectedLotName,
                items: _lotNames,
                onChanged: (v) => setState(() => _selectedLotName = v),
              ),
              const SizedBox(height: 12),
              CustomDropdownField(
                label: 'DIA',
                value: _selectedDia,
                items: _dias,
                onChanged: (v) => setState(() => _selectedDia = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minWeightController,
                      decoration: InputDecoration(
                        labelText: 'Min Weight (Kg)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          LucideIcons.arrowDownToLine,
                          size: 18,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxWeightController,
                      decoration: InputDecoration(
                        labelText: 'Max Weight (Kg)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          LucideIcons.arrowUpToLine,
                          size: 18,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _manualAdjustmentController,
                decoration: InputDecoration(
                  labelText: 'Outside Input / Manual Adj (Kg)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(LucideIcons.plusCircle, size: 18),
                  hintText: 'Add manual stock adjustment...',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(LucideIcons.save, size: 18),
                  label: const Text(
                    'Save Stock Limit',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorPalette.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLimitList() {
    if (_currentLimits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.packageX, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No limits defined yet',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _currentLimits.length,
      itemBuilder: (context, index) {
        final limit = _currentLimits[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ColorPalette.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.settings,
                color: ColorPalette.primary,
                size: 20,
              ),
            ),
            title: Text(
              '${limit['lotName']} - DIA ${limit['dia']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Badge(
                      label: 'MIN: ${limit['minWeight']}kg',
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    _Badge(
                      label: 'MAX: ${limit['maxWeight']}kg',
                      color: Colors.orange,
                    ),
                  ],
                ),
                if (limit['manualAdjustment'] != 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Manual Adj: ${limit['manualAdjustment']} kg',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(LucideIcons.edit2, size: 18, color: Colors.grey),
              onPressed: () => _editLimit(limit),
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
