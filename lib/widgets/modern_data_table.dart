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
  final bool showActions;
  final String? emptyMessage;
  final Map<String, IconData>? columnIcons;

  const ModernDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onEdit,
    this.onDelete,
    this.onView,
    this.showActions = true,
    this.emptyMessage,
    this.columnIcons,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorPalette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24, 
              vertical: 14
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: ColorPalette.border.withOpacity(0.8))),
            ),
            child: Row(
              children: [
                ...widget.columns.map((col) => Expanded(
                  flex: col == 'description' || col == 'address' || col == 'remarks' ? 2 : 1,
                  child: Text(
                    col.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.8,
                      color: ColorPalette.textMuted,
                    ),
                  ),
                )),
                if (widget.showActions)
                  SizedBox(
                    width: isMobile ? 80 : 120,
                    child: Text(
                      'ACTIONS',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.8,
                        color: ColorPalette.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _paginatedRows.length,
            itemBuilder: (context, index) {
              final row = _paginatedRows[index];
              final isAlternate = index % 2 != 0;

              return InkWell(
                onTap: widget.onView != null ? () => widget.onView!(row) : null,
                hoverColor: ColorPalette.primary.withOpacity(0.04),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24, 
                    vertical: 16
                  ),
                  decoration: BoxDecoration(
                    color: isAlternate ? const Color(0xFFFDFDFD) : Colors.white,
                    border: Border(bottom: BorderSide(color: ColorPalette.border.withOpacity(0.5))),
                  ),
                  child: Row(
                    children: [
                      ...widget.columns.asMap().entries.map((entry) {
                        final colIdx = entry.key;
                        final col = entry.value;
                        final value = row[col]?.toString() ?? '-';
                        final isFirst = colIdx == 0;
                        final icon = isFirst ? (widget.columnIcons?[col] ?? _getDefaultIcon(col, value)) : null;

                        return Expanded(
                          flex: col == 'description' || col == 'address' || col == 'remarks' ? 2 : 1,
                          child: Row(
                            children: [
                              if (isFirst && icon != null)
                                Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: ColorPalette.primary.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(icon, size: 14, color: ColorPalette.primary),
                                ),
                              Expanded(
                                child: Text(
                                  value,
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 12 : 13,
                                    fontWeight: isFirst ? FontWeight.w700 : FontWeight.w500,
                                    color: ColorPalette.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (widget.showActions)
                        SizedBox(
                          width: isMobile ? 80 : 120,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (widget.onView != null)
                                _buildActionBtn(
                                  icon: LucideIcons.eye,
                                  onTap: () => widget.onView!(row),
                                  color: ColorPalette.info,
                                  tooltip: 'View',
                                  isMobile: isMobile,
                                ),
                              if (widget.onEdit != null)
                                _buildActionBtn(
                                  icon: LucideIcons.edit,
                                  onTap: () => widget.onEdit!(row),
                                  color: ColorPalette.primary,
                                  tooltip: 'Edit',
                                  isMobile: isMobile,
                                ),
                              if (widget.onDelete != null)
                                _buildActionBtn(
                                  icon: LucideIcons.trash2,
                                  onTap: () => widget.onDelete!(row),
                                  color: ColorPalette.error,
                                  tooltip: 'Delete',
                                  isMobile: isMobile,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          _buildPaginationFooter(),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter() {
    if (widget.rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: ColorPalette.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'SHOWING ',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5),
              ),
              Text(
                '${(_currentPage * _pageSize) + 1} - ${(_currentPage * _pageSize) + _paginatedRows.length}',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: ColorPalette.textPrimary),
              ),
              Text(
                ' OF ${widget.rows.length}',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5),
              ),
            ],
          ),
          Row(
            children: [
              _buildPaginationBtn(
                LucideIcons.chevronLeft,
                _currentPage > 0 ? () => setState(() => _currentPage--) : null,
              ),
              const SizedBox(width: 12),
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: ColorPalette.textPrimary),
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: isEnabled ? ColorPalette.border : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(6),
          color: isEnabled ? Colors.white : Colors.grey.shade50,
        ),
        child: Icon(icon, size: 16, color: isEnabled ? ColorPalette.textPrimary : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(64.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorPalette.border),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: ColorPalette.background, shape: BoxShape.circle),
              child: Icon(LucideIcons.database, size: 48, color: ColorPalette.textMuted.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              widget.emptyMessage ?? 'No registry entries found',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: ColorPalette.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Try refining your current search parameters.',
              style: GoogleFonts.inter(fontSize: 13, color: ColorPalette.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required String tooltip,
    required bool isMobile,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 6 : 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: isMobile ? 14 : 16, color: color),
        ),
      ),
    );
  }

  IconData _getDefaultIcon(String col, String value) {
    final lowerCol = col.toLowerCase();
    final lowerVal = value.toLowerCase();
    
    if (lowerCol.contains('color') || lowerVal.contains('shade')) return LucideIcons.palette;
    if (lowerCol.contains('dia')) return LucideIcons.moveHorizontal;
    if (lowerCol.contains('gsm')) return LucideIcons.layers;
    if (lowerCol.contains('lot')) return LucideIcons.package;
    if (lowerCol.contains('party')) return LucideIcons.briefcase;
    if (lowerCol.contains('size')) return LucideIcons.ruler;
    return LucideIcons.tag;
  }
}
