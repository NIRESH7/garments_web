import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';

class AccessoriesItemAssignScreen extends StatefulWidget {
  const AccessoriesItemAssignScreen({super.key});
  @override
  State<AccessoriesItemAssignScreen> createState() => _AccessoriesItemAssignScreenState();
}

class _AccessoriesItemAssignScreenState extends State<AccessoriesItemAssignScreen> {
  final _api = MobileApiService();
  List<dynamic> _assigns = [];
  bool _loading = true;
  final _itemNameCtrl = TextEditingController();
  List<Map<String, dynamic>> _accessoryRows = [];
  bool _saving = false;

  final List<String> _sizeOptions = ['75', '80', '85', '90', '95', '100', '105', '110'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _api.getAccessoriesItemAssigns();
    setState(() {
      _assigns = data;
      _loading = false;
    });
  }

  void _loadAssign(Map<String, dynamic> assign) {
    _itemNameCtrl.text = assign['itemName'] ?? '';
    _accessoryRows = List<Map<String, dynamic>>.from(
      (assign['accessories'] as List?)?.map((a) => Map<String, dynamic>.from(a as Map)) ?? [],
    );
    setState(() {});
  }

  void _addAccessoryRow() {
    setState(() {
      _accessoryRows.add({
        'accessoriesGroup': '',
        'accessoriesName': '',
        'sizeWiseQty': _sizeOptions.map((s) => {'size': s, 'qtyPerPcs': 0.0}).toList(),
      });
    });
  }

  Future<void> _save() async {
    if (_itemNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter item name'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    final data = {
      'itemName': _itemNameCtrl.text.trim(),
      'accessories': _accessoryRows,
    };
    final ok = await _api.saveAccessoriesItemAssign(data);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Saved!' : 'Failed to save'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) {
        _load();
        _itemNameCtrl.clear();
        _accessoryRows.clear();
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Accessories Item Assignment', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Existing assigns
            const Text('Existing Assignments',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _assigns.isEmpty
                    ? Text('No assignments yet.', style: TextStyle(color: Colors.grey.shade500))
                    : SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _assigns.length,
                          itemBuilder: (_, i) {
                            final a = _assigns[i];
                            return GestureDetector(
                              onTap: () => _loadAssign(a as Map<String, dynamic>),
                              child: Card(
                                margin: const EdgeInsets.only(right: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: Container(
                                  width: 140,
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.inventory_2, color: Theme.of(context).primaryColor),
                                      const SizedBox(height: 8),
                                      Text(a['itemName'] ?? '-',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          maxLines: 2, overflow: TextOverflow.ellipsis),
                                      Text('${(a['accessories'] as List?)?.length ?? 0} accessories',
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
            const SizedBox(height: 20),
            // Form
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign Accessories to Item',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _itemNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Item Name *',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Accessories',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add', overflow: TextOverflow.ellipsis),
                            onPressed: _addAccessoryRow,
                          ),
                        ),
                      ],
                    ),
                    ..._accessoryRows.asMap().entries.map((e) {
                      final i = e.key;
                      final row = e.value;
                      final sizeQtys = (row['sizeWiseQty'] as List?) ?? [];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        color: Colors.grey.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: row['accessoriesName'] ?? '',
                                      decoration: const InputDecoration(
                                        labelText: 'Accessory Name',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (v) => _accessoryRows[i]['accessoriesName'] = v,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: row['accessoriesGroup'] ?? '',
                                      decoration: const InputDecoration(
                                        labelText: 'Group',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (v) => _accessoryRows[i]['accessoriesGroup'] = v,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    onPressed: () => setState(() => _accessoryRows.removeAt(i)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Size-wise qty
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(sizeQtys.length, (si) {
                                  final sq = sizeQtys[si] as Map;
                                  return SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      initialValue: (sq['qtyPerPcs'] ?? 0).toString(),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: sq['size']?.toString() ?? '',
                                        labelStyle: const TextStyle(fontSize: 11),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      onChanged: (v) {
                                        (_accessoryRows[i]['sizeWiseQty'] as List)[si]['qtyPerPcs'] =
                                            double.tryParse(v) ?? 0;
                                      },
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Assignment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
