import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/color_palette.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/layout_constants.dart';

class CustomDropdownField extends StatefulWidget {
  final String label;
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;
  final String? Function(String?)? validator;
  final String hint;
  final IconData? prefixIcon;
  final Map<String, String>? itemImages;
  final VoidCallback? onDoubleTap;
  final Color? Function(String)? resolveColor;
  final bool isDense;

  const CustomDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.hint = 'Select an option',
    this.prefixIcon,
    this.itemImages,
    this.onDoubleTap,
    this.resolveColor,
    this.isDense = false,
  });

  @override
  State<CustomDropdownField> createState() => _CustomDropdownFieldState();
}

class _CustomDropdownFieldState extends State<CustomDropdownField> {
  final MenuController _menuController = MenuController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    return widget.items
        .where((item) => item.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ColorPalette.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          Gaps.h8,
        ],
        MenuAnchor(
          controller: _menuController,
          alignmentOffset: const Offset(0, 4),
          style: MenuStyle(
            backgroundColor: WidgetStateProperty.all(Colors.white),
            surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
            elevation: WidgetStateProperty.all(8),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: ColorPalette.border),
              ),
            ),
            padding: WidgetStateProperty.all(EdgeInsets.zero),
          ),
          menuChildren: [
            Container(
              width: 350,
              height: 400,
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                children: [
                  // Search Bar at Top
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted),
                        prefixIcon: const Icon(LucideIcons.search, size: 14, color: ColorPalette.textMuted),
                        filled: true,
                        fillColor: ColorPalette.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: ColorPalette.border),
                  // List Items
                  Expanded(
                    child: _filteredItems.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No items found',
                                style: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = _filteredItems[index];
                              final isSelected = item == widget.value;

                              return InkWell(
                                onTap: () {
                                  widget.onChanged(item);
                                  _menuController.close();
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  color: isSelected ? ColorPalette.primary.withOpacity(0.05) : null,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.contains(' (#') ? item.split(' (#')[0] : item,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected ? ColorPalette.primary : ColorPalette.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(LucideIcons.check, size: 14, color: ColorPalette.primary),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
          builder: (context, controller, child) {
            return GestureDetector(
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              child: FormField<String>(
                key: ValueKey(widget.value),
                validator: widget.validator,
                initialValue: widget.value,
                builder: (state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: widget.isDense 
                            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                            : const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: state.hasError ? ColorPalette.error : ColorPalette.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (widget.prefixIcon != null) ...[
                              Icon(widget.prefixIcon, size: 16, color: ColorPalette.textMuted),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Text(
                                (widget.value != null && widget.value!.contains(' (#'))
                                    ? widget.value!.split(' (#')[0]
                                    : widget.value ?? widget.hint,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: widget.value == null
                                      ? ColorPalette.textMuted
                                      : ColorPalette.textPrimary,
                                  fontWeight: widget.value == null ? FontWeight.normal : FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(LucideIcons.chevronDown, size: 16, color: ColorPalette.textMuted),
                          ],
                        ),
                      ),
                      if (state.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            state.errorText!,
                            style: GoogleFonts.inter(color: ColorPalette.error, fontSize: 10),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
