import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:garments/utils/print_utils.dart';

class LotAllocationPrintService {
  Future<void> printCuttingOrderPlanning(
    String planType,
    String planPeriod,
    DateTime? startDate,
    DateTime? endDate,
    String sizeType,
    List<Map<String, dynamic>> cuttingEntries,
    List<int> sizes,
  ) async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final validEntries = cuttingEntries
        .where((e) => e['itemName'].toString().isNotEmpty)
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            PrintUtils.buildCompanyHeader(boldFont, font),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                'CUTTING ORDER PLANNING SHEET',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 16,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Plan Type: $planType',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Period: $planPeriod',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Size Type: $sizeType',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (startDate != null)
                      pw.Text(
                        'From: ${DateFormat('dd-MM-yyyy').format(startDate)}',
                        style: pw.TextStyle(font: font, fontSize: 10),
                      ),
                    if (endDate != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'To: ${DateFormat('dd-MM-yyyy').format(endDate)}',
                        style: pw.TextStyle(font: font, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: [
                'Item Name',
                ...sizes.map((s) => s.toString()),
                'Total Dozens',
              ],
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 9),
              cellStyle: pw.TextStyle(font: font, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              data: validEntries.map((e) {
                return [
                  e['itemName'] ?? '',
                  ...sizes.map(
                    (s) => (e['sizeQuantities']?[s.toString()] ?? 0).toString(),
                  ),
                  e['totalDozens']?.toString() ?? '0',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Grand Total Dozens: ${validEntries.fold<int>(0, (sum, e) => sum + ((e['totalDozens'] ?? 0) as int))}',
                  style: pw.TextStyle(font: boldFont, fontSize: 12),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Divider(thickness: 0.5, color: PdfColors.grey),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated via IDEAL innerwear ERP',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Date: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Cutting_Order_Planning_${DateFormat('ddMMyyyy_HHmm').format(DateTime.now())}',
    );
  }

  Future<void> printWeeklyAllocations(
    String planId,
    String planPeriod,
    List<Map<String, dynamic>> allAllocations,
  ) async {
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
                'WEEKLY LOT ALLOCATION PLAN',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 16,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Plan ID: $planId',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
                pw.Text(
                  'Period: $planPeriod',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Table.fromTextArray(
              headers: [
                'Day',
                'Lot Name',
                'Lot No',
                'Set',
                'Dia',
                'Rack',
                'Dozen',
              ],
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 9),
              cellStyle: pw.TextStyle(font: font, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              data: allAllocations.map((a) {
                return [
                  a['day'] ?? 'N/A',
                  a['lotName'] ?? '',
                  a['lotNo'] ?? '',
                  a['setNum'] ?? '-',
                  a['dia'] ?? '',
                  a['rackName'] ?? '',
                  a['dozen']?.toString() ?? '0',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Dozens: ${allAllocations.fold<double>(0, (sum, a) => sum + (a['dozen'] ?? 0)).toStringAsFixed(2)}',
                  style: pw.TextStyle(font: boldFont, fontSize: 10),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Divider(thickness: 0.5, color: PdfColors.grey),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated via IDEAL innerwear ERP',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Date: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Weekly_Allocation_$planId',
    );
  }

  Future<void> printDailyAllocations(
    List<dynamic> allocations,
    DateTime startDate,
    DateTime endDate, {
    String? itemName,
    String? size,
  }) async {
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
                'DAILY LOT ALLOCATION REPORT',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 16,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'From: ${DateFormat('dd-MM-yyyy').format(startDate)}',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'To: ${DateFormat('dd-MM-yyyy').format(endDate)}',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (itemName != null)
                      pw.Text(
                        'Item: $itemName',
                        style: pw.TextStyle(font: font, fontSize: 10),
                      ),
                    if (size != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Size: $size',
                        style: pw.TextStyle(font: font, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Table.fromTextArray(
              headers: [
                'Date',
                'Plan ID',
                'Item',
                'Size',
                'Lot No',
                'Dia',
                'Dozen',
              ],
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 8),
              cellStyle: pw.TextStyle(font: font, fontSize: 7),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              data: allocations.map((a) {
                final date = a['orderDate'] is DateTime
                    ? a['orderDate'] as DateTime
                    : DateTime.now();
                return [
                  DateFormat('dd-MM-yyyy').format(date),
                  a['planId'] ?? 'N/A',
                  a['itemName'] ?? '',
                  a['size'] ?? '',
                  a['lotNo'] ?? '',
                  a['dia'] ?? '',
                  a['dozen']?.toString() ?? '0',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Items: ${allocations.length}',
                  style: pw.TextStyle(font: boldFont, fontSize: 10),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Divider(thickness: 0.5, color: PdfColors.grey),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated via IDEAL innerwear ERP',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Date: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Daily_Allocation_Report',
    );
  }

  /// Prints the SET-LEVEL FIFO allocation report (one row per set).
  /// Columns: Day | Item | Size | Dozen | Need Wt | Lot Name | Lot No | Dia | Set No | Rack | Pallet | Set Wt
  Future<void> printSetLevelReport(
    String planId,
    String planPeriod,
    String? dayFilter,
    List<Map<String, dynamic>> rows,
  ) async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final totalWt = rows.fold<double>(
      0.0,
      (s, r) => s + ((r['setWeight'] as num?)?.toDouble() ?? 0),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) => [
          PrintUtils.buildCompanyHeader(boldFont, font),
          pw.SizedBox(height: 14),
          pw.Center(
            child: pw.Text(
              'LOT ALLOCATION — SET-LEVEL PLAN REPORT',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 14,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Plan: $planId  |  Period: $planPeriod',
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
              pw.Text(
                dayFilter != null ? 'Day: $dayFilter' : 'All Days',
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: [
              'Day',
              'Item Name',
              'Size',
              'Dozen',
              'Need Wt (kg)',
              'Lot Name',
              'Lot No',
              'Dia',
              'Set No',
              'Rack',
              'Pallet',
              'Set Wt (kg)',
            ],
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 7),
            cellStyle: pw.TextStyle(font: font, fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellDecoration: (idx, data, rowNum) => pw.BoxDecoration(
              color: rowNum % 2 == 0 ? PdfColors.white : PdfColors.grey50,
            ),
            data: rows
                .map(
                  (r) => [
                    r['day'] ?? '-',
                    r['itemName'] ?? '-',
                    r['size'] ?? '-',
                    r['dozen']?.toString() ?? '-',
                    (r['neededWeight'] as num?)?.toStringAsFixed(1) ?? '-',
                    r['lotName'] ?? '-',
                    r['lotNo'] ?? '-',
                    r['dia'] ?? '-',
                    'Set ${r['setNo']?.toString() ?? '-'}',
                    r['rackName'] ?? '-',
                    r['palletNumber'] ?? '-',
                    (r['setWeight'] as num?)?.toStringAsFixed(2) ?? '-',
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Set Rows: ${rows.length}',
                style: pw.TextStyle(font: boldFont, fontSize: 9),
              ),
              pw.Text(
                'Total Weight: ${totalWt.toStringAsFixed(2)} kg',
                style: pw.TextStyle(font: boldFont, fontSize: 9),
              ),
            ],
          ),
          pw.Spacer(),
          pw.Divider(thickness: 0.5, color: PdfColors.grey),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated via IDEAL innerwear ERP',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Printed: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'SetLevel_Allocation_$planId',
    );
  }
}
