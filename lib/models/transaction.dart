class LotInward {
  final String id;
  final String lotNumber;
  final String lotName;
  final String fromParty;
  final String process;
  final String dia;
  final int roll;
  final String setNo;
  final List<LotInwardRow> rows;
  final DateTime createdAt;

  LotInward({
    required this.id,
    required this.lotNumber,
    required this.lotName,
    required this.fromParty,
    required this.process,
    required this.dia,
    required this.roll,
    required this.setNo,
    required this.rows,
    required this.createdAt,
  });
}

class LotInwardRow {
  final String dia;
  final String serialNo;
  final String colour;
  final String fromLotNo;
  final double s1Weight;
  final double s2Weight;

  LotInwardRow({
    required this.dia,
    required this.serialNo,
    required this.colour,
    required this.fromLotNo,
    required this.s1Weight,
    required this.s2Weight,
  });

  double get totalWeight => s1Weight + s2Weight;
}

class LotOutward {
  final String id;
  final String lotNo;
  final String lotName;
  final String dia;
  final String setNo;
  final String partyName;
  final String process;
  final List<LotOutwardItem> items;
  final String dcNumber;
  final DateTime createdAt;

  LotOutward({
    required this.id,
    required this.lotNo,
    required this.lotName,
    required this.dia,
    required this.setNo,
    required this.partyName,
    required this.process,
    required this.items,
    required this.dcNumber,
    required this.createdAt,
  });
}

class LotOutwardItem {
  final String colour;
  double weight;

  LotOutwardItem({required this.colour, required this.weight});
}
