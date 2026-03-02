import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../services/shade_card_print_service.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ShadeCardReportScreen extends StatefulWidget {
  const ShadeCardReportScreen({super.key});

  @override
  State<ShadeCardReportScreen> createState() => _ShadeCardReportScreenState();
}

class _ShadeCardReportScreenState extends State<ShadeCardReportScreen> {
  final _api = MobileApiService();
  List<dynamic> _reportData = [];
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  String? _selectedLotName;

  List<String> get _availableLotNames {
    final Set<String> names = {};
    for (var g in _reportData) {
      if (g['groupName'] != null && g['groupName'].toString().isNotEmpty) {
        names.add(g['groupName'].toString());
      }
    }
    final sortedNames = names.toList()..sort();
    return ['All Lots', ...sortedNames];
  }

  List<dynamic> get _filteredData {
    if (_selectedLotName == null || _selectedLotName == 'All Lots') {
      return _reportData;
    }
    return _reportData
        .where((g) => g['groupName'] == _selectedLotName)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getShadeCardReport();
      setState(() => _reportData = res);
    } catch (e) {
      debugPrint('Error fetching shade card: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shade Card Module'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(LucideIcons.printer),
            onPressed: _isGeneratingPdf
                ? null
                : () async {
                    if (_filteredData.isNotEmpty) {
                      setState(() => _isGeneratingPdf = true);
                      try {
                        await ShadeCardPrintService().printShadeCard(
                          _filteredData,
                        );
                      } catch (e) {
                        debugPrint('Error generating PDF: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to generate PDF: $e'),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isGeneratingPdf = false);
                      }
                    }
                  },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_reportData.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedLotName ?? 'All Lots',
                      decoration: InputDecoration(
                        labelText: 'Filter by Lot Name',
                        prefixIcon: const Icon(LucideIcons.filter),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: _availableLotNames.map((name) {
                        return DropdownMenuItem(value: name, child: Text(name));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLotName = value;
                        });
                      },
                    ),
                  ),
                Expanded(
                  child: _filteredData.isEmpty
                      ? const Center(
                          child: Text(
                            'No shade cards found matching the filter.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _filteredData.length,
                          itemBuilder: (context, index) {
                            final group = _filteredData[index];
                            return _buildGroupCard(group);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final List colours = group['colours'] ?? [];
    final List items = group['items'] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group['groupName'] ?? 'No Lot Name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Items: ${items.join(', ')}',
                      style: TextStyle(
                        color: Colors.indigo.shade100,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Colours Grid
          if (colours.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No colours mapped to this group.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: colours.length,
                itemBuilder: (context, idx) {
                  final color = colours[idx];
                  return _buildColorTile(color);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorTile(Map<String, dynamic> color) {
    final String? photo = color['photo'];
    final String name = color['name'] ?? 'Unknown';
    final String gsm = color['gsm'] ?? 'N/A';

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                image: photo != null
                    ? DecorationImage(
                        image: NetworkImage(ApiConstants.getImageUrl(photo)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: photo == null
                  ? const Center(
                      child: Icon(LucideIcons.image, color: Colors.grey),
                    )
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0, left: 8, right: 8),
            child: Column(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'GSM: $gsm',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
