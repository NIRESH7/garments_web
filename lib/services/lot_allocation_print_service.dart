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
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('ITEM NAME', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                    ),
                    ...sizes.map((s) => pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Center(
                            child: pw.Text(s.toString(), style: pw.TextStyle(font: boldFont, fontSize: 9)),
                          ),
                        )),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('TOTAL', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                    ),
                  ],
                ),
                // Data rows
                ...validEntries.map((e) {
                  final orderQty = e['sizeQuantities'] as Map<String, dynamic>? ?? {};
                  final cuttingQty = e['cuttingQuantities'] as Map<String, dynamic>? ?? {};

                  int rowOrderTotal = 0;
                  int rowCuttingTotal = 0;

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(e['itemName'] ?? '', style: pw.TextStyle(font: font, fontSize: 8)),
                      ),
                      ...sizes.map((s) {
                        final sStr = s.toString();
                        final order = (orderQty[sStr] ?? 0) as int;
                        final cutting = (cuttingQty[sStr] ?? 0) as int;
                        final pending = order - cutting;

                        rowOrderTotal += order;
                        rowCuttingTotal += cutting;

                        return pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (order > 0 || cutting > 0) ...[
                                pw.Text('ORDER-${order}', style: pw.TextStyle(color: PdfColors.green, font: font, fontSize: 7)),
                                pw.Text('CUTTING-${cutting}', style: pw.TextStyle(color: PdfColors.blue, font: font, fontSize: 7)),
                                pw.Text('PENDING-${pending}', style: pw.TextStyle(color: PdfColors.red, font: font, fontSize: 7)),
                              ] else
                                pw.Text('-', style: pw.TextStyle(font: font, fontSize: 7)),
                            ],
                          ),
                        );
                      }),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('ORDER-${rowOrderTotal}', style: pw.TextStyle(color: PdfColors.green, font: boldFont, fontSize: 7)),
                            pw.Text('CUTTING-${rowCuttingTotal}', style: pw.TextStyle(color: PdfColors.blue, font: boldFont, fontSize: 7)),
                            pw.Text('PENDING-${rowOrderTotal - rowCuttingTotal}', style: pw.TextStyle(color: PdfColors.red, font: boldFont, fontSize: 7)),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Grand Total ORDER: ${validEntries.fold<int>(0, (sum, e) => sum + ((e['totalDozens'] ?? 0) as int))}',
                      style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.green),
                    ),
                    pw.Text(
                      'Grand Total CUTTING: ${validEntries.fold<int>(0, (sum, e) => sum + (e['cuttingQuantities'] != null ? (e['cuttingQuantities'] as Map).values.fold<int>(0, (s, v) => s + (v as int)) : 0))}',
                      style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.blue),
                    ),
                    pw.Text(
                      'Grand Total PENDING: ${validEntries.fold<int>(0, (sum, e) {
                            final order = (e['totalDozens'] ?? 0) as int;
                            final cutting = e['cuttingQuantities'] != null ? (e['cuttingQuantities'] as Map).values.fold<int>(0, (s, v) => s + (v as int)) : 0;
                            return sum + (order - cutting);
                          })}',
                      style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.red),
                    ),
                  ],
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

  Future<void> printCuttingMasterDetail(Map<String, dynamic> entry) async {
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
                'CUTTING MASTER DETAIL REPORT',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 16,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey300),
              children: [
                _buildTableRow('Item Name', entry['itemName'] ?? '-', boldFont, font),
                _buildTableRow('Size', entry['size'] ?? '-', boldFont, font),
                _buildTableRow('Lot Name', entry['lotName'] ?? '-', boldFont, font),
                _buildTableRow('Dia Name', entry['diaName'] ?? '-', boldFont, font),
                _buildTableRow('Knitting Dia', entry['knittingDia'] ?? '-', boldFont, font),
                _buildTableRow('Cutting Dia', entry['cuttingDia'] ?? '-', boldFont, font),
                _buildTableRow('Dozen Weight', entry['dozenWeight']?.toString() ?? '-', boldFont, font),
                _buildTableRow('Efficiency %', entry['efficiency']?.toString() ?? '-', boldFont, font),
                _buildTableRow('Waste %', entry['wastePercentage']?.toString() ?? '-', boldFont, font),
                _buildTableRow('Folding', entry['folding']?.toString() ?? '-', boldFont, font),
                _buildTableRow('Lay Pcs', entry['layPcs']?.toString() ?? '-', boldFont, font),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Text('Instructions:', style: pw.TextStyle(font: boldFont, fontSize: 12)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
              child: pw.Text(entry['instructionText'] ?? 'No text instruction provided.', style: pw.TextStyle(font: font, fontSize: 10)),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Pattern Details:', style: pw.TextStyle(font: boldFont, fontSize: 12)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Party Name', 'Front (Mea)', 'Back (Mea)', 'Finishing'],
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 9),
              cellStyle: pw.TextStyle(font: font, fontSize: 8),
              data: (entry['patternDetails'] as List? ?? []).map((p) => [
                p['partyName'] ?? '-',
                p['frontMeasurement'] ?? '-',
                p['backMeasurement'] ?? '-',
                p['finishingMeasurement'] ?? '-',
              ]).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'CuttingMaster_${entry['itemName']}_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  pw.TableRow _buildTableRow(String label, String value, pw.Font labelFont, pw.Font valueFont) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(font: labelFont, fontSize: 10)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: pw.TextStyle(font: valueFont, fontSize: 10)),
        ),
      ],
    );
  }
}
