import 'package:test/test.dart';
import 'package:garments/services/inward_data_processor.dart';

void main() {
  test('Process Inward Data Matrix', () {
    final inwardData = {
      'storageDetails': [
        {
          'dia': '30',
          'rows': [
            {'colour': 'Red', 'setWeights': ['10.5', '11.0']}, // 2 rolls, 21.5
            {'colour': 'Blue', 'setWeights': ['12.0']} // 1 roll, 12.0
          ]
        },
        {
          'dia': '32',
          'rows': [
            {'colour': 'Red', 'setWeights': ['15.0']} // 1 roll, 15.0
          ]
        }
      ]
    };

    final result = InwardDataProcessor.process(inwardData);
    
    // Check Dias
    expect(result['dias'], ['30', '32']);
    
    // Check Totals
    final totals = result['totals'];
    // 30 DIA: 3 rolls, 33.5
    expect(totals['30']['rolls'], 3);
    expect(totals['30']['weight'], 33.5);
    // 32 DIA: 1 roll, 15.0
    expect(totals['32']['rolls'], 1);
    expect(totals['32']['weight'], 15.0);
    // Grand Total: 4 rolls, 48.5
    expect(totals['grandTotalRolls'], 4);
    expect(totals['grandTotalWeight'], 48.5);

    // Check Rows (Colours)
    final rows = result['rows'] as List<dynamic>;
    expect(rows.length, 2); // Red, Blue

    final redRow = rows.firstWhere((r) => r['colour'] == 'Red');
    expect(redRow['data']['30']['rolls'], 2);
    expect(redRow['data']['30']['weight'], 21.5);
    expect(redRow['data']['32']['rolls'], 1);
    expect(redRow['data']['32']['weight'], 15.0);
    expect(redRow['totalRolls'], 3);
    expect(redRow['totalWeight'], 36.5);

    final blueRow = rows.firstWhere((r) => r['colour'] == 'Blue');
    expect(blueRow['data']['30']['rolls'], 1);
    expect(blueRow['data']['30']['weight'], 12.0);
    expect(blueRow['data'].containsKey('32'), false); // No blue in 32
  });
}
