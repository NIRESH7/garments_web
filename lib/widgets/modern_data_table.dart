import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/color_palette.dart';
import '../core/constants/layout_constants.dart';

class ModernDataTable extends StatefulWidget {
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final Function(Map<String, dynamic>)? onEdit;
  final Function(Map<String, dynamic>)? onDelete;
  final Function(Map<String, dynamic>)? onView;
  final Function(Map<String, dynamic>)? onPrint;
  final Function(Map<String, dynamic>)? onShare;
  final bool showActions;
  final String? emptyMessage;
  final Map<String, IconData>? columnIcons;
  final Widget? headerTrailing;

  const ModernDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onEdit,
    this.onDelete,
    this.onView,
    this.onPrint,
    this.onShare,
    this.showActions = true,
    this.emptyMessage,
    this.columnIcons,
    this.headerTrailing,
  });

  @override
  State<ModernDataTable> createState() => _ModernDataTableState();
}

class _ModernDataTableState extends State<ModernDataTable> {
  int? _hoveredIndex;
  int _currentPage = 0;
  static const int _pageSize = 10;

  List<Map<String, dynamic>> get _paginatedRows {
    int start = _currentPage * _pageSize;
    int end = start + _pageSize;
    if (end > widget.rows.length) end = widget.rows.length;
    return widget.rows.sublist(start, end);
  }

  int get _totalPages => (widget.rows.length / _pageSize).ceil();
  
  @override
  void didUpdateWidget(covariant ModernDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rows != widget.rows) {
      setState(() => _currentPage = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return _buildEmptyState();
    }

    final isMobile = LayoutConstants.isMobile(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min, // prevent expansion overflow
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF475569), // Lightened slate grey for better contrast
            ),
            child: Row(
              children: [
                ...widget.columns.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final col = entry.value;
                  return Expanded(
                    flex: col == 'description' || col == 'address' || col == 'remarks' ? 2 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        border: idx < widget.columns.length - 1 || widget.showActions 
                          ? const Border(right: BorderSide(color: Colors.white24, width: 0.5)) 
                          : null,
                      ),
                      child: Text(
                        col.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 1,
                          color: Colors.white, // White text on black header
                        ),
                      ),
                    ),
                  );
                }),
                if (widget.showActions)
                  SizedBox(
                    width: isMobile ? 120 : 180,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      alignment: Alignment.centerRight,
                      child: widget.headerTrailing ?? Text(
                        'ACTIONS',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Rows
          Flexible( // allow rows to take available space correctly
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: _paginatedRows.length,
              itemBuilder: (context, index) {
                final row = _paginatedRows[index];

                return InkWell(
                  onTap: widget.onView != null ? () => widget.onView!(row) : null,
                  hoverColor: const Color(0xFFF8FAFC),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        ...widget.columns.asMap().entries.map((entry) {
                          final colIdx = entry.key;
                          final col = entry.value;
                          final value = row[col]?.toString() ?? '-';
                          final isFirst = colIdx == 0;

                          return Expanded(
                            flex: col == 'description' || col == 'address' || col == 'remarks' ? 2 : 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                              decoration: BoxDecoration(
                                border: colIdx < widget.columns.length - 1 || widget.showActions
                                  ? const Border(right: BorderSide(color: Color(0xFFF1F5F9), width: 0.5)) // Vertical Borders
                                  : null,
                              ),
                              child: Text(
                                value,
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 13 : 14,
                                  fontWeight: isFirst ? FontWeight.w700 : FontWeight.w500,
                                  color: isFirst ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          );
                        }),
                        if (widget.showActions)
                          SizedBox(
                            width: isMobile ? 120 : 180,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (widget.onView != null)
                                  _buildActionBtn(icon: LucideIcons.eye, onTap: () => widget.onView!(row), color: const Color(0xFF3B82F6), isMobile: isMobile),
                                if (widget.onEdit != null)
                                  _buildActionBtn(icon: LucideIcons.edit3, onTap: () => widget.onEdit!(row), color: const Color(0xFF2563EB), isMobile: isMobile),
                                if (widget.onDelete != null)
                                  _buildActionBtn(icon: LucideIcons.trash2, onTap: () => widget.onDelete!(row), color: const Color(0xFFEF4444), isMobile: isMobile),
                                if (widget.onShare != null)
                                  _buildActionBtn(icon: LucideIcons.arrowRightLeft, onTap: () => widget.onShare!(row), color: const Color(0xFFF59E0B), isMobile: isMobile),
                                const SizedBox(width: 16),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildPaginationFooter(),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter() {
    if (widget.rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page ${_currentPage + 1} of $_totalPages',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
          ),
          Row(
            children: [
              _buildPaginationBtn(
                LucideIcons.chevronLeft,
                _currentPage > 0 ? () => setState(() => _currentPage--) : null,
              ),
              const SizedBox(width: 12),
              _buildPaginationBtn(
                LucideIcons.chevronRight,
                _currentPage < _totalPages - 1 ? () => setState(() => _currentPage++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBtn(IconData icon, VoidCallback? onTap) {
    bool isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: isEnabled ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: isEnabled ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(64.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC), shape: BoxShape.circle),
            child: Icon(LucideIcons.database, size: 48, color: Colors.blueGrey.shade100),
          ),
          const SizedBox(height: 24),
          Text(
            widget.emptyMessage ?? 'No records found',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required bool isMobile,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 14, color: color.withOpacity(0.7)),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 18,
      ),
    );
  }
}
