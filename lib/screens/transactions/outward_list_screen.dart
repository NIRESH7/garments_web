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
      appBar: AppBar(title: const Text('Outward List')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _outwards.isEmpty
          ? const Center(child: Text('No outward entries found'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _outwards.length,
              itemBuilder: (context, index) {
                final item = _outwards[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text('DC No: ${item['dcNo']}'),
                    subtitle: Text(
                      'Lot: ${item['lotNo']} / ${item['lotName']}\nParty: ${item['partyName']}',
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OutwardDetailScreen(outward: item),
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
