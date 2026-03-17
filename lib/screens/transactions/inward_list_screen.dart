import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import '../../core/constants/api_constants.dart';
import 'package:intl/intl.dart';
import 'inward_detail_screen.dart';
import 'lot_inward_screen.dart';

class InwardListScreen extends StatefulWidget {
  const InwardListScreen({super.key});

  @override
  State<InwardListScreen> createState() => _InwardListScreenState();
}

class _InwardListScreenState extends State<InwardListScreen> {
  final _api = MobileApiService();
  List<dynamic> _inwards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInwards();
  }

  Future<void> _fetchInwards() async {
    try {
      final res = await _api.getInwards();
      setState(() {
        _inwards = res;
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
        title: const Text('Inward List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LotInwardScreen(),
                ),
              );
              _fetchInwards();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchInwards,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _inwards.isEmpty
            ? const Center(child: Text('No inward entries found'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _inwards.length,
                itemBuilder: (context, index) {
                  final item = _inwards[index];
                  final hasIncharge =
                      item['lotInchargeSignature'] != null &&
                      item['lotInchargeSignature'].toString().isNotEmpty;
                  final hasAuthorized =
                      item['authorizedSignature'] != null &&
                      item['authorizedSignature'].toString().isNotEmpty;
                  final hasMd =
                      item['mdSignature'] != null &&
                      item['mdSignature'].toString().isNotEmpty;

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
                      leading: item['qualityImage'] != null
                          ? Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(
                                    ApiConstants.getImageUrl(
                                      item['qualityImage'],
                                    ),
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.inventory_2,
                                color: Colors.green,
                              ),
                            ),
                      title: Text(
                        'Lot: ${item['lotNo']} - ${item['lotName']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Date: ${DateFormat('dd-MM-yyyy').format(DateTime.parse(item['inwardDate']))}\nParty: ${item['fromParty']}',
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
                              const SizedBox(width: 8),
                              _buildSignIndicator(Icons.star, hasMd, 'MD'),
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
                                InwardDetailScreen(inward: item),
                          ),
                        );
                        _fetchInwards();
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
          color: active ? Colors.green : Colors.grey.withOpacity(0.5),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? Colors.green : Colors.grey.withOpacity(0.5),
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
