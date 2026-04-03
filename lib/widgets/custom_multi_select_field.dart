import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/color_palette.dart';

class CustomMultiSelectField extends StatelessWidget {
  final String label;
  final List<String> selectedValues;
  final List<String> items;
  final Function(List<String>) onChanged;
  final String hint;
  final IconData? prefixIcon;

  const CustomMultiSelectField({
    super.key,
    required this.label,
    required this.selectedValues,
    required this.items,
    required this.onChanged,
    this.hint = 'Select options',
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    String displayText = selectedValues.isEmpty ? hint : selectedValues.join(', ');
    if (selectedValues.length > 2) {
      displayText = '${selectedValues.length} items selected';
    }

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
        InkWell(
          onTap: () => _showMultiSelectDialog(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
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
                  Icon(prefixIcon, size: 18, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedValues.isEmpty ? Colors.grey.shade400 : ColorPalette.textPrimary,
                      fontWeight: selectedValues.isEmpty ? FontWeight.normal : FontWeight.w500,
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
        ),
      ],
    );
  }

  void _showMultiSelectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _SearchableMultiSelectDialog(
        title: label,
        items: items,
        initialSelected: selectedValues,
        onChanged: onChanged,
      ),
    );
  }
}

class _SearchableMultiSelectDialog extends StatefulWidget {
  final String title;
  final List<String> items;
  final List<String> initialSelected;
  final Function(List<String>) onChanged;

  const _SearchableMultiSelectDialog({
    required this.title,
    required this.items,
    required this.initialSelected,
    required this.onChanged,
  });

  @override
  State<_SearchableMultiSelectDialog> createState() => _SearchableMultiSelectDialogState();
}

class _SearchableMultiSelectDialogState extends State<_SearchableMultiSelectDialog> {
  late List<String> _tempSelected;
  late List<String> _filteredItems;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tempSelected = List.from(widget.initialSelected);
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
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 400,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Select ${widget.title}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _tempSelected = List.from(widget.items)),
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: () => setState(() => _tempSelected = []),
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  final isChecked = _tempSelected.contains(item);
                  return CheckboxListTile(
                    title: Text(item, style: const TextStyle(fontSize: 14)),
                    value: isChecked,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _tempSelected.add(item);
                        } else {
                          _tempSelected.remove(item);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  widget.onChanged(_tempSelected);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
