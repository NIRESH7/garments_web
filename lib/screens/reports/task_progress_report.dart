import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/app_drawer.dart';

class TaskProgressReportScreen extends StatefulWidget {
  const TaskProgressReportScreen({super.key});

  @override
  State<TaskProgressReportScreen> createState() => _TaskProgressReportScreenState();
}

class _TaskProgressReportScreenState extends State<TaskProgressReportScreen> {
  final _api = MobileApiService();
  bool _isLoading = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<dynamic> _tasks = [];
  String _targetDept = 'Cutting';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _api.getTasks();
      setState(() {
        _tasks = tasks.where((t) {
          final date = DateTime.parse(t['createdAt'].toString());
          final inRange = date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
                          date.isBefore(_endDate.add(const Duration(days: 1)));
          final inDept = _targetDept == 'All' || t['assignedTo'] == _targetDept;
          return inRange && inDept;
        }).toList();
        // Sort by date descending
        _tasks.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TASK PROGRESS REPORT')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? const Center(child: Text('No tasks found for this criteria'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          return _buildTaskCard(task);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _targetDept,
                    decoration: const InputDecoration(labelText: 'DEPARTMENT'),
                    items: ['All', 'Tailoring', 'Packing', 'Cutting']
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (val) {
                      setState(() => _targetDept = val!);
                      _fetchData();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) {
                        setState(() => _startDate = d);
                        _fetchData();
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('FROM', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(DateFormat('dd-MM-yyyy').format(_startDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) {
                        setState(() => _endDate = d);
                        _fetchData();
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TO', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(DateFormat('dd-MM-yyyy').format(_endDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(dynamic task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task['title'] ?? 'No Title',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                _statusChip(task['status'] ?? 'Pending'),
              ],
            ),
            const SizedBox(height: 8),
            Text(task['description'] ?? '', style: const TextStyle(color: Colors.black87)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Created: ${DateFormat('dd-MM-yyyy').format(DateTime.parse(task['createdAt']))}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text('Assigned: ${task['assignedTo']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            if (task['replies'] != null && (task['replies'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Progress History:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
              for (var reply in task['replies']) 
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• ${reply['workerName']}: ${reply['replyText']} (${reply['submittedAt'] != null ? DateFormat('dd-MM-yy HH:mm').format(DateTime.parse(reply['submittedAt'])) : 'N/A'})',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color = Colors.grey;
    if (status == 'Completed') color = Colors.green;
    if (status == 'In Progress') color = Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
