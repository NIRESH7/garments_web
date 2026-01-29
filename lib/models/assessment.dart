class Party {
  final String id;
  final String name;

  Party({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
  factory Party.fromMap(Map<String, dynamic> map) =>
      Party(id: map['id'], name: map['name']);
}

class ItemAssignment {
  final String id;
  final String itemName;
  final String size;
  final String dia;
  final String efficiency;
  final double dozenWeight;

  ItemAssignment({
    required this.id,
    required this.itemName,
    required this.size,
    required this.dia,
    required this.efficiency,
    required this.dozenWeight,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_name': itemName,
      'size': size,
      'dia': dia,
      'efficiency': efficiency,
      'dozen_weight': dozenWeight,
    };
  }

  factory ItemAssignment.fromMap(Map<String, dynamic> map) {
    return ItemAssignment(
      id: map['id'],
      itemName: map['item_name'],
      size: map['size'],
      dia: map['dia'],
      efficiency: map['efficiency'],
      dozenWeight: (map['dozen_weight'] as num).toDouble(),
    );
  }
}
