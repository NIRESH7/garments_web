import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import '../../core/constants/api_constants.dart';
import 'package:intl/intl.dart';
import 'inward_detail_screen.dart';

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
      appBar: AppBar(title: const Text('Inward List')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inwards.isEmpty
          ? const Center(child: Text('No inward entries found'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _inwards.length,
              itemBuilder: (context, index) {
                final item = _inwards[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: item['qualityImage'] != null
                        ? Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: NetworkImage(
                                  '${ApiConstants.serverUrl}${item['qualityImage']}',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : const Icon(Icons.inventory_2, size: 40),
                    title: Text('Lot: ${item['lotNo']} - ${item['lotName']}'),
                    subtitle: Text(
                      'Date: ${DateFormat('dd-MM-yyyy').format(DateTime.parse(item['inwardDate']))}\nParty: ${item['fromParty']}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              InwardDetailScreen(inward: item),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
