import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/app_drawer.dart';
import './task_detail_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/api_constants.dart';

class WorkerTaskDashboardScreen extends StatefulWidget {
  const WorkerTaskDashboardScreen({super.key});

  @override
  State<WorkerTaskDashboardScreen> createState() => _WorkerTaskDashboardScreenState();
}

class _WorkerTaskDashboardScreenState extends State<WorkerTaskDashboardScreen> {
  final _api = MobileApiService();
  final _audioPlayer = AudioPlayer();
  bool _isLoading = false;
  List<dynamic> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await _api.getTasks();
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('MY TASKS')),
      drawer: const AppDrawer(),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  final isCompleted = task['status'] == 'Completed';
                  final priorityColor = task['priority'] == 'High' ? Colors.red : (task['priority'] == 'Medium' ? Colors.orange : Colors.green);

                  return Card(
                    elevation: isCompleted ? 1 : 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: priorityColor.withOpacity(0.1),
                        child: Icon(isCompleted ? Icons.check_circle : LucideIcons.clock, color: priorityColor),
                      ),
                      title: Text(
                        task['title'] ?? 'No Title',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted ? Colors.grey : Colors.black87,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(task['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCompleted ? Colors.green.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task['status'].toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? Colors.green : Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Play admin voice instruction if available
                          if (task['voiceDescriptionUrl'] != null &&
                              task['voiceDescriptionUrl'].toString().isNotEmpty)
                            IconButton(
                              icon: const Icon(LucideIcons.volume2, color: Colors.blue, size: 22),
                              onPressed: () {
                                final fullUrl = ApiConstants.getImageUrl(task['voiceDescriptionUrl']);
                                _audioPlayer.play(UrlSource(fullUrl));
                              },
                              tooltip: 'Listen to instruction',
                            ),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2, color: Colors.grey, size: 20),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Task'),
                                  content: const Text('Are you sure you want to delete this task?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        final success = await _api.deleteTask(task['_id']);
                                        if (success) {
                                          _loadTasks();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Task deleted successfully')),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Failed to delete task'), backgroundColor: Colors.red),
                                          );
                                        }
                                      },
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task))
                        );
                        _loadTasks();
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
