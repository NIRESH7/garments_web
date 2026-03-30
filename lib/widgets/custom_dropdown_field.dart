import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/color_palette.dart';

class CustomDropdownField extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ColorPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: () => _showSelectionDialog(context),
          onDoubleTap: onDoubleTap,
          child: FormField<String>(
            key: ValueKey(value),
            validator: validator,
            initialValue: value,
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: state.hasError
                            ? ColorPalette.error
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (prefixIcon != null) ...[
                          Icon(
                            prefixIcon,
                            size: 18,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (value != null) ...[
                          (() {
                            final rColor = resolveColor?.call(value!);
                            final imgPath = itemImages?[value!];

                            if (rColor != null) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildColorCircle(rColor),
                                  const SizedBox(width: 10),
                                ],
                              );
                            } else if (imgPath != null) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildImagePreview(imgPath),
                                  const SizedBox(width: 10),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          })(),
                        ],
                        Expanded(
                          child: Text(
                            (value != null && value!.contains(' (#'))
                                ? value!.split(' (#')[0]
                                : value ?? hint,
                            style: TextStyle(
                              fontSize: 14,
                              color: value == null
                                  ? Colors.grey.shade400
                                  : ColorPalette.textPrimary,
                              fontWeight: value == null
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          LucideIcons.chevronDown,
                          size: 20,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        state.errorText!,
                        style: const TextStyle(
                          color: ColorPalette.error,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _SearchableListDialog(
        title: 'Select $label',
        items: items,
        initialValue: value,
        itemImages: itemImages,
        resolveColor: resolveColor,
        onSelected: (val) {
          onChanged(val);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildColorCircle(Color color) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
    );
  }

  Widget _buildImagePreview(String path) {
    bool isNetwork = path.startsWith('http');
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
        image: DecorationImage(
          image: isNetwork
              ? NetworkImage(path) as ImageProvider
              : FileImage(File(path)), // Correcting io.File usage
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _SearchableListDialog extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? initialValue;
  final Map<String, String>? itemImages;
  final Color? Function(String)? resolveColor;
  final Function(String) onSelected;

  const _SearchableListDialog({
    required this.title,
    required this.items,
    this.initialValue,
    this.itemImages,
    this.resolveColor,
    required this.onSelected,
  });

  @override
  State<_SearchableListDialog> createState() => _SearchableListDialogState();
}

class _SearchableListDialogState extends State<_SearchableListDialog> {
  late List<String> _filteredItems;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = widget.items
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ColorPalette.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _filterItems,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.searchX,
                            size: 40,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No items found',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isSelected = item == widget.initialValue;
                        final imagePath = widget.itemImages?[item];

                        return ListTile(
                          onTap: () => widget.onSelected(item),
                          leading: (() {
                            final rColor = widget.resolveColor?.call(item);
                            final imagePath = widget.itemImages?[item];

                            if (rColor != null) {
                              return Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: rColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                              );
                            } else if (imagePath != null) {
                              return Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  image: DecorationImage(
                                    image: imagePath.startsWith('http')
                                        ? NetworkImage(imagePath)
                                              as ImageProvider
                                        : FileImage(File(imagePath)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            }
                            return null;
                          })(),
                          title: Text(
                            item.contains(' (#') ? item.split(' (#')[0] : item,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : ColorPalette.textPrimary,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  LucideIcons.check,
                                  color: Theme.of(context).primaryColor,
                                  size: 18,
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
