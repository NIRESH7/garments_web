import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import 'party_master_screen.dart';

class PartyHistoryScreen extends StatefulWidget {
  const PartyHistoryScreen({super.key});

  @override
  State<PartyHistoryScreen> createState() => _PartyHistoryScreenState();
}

class _PartyHistoryScreenState extends State<PartyHistoryScreen> {
  final _api = MobileApiService();
  List<dynamic> _parties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchParties();
  }

  Future<void> _fetchParties() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getParties();
      setState(() {
        _parties = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to fetch parties');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _deleteParty(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this party?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _api.deleteParty(id);
      if (success) {
        _fetchParties();
      } else {
        _showError('Failed to delete party');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Party History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _parties.isEmpty
              ? const Center(child: Text('No parties found'))
              : ListView.builder(
                  itemCount: _parties.length,
                  itemBuilder: (context, index) {
                    final party = _parties[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(party['name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Process: ${party['process']} | Rate: ${party['rate']}'),
                            Text('Mobile: ${party['mobileNumber']}'),
                            Text('GST: ${party['gstIn']}'),
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
                                    builder: (context) => PartyMasterScreen(editParty: party),
                                  ),
                                );
                                if (result == true) _fetchParties();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteParty(party['_id']),
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
