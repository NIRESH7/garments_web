import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../utils/print_utils.dart';

class LotAllocationPrintService {
  Future<void> printDailyAllocations(List<dynamic> allocations, DateTime start, DateTime end) async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            PrintUtils.buildCompanyHeader(boldFont, font),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                'DAILY ALLOCATION REPORT',
                style: pw.TextStyle(font: boldFont, fontSize: 16, decoration: pw.TextDecoration.underline),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Period: ${DateFormat('dd/MM/yyyy').format(start)} to ${DateFormat('dd/MM/yyyy').format(end)}',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Date', 'Item', 'Size', 'Dozen', 'Lot No', 'Rolls', 'Set No', 'Storage'],
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 9),
              cellStyle: pw.TextStyle(font: font, fontSize: 8),
              data: allocations.map((a) {
                final date = a['orderDate'] is DateTime ? a['orderDate'] : DateTime.parse(a['orderDate'].toString());
                return [
                  DateFormat('dd-MM').format(date),
                  a['itemName'] ?? 'N/A',
                  a['size'] ?? 'N/A',
                  a['dozen'].toString(),
                  a['lotNo'] ?? 'N/A',
                  a['rolls']?.toString() ?? 'N/A',
                  a['setNum'] ?? 'N/A',
                  'R:${a['rackName'] ?? ''}/P:${a['palletNumber'] ?? ''}',
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Allocation_Report_${DateFormat('ddMMyy').format(start)}',
    );
  }
}
