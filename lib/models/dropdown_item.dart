class DropdownItem {
  final String id;
  final String
  category; // lot_name, item_name, dia, colour, size, set, item_group, process, efficiency
  final String value;

  DropdownItem({required this.id, required this.category, required this.value});

  Map<String, dynamic> toMap() {
    return {'id': id, 'category': category, 'value': value};
  }

  factory DropdownItem.fromMap(Map<String, dynamic> map) {
    return DropdownItem(
      id: map['id'],
      category: map['category'],
      value: map['value'],
    );
  }
}
