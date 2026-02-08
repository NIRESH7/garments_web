import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';
import 'item_assignment_screen.dart';

class ItemAssignmentListScreen extends StatefulWidget {
  const ItemAssignmentListScreen({super.key});

  @override
  State<ItemAssignmentListScreen> createState() =>
      _ItemAssignmentListScreenState();
}

class _ItemAssignmentListScreenState extends State<ItemAssignmentListScreen> {
  final _api = MobileApiService();
  List<dynamic> _assignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAssignments();
  }

  Future<void> _fetchAssignments() async {
    setState(() => _isLoading = true);
    final res = await _api.getAssignments();
    setState(() {
      _assignments = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Assignments'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ItemAssignmentScreen(),
                ),
              );
              _fetchAssignments();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _assignments.length,
              itemBuilder: (context, index) {
                final item = _assignments[index];
                return _buildAssignmentCard(item);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.clipboardList,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No assignments found',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ItemAssignmentScreen(),
                ),
              );
              _fetchAssignments();
            },
            icon: const Icon(LucideIcons.plus),
            label: const Text('Add Assignment'),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ColorPalette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item['itemName'] ?? 'N/A',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ColorPalette.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item['efficiency']}% Eff.',
                  style: const TextStyle(
                    color: ColorPalette.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(LucideIcons.maximize, 'Size: ${item['size']}'),
              const SizedBox(width: 8),
              _buildInfoChip(LucideIcons.circle, 'Dia: ${item['dia']}'),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dozen Weight',
                style: TextStyle(
                  color: ColorPalette.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '${item['dozenWeight']} Kg',
                style: const TextStyle(
                  color: ColorPalette.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: ColorPalette.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: ColorPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
