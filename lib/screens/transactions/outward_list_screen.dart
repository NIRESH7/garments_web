import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import 'outward_detail_screen.dart';

class OutwardListScreen extends StatefulWidget {
  const OutwardListScreen({super.key});

  @override
  State<OutwardListScreen> createState() => _OutwardListScreenState();
}

class _OutwardListScreenState extends State<OutwardListScreen> {
  final _api = MobileApiService();
  List<dynamic> _outwards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOutwards();
  }

  Future<void> _fetchOutwards() async {
    try {
      final res = await _api.getOutwards();
      setState(() {
        _outwards = res;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outward List'),
        backgroundColor: Colors.orange,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOutwards,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _outwards.isEmpty
            ? const Center(child: Text('No outward entries found'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _outwards.length,
                itemBuilder: (context, index) {
                  final item = _outwards[index];
                  final hasIncharge =
                      item['lotInchargeSignature'] != null &&
                      item['lotInchargeSignature'].toString().isNotEmpty;
                  final hasAuthorized =
                      item['authorizedSignature'] != null &&
                      item['authorizedSignature'].toString().isNotEmpty;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_shipping,
                          color: Colors.orange,
                        ),
                      ),
                      title: Text(
                        'DC: ${item['dcNo'] ?? 'N/A'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Lot: ${item['lotNo']} - ${item['lotName']}\nParty: ${item['partyName']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildSignIndicator(
                                Icons.person_pin,
                                hasIncharge,
                                'Incharge',
                              ),
                              const SizedBox(width: 8),
                              _buildSignIndicator(
                                Icons.verified_user,
                                hasAuthorized,
                                'Auth',
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OutwardDetailScreen(outward: item),
                          ),
                        );
                        _fetchOutwards();
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSignIndicator(IconData icon, bool active, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: active ? Colors.orange : Colors.grey.withOpacity(0.5),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? Colors.orange : Colors.grey.withOpacity(0.5),
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
