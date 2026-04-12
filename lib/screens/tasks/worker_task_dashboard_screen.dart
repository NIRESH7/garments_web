import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/mobile_api_service.dart';
import './task_detail_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/color_palette.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/layout_constants.dart';

class WorkerTaskDashboardScreen extends StatefulWidget {
  const WorkerTaskDashboardScreen({super.key});

  @override
  State<WorkerTaskDashboardScreen> createState() => _WorkerTaskDashboardScreenState();
}

class _WorkerTaskDashboardScreenState extends State<WorkerTaskDashboardScreen> {
  final _api = MobileApiService();
  final _audioPlayer = AudioPlayer();
  bool _isLoading = true;
  List<dynamic> _tasks = [];
  String _filter = 'ALL';

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
    try {
      final tasks = await _api.getTasks();
      if (mounted) {
        setState(() {
          _tasks = tasks ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredTasks {
    if (_filter == 'ALL') return _tasks;
    return _tasks.where((t) => t['status']?.toString().toUpperCase() == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = LayoutConstants.isWeb(context);

    // If it's Web, we don't want a Scaffold-AppBar combo that clashes with the shell.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                Text(
                  'MY TASKS',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: ColorPalette.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                _buildFilterChip('ALL'),
                const SizedBox(width: 8),
                _buildFilterChip('PENDING'),
                const SizedBox(width: 8),
                _buildFilterChip('COMPLETED'),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: _loadTasks,
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  color: ColorPalette.textMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _filteredTasks.isEmpty
                    ? _buildEmptyState()
                    : _buildTaskGrid(isWeb),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool isSelected = _filter == label;
    return InkWell(
      onTap: () => setState(() => _filter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ColorPalette.primary : Colors.white,
          border: Border.all(color: isSelected ? ColorPalette.primary : ColorPalette.border.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : ColorPalette.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.clipboardList, size: 48, color: ColorPalette.border.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'NO TASKS FOUND',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ColorPalette.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new assignments.',
            style: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskGrid(bool isWeb) {
    final double horizontalPadding = isWeb ? 24 : 16;
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      itemCount: _filteredTasks.length,
      itemBuilder: (context, index) {
        final task = _filteredTasks[index];
        return _buildTaskRow(task);
      },
    );
  }

  Widget _buildTaskRow(dynamic task) {
    final String status = (task['status'] ?? 'Pending').toString().toUpperCase();
    final bool isCompleted = status == 'COMPLETED';
    final String priority = (task['priority'] ?? 'Low').toString().toUpperCase();
    
    Color priorityColor;
    switch(priority) {
      case 'HIGH': priorityColor = ColorPalette.error; break;
      case 'MEDIUM': priorityColor = Colors.orange; break;
      default: priorityColor = ColorPalette.success; break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorPalette.border.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
          );
          _loadTasks();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (task['title'] ?? 'UNTITLED TASK').toString().toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isCompleted ? ColorPalette.textMuted : ColorPalette.textPrimary,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task['description'] ?? 'No additional details provided.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: ColorPalette.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              _buildStatusChip(status),
              const SizedBox(width: 24),
              if (task['voiceDescriptionUrl'] != null && task['voiceDescriptionUrl'].toString().isNotEmpty)
                IconButton(
                  icon: const Icon(LucideIcons.volume2, color: ColorPalette.primary, size: 20),
                  onPressed: () {
                    final fullUrl = ApiConstants.getImageUrl(task['voiceDescriptionUrl']);
                    _audioPlayer.play(UrlSource(fullUrl));
                  },
                ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(LucideIcons.trash2, color: ColorPalette.textMuted, size: 18),
                onPressed: () => _confirmDelete(task),
              ),
              const SizedBox(width: 12),
              const Icon(LucideIcons.chevronRight, size: 16, color: ColorPalette.border),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch(status) {
      case 'COMPLETED': color = ColorPalette.success; break;
      case 'IN PROGRESS': color = ColorPalette.primary; break;
      default: color = ColorPalette.textMuted; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _confirmDelete(dynamic task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('DELETE TASK', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to permanently remove this task?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _api.deleteTask(task['_id']);
              if (success) {
                _loadTasks();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted')));
              }
            },
            child: const Text('DELETE', style: TextStyle(color: ColorPalette.error)),
          ),
        ],
      ),
    );
  }
}
