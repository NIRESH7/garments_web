import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/color_palette.dart';
import '../core/constants/layout_constants.dart';

class WebDataTable extends StatelessWidget {
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final Function(Map<String, dynamic>)? onEdit;
  final Function(Map<String, dynamic>)? onDelete;
  final Function(Map<String, dynamic>)? onView;
  final String? emptyMessage;
  final bool showActions;

  const WebDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onEdit,
    this.onDelete,
    this.onView,
    this.emptyMessage,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final isWeb = LayoutConstants.isWeb(context);
    
    if (!isWeb) {
      return _buildMobileList();
    }

    if (rows.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ColorPalette.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                ...columns.map((column) => Expanded(
                  child: Text(
                    column.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ColorPalette.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                )),
                if (showActions) const SizedBox(width: 100),
              ],
            ),
          ),
          // Rows
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => _buildWebRow(rows[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebRow(Map<String, dynamic> row) {
    return InkWell(
      onTap: onView != null ? () => onView!(row) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ...columns.map((column) => Expanded(
              child: Text(
                _formatCellValue(row[column]),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: ColorPalette.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )),
            if (showActions) SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    IconButton(
                      onPressed: () => onEdit!(row),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                      tooltip: 'Edit',
                    ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: () => onDelete!(row),
                      icon: const Icon(LucideIcons.trash2, size: 16, color: ColorPalette.error),
                      tooltip: 'Delete',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    if (rows.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) => _buildMobileCard(rows[index]),
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> row) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...columns.take(3).map((column) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      column.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ColorPalette.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatCellValue(row[column]),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: ColorPalette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            if (showActions) ...[
              const SizedBox(height: 8),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: () => onEdit!(row),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                      label: const Text('Edit'),
                    ),
                  if (onDelete != null)
                    TextButton.icon(
                      onPressed: () => onDelete!(row),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: ColorPalette.error),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.inbox,
            size: 64,
            color: ColorPalette.textMuted.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            emptyMessage ?? 'No data available',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: ColorPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCellValue(dynamic value) {
    if (value == null) return '-';
    if (value is String) return value;
    if (value is num) return value.toString();
    return value.toString();
  }
}