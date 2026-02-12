import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import 'item_master_screen.dart';

class ItemGroupHistoryScreen extends StatefulWidget {
  const ItemGroupHistoryScreen({super.key});

  @override
  State<ItemGroupHistoryScreen> createState() => _ItemGroupHistoryScreenState();
}

class _ItemGroupHistoryScreenState extends State<ItemGroupHistoryScreen> {
  final _api = MobileApiService();
  List<dynamic> _itemGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItemGroups();
  }

  Future<void> _fetchItemGroups() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getItemGroups();
      setState(() {
        _itemGroups = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to fetch item groups');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _deleteGroup(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this item group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _api.deleteItemGroup(id);
      if (success) {
        _fetchItemGroups();
      } else {
        _showError('Failed to delete group');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item Group History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _itemGroups.isEmpty
              ? const Center(child: Text('No item groups found'))
              : ListView.builder(
                  itemCount: _itemGroups.length,
                  itemBuilder: (context, index) {
                    final group = _itemGroups[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(group['groupName'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GSM: ${group['gsm']} | Rate: ${group['rate']}'),
                            Text('Items: ${(group['itemNames'] as List).join(", ")}'),
                            Text('Colours: ${(group['colours'] as List).join(", ")}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ItemMasterScreen(editGroup: group),
                                  ),
                                );
                                if (result == true) _fetchItemGroups();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteGroup(group['_id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
