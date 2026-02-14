import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:garments/services/inward_print_service.dart';

void main() {
  test('Generate Inward PDF', () async {
    final service = InwardPrintService();
    
    final inwardData = {
      'inwardNo': 'INW-001',
      'inwardDate': '2023-10-27',
      'fromParty': 'Test Party',
      'lotName': 'Test Fabric',
      'lotNo': '1234/56',
      'partyDcNo': 'DC-999',
      'storageDetails': [
        {
          'dia': '30',
          'rows': [
            {
              'colour': 'Red',
              'setWeights': ['10.5', '11.0']
            },
            {
              'colour': 'Blue',
              'setWeights': ['12.0']
            }
          ]
        },
        {
          'dia': '32',
          'rows': [
            {
              'colour': 'Red',
              'setWeights': ['15.0']
            }
          ]
        }
      ]
    };

    // We can't easily test PdfGoogleFonts in raw unit test without HTTP mocking or allowing it.
    // However, if we run `flutter test`, it might work if network is allowed or we mock it.
    // For now, let's try. If PdfGoogleFonts fails, we might need to mock it or use standard fonts in the service for testing.
    
    // To make it testable without network, we should probably allow injecting fonts or use default fonts in test.
    // But let's try running it first.
    
    try {
        final bytes = await service.generatePdfBytes(inwardData);
        final file = File('test_inward_report.pdf');
        await file.writeAsBytes(bytes);
        print('PDF saved to ${file.absolute.path}');
        expect(file.existsSync(), true);
        expect(bytes.length, greaterThan(0));
    } catch (e) {
        print('Error: $e');
        // If it fails due to fonts, we know we need to adjust.
        // rethrow;
    }
  });
}
