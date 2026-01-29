class Lot {
  final String id;
  final String lotNumber;
  final String partyName;
  final String process;
  final String? remarks;

  Lot({
    required this.id,
    required this.lotNumber,
    required this.partyName,
    required this.process,
    this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lot_number': lotNumber,
      'party_name': partyName,
      'process': process,
      'remarks': remarks,
    };
  }

  factory Lot.fromMap(Map<String, dynamic> map) {
    return Lot(
      id: map['id'],
      lotNumber: map['lot_number'] ?? '',
      partyName: map['party_name'] ?? '',
      process: map['process'] ?? '',
      remarks: map['remarks'],
    );
  }
}

class Item {
  final String id;
  final String itemName;
  final String gsm;
  final String itemGroup;
  final String size;
  final String setVal;

  Item({
    required this.id,
    required this.itemName,
    required this.gsm,
    required this.itemGroup,
    required this.size,
    required this.setVal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_name': itemName,
      'gsm': gsm,
      'item_group': itemGroup,
      'size': size,
      'set_val': setVal,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      itemName: map['item_name'] ?? '',
      gsm: map['gsm'] ?? '',
      itemGroup: map['item_group'] ?? '',
      size: map['size'] ?? '',
      setVal: map['set_val'] ?? '',
    );
  }
}
