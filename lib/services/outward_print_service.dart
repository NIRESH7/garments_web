import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import '../core/constants/api_constants.dart';
import '../utils/print_utils.dart';
import '../utils/pdf_font_helper.dart';

class OutwardPrintService {
  static pw.MemoryImage? _cachedLogo;

  Future<pw.MemoryImage?> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo;
    try {
      final logoData = await rootBundle.load('assets/images/app_logo.png');
      _cachedLogo = pw.MemoryImage(logoData.buffer.asUint8List());
      return _cachedLogo;
    } catch (e) {
      print('Error loading app logo: $e');
      return null;
    }
  }

  Future<void> printOutwardReport(Map<String, dynamic> outward) async {
    final pdf = await _buildPdf(outward);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Lot_Outward_${outward['dcNo']}',
    );
  }

  Future<pw.MemoryImage?> _loadNetImage(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      String url = ApiConstants.getImageUrl(path);
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      print('Error loading image for Outward PDF: $e');
    }
    return null;
  }

  Future<pw.Document> _buildPdf(Map<String, dynamic> outward) async {
    final pdf = pw.Document();

    // Parallel fetch fonts and signatures
    final List<dynamic> results = await Future.wait([
      PdfFontHelper.regular,
      PdfFontHelper.bold,
      _loadNetImage(outward['lotInchargeSignature']?.toString()),
      _loadNetImage(outward['authorizedSignature']?.toString()),
      _loadLogo(),
    ]);

    final font = results[0] as pw.Font;
    final boldFont = results[1] as pw.Font;
    final inchargeImg = results[2] as pw.MemoryImage?;
    final authImg = results[3] as pw.MemoryImage?;
    final logoImage = results[4] as pw.MemoryImage?;

    final items = outward['items'] as List<dynamic>? ?? [];

    // Pivot data: Colors as rows, Sets as columns
    final Set<String> allSetNos = {};
    final Set<String> allColours = {};
    final Map<String, Map<String, double>> colorSetWeights = {};
    final Map<String, int> colorTotalRolls = {};
    final Map<String, double> colorTotalWeight = {};
    final Map<String, Map<String, double>> colorMetadata = {};

    for (var set in items) {
      final setNo = set['set_no']?.toString() ?? 'N/A';
      allSetNos.add(setNo);
      final colours = set['colours'] as List<dynamic>? ?? [];

      for (var col in colours) {
        final colour = col['colour']?.toString() ?? 'N/A';
        allColours.add(colour);
        final wt = (col['weight'] as num?)?.toDouble() ?? 0;
        final r = (col['no_of_rolls'] as num?)?.toInt() ?? 0;

        if (!colorSetWeights.containsKey(colour)) {
          colorSetWeights[colour] = {};
        }
        colorSetWeights[colour]![setNo] = (colorSetWeights[colour]![setNo] ?? 0) + wt;

        colorTotalRolls[colour] = (colorTotalRolls[colour] ?? 0) + r;
        colorTotalWeight[colour] = (colorTotalWeight[colour] ?? 0) + wt;

        // Store gsm/dia for meter calculation if not already stored
        if (!colorMetadata.containsKey(colour)) {
          colorMetadata[colour] = {
            'gsm': (col['gsm'] as num?)?.toDouble() ?? 0,
            'dia': (col['cutting_dia'] as num?)?.toDouble() ??
                (col['dia'] as num?)?.toDouble() ??
                0,
          };
        }
      }
    }

    // Sort sets numerically if possible (e.g. S-1, S-2...)
    final sortedSets = allSetNos.toList()..sort((a, b) {
      int getNum(String s) {
        final match = RegExp(r'\d+').firstMatch(s);
        return match != null ? int.parse(match.group(0)!) : 0;
      }
      int numA = getNum(a);
      int numB = getNum(b);
      if (numA == numB) return a.compareTo(b);
      return numA.compareTo(numB);
    });
    
    final sortedColours = allColours.toList()..sort();

    // Extract distinct Rack and Pallet info
    final Set<String> racks = {};
    final Set<String> pallets = {};
    for (var set in items) {
      if (set['rack_name'] != null) racks.add(set['rack_name'].toString());
      if (set['pallet_number'] != null) pallets.add(set['pallet_number'].toString());
    }

    // Determine orientation: Landscape if many sets
    PdfPageFormat pageFormat = PdfPageFormat.a4;
    if (sortedSets.length > 5) {
      pageFormat = PdfPageFormat.a4.landscape;
    }

    final Map<String, String> setRackMap = {};
    final Map<String, String> setPalletMap = {};
    for (var set in items) {
      final setNo = set['set_no']?.toString() ?? 'N/A';
      setRackMap[setNo] = set['rack_name']?.toString() ?? '-';
      setPalletMap[setNo] = set['pallet_number']?.toString() ?? '-';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
        header: (pw.Context context) => PrintUtils.buildCompanyHeader(boldFont, font, logo: logoImage),
        footer: (pw.Context context) => _buildFooter(boldFont, font),
        build: (pw.Context context) {
          return [
            _buildHeader(
              outward,
              boldFont,
              font,
              setNo: sortedSets.join(', '),
              rack: racks.join(', '),
              pallet: pallets.join(', '),
            ),
            pw.SizedBox(height: 20),
            _buildMatrixTable(
              sortedSets: sortedSets,
              sortedColours: sortedColours,
              colorSetWeights: colorSetWeights,
              colorTotalRolls: colorTotalRolls,
              colorTotalWeight: colorTotalWeight,
              colorMetadata: colorMetadata,
              setRackMap: setRackMap,
              setPalletMap: setPalletMap,
              font: font,
              boldFont: boldFont,
            ),
            pw.SizedBox(height: 30),
            // Signatures Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSigBox('Lot Incharge', inchargeImg, boldFont),
                _buildSigBox('Authorized', authImg, boldFont),
              ],
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(
    Map<String, dynamic> outward,
    pw.Font boldFont,
    pw.Font font, {
    String? setNo,
    String? rack,
    String? pallet,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'LOT OUTWARD REPORT (DC)',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 18,
                color: PdfColors.orange,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Party: ${outward['partyName'] ?? 'N/A'}', style: pw.TextStyle(font: font, fontSize: 10)),
            pw.Text('Lot Name: ${outward['lotName'] ?? 'N/A'}', style: pw.TextStyle(font: font, fontSize: 10)),
            pw.Text('Lot No: ${outward['lotNo'] ?? 'N/A'}', style: pw.TextStyle(font: font, fontSize: 10)),
            pw.Text('DIA: ${outward['dia'] ?? 'N/A'}', style: pw.TextStyle(font: font, fontSize: 10)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'DC No: ${outward['dcNo'] ?? 'N/A'}',
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.Text(
              'Date: ${outward['dateTime'] != null ? DateFormat('dd-MM-yyyy').format(DateTime.parse(outward['dateTime'])) : 'N/A'}',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
            pw.Text('Vehicle: ${outward['vehicleNo'] ?? 'N/A'}', style: pw.TextStyle(font: font, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildMatrixTable({
    required List<String> sortedSets,
    required List<String> sortedColours,
    required Map<String, Map<String, double>> colorSetWeights,
    required Map<String, int> colorTotalRolls,
    required Map<String, double> colorTotalWeight,
    required Map<String, Map<String, double>> colorMetadata,
    required Map<String, String> setRackMap,
    required Map<String, String> setPalletMap,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    final List<pw.TableRow> rows = [];

    // Header 1: Rack Name (per set)
    rows.add(
      pw.TableRow(
        children: [
          pw.SizedBox(), // S.No
          pw.Container(
            padding: const pw.EdgeInsets.all(5),
            alignment: pw.Alignment.centerLeft,
            child: pw.Text('Rack Name', style: pw.TextStyle(font: boldFont, fontSize: 9)),
          ),
          ...sortedSets.map((s) => pw.Container(
            padding: const pw.EdgeInsets.all(5),
            alignment: pw.Alignment.center,
            child: pw.Text(setRackMap[s] ?? '-', style: pw.TextStyle(font: boldFont, fontSize: 8)),
          )),
          pw.SizedBox(), // T.Roll
          pw.SizedBox(), // Total
          pw.SizedBox(), // Meter
        ],
      ),
    );

    // Header 2: Pallet (per set)
    rows.add(
      pw.TableRow(
        children: [
          pw.SizedBox(), // S.No
          pw.Container(
            padding: const pw.EdgeInsets.all(5),
            alignment: pw.Alignment.centerLeft,
            child: pw.Text('Pallet', style: pw.TextStyle(font: boldFont, fontSize: 9)),
          ),
          ...sortedSets.map((s) => pw.Container(
            padding: const pw.EdgeInsets.all(5),
            alignment: pw.Alignment.center,
            child: pw.Text(setPalletMap[s] ?? '-', style: pw.TextStyle(font: boldFont, fontSize: 8)),
          )),
          pw.SizedBox(), // T.Roll
          pw.SizedBox(), // Total
          pw.SizedBox(), // Meter
        ],
      ),
    );

    // Header 3: Table Column Headers
    final List<String> headers = [
      'S.No',
      'Colour',
      ...sortedSets.map((s) {
        if (RegExp(r'^\d+$').hasMatch(s)) return 'Set $s';
        if (s.toLowerCase().startsWith('s-')) return 'Set ${s.substring(2)}';
        return s;
      }),
      'T.Roll',
      'Total',
      'Meter'
    ];
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.orange),
        children: headers.map((h) => pw.Container(
          padding: const pw.EdgeInsets.all(5),
          alignment: pw.Alignment.center,
          child: pw.Text(h, style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10)),
        )).toList(),
      ),
    );

    // Data Rows
    double grantTotalWeight = 0;
    int grantTotalRolls = 0;
    double grantTotalMeters = 0;

    for (int i = 0; i < sortedColours.length; i++) {
        final colour = sortedColours[i];
        final totalWt = colorTotalWeight[colour] ?? 0;
        final totalR = colorTotalRolls[colour] ?? 0;
        
        final meta = colorMetadata[colour] ?? {};
        final gsm = meta['gsm'] ?? 0;
        final diaMetric = meta['dia'] ?? 0;

        double meters = 0;
        if (totalWt > 0 && gsm > 0 && diaMetric > 0) {
          meters = (totalWt * 1000.0) / (gsm * (diaMetric * 2.0 / 39.37));
        }

        grantTotalWeight += totalWt;
        grantTotalRolls += totalR;
        grantTotalMeters += meters;

        rows.add(
          pw.TableRow(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.center,
                child: pw.Text((i + 1).toString(), style: pw.TextStyle(font: font, fontSize: 10)),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(colour, style: pw.TextStyle(font: boldFont, fontSize: 10)),
              ),
              ...sortedSets.map((s) => pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  colorSetWeights[colour]?[s]?.toStringAsFixed(2) ?? '0.00',
                  style: pw.TextStyle(font: boldFont, fontSize: 10, color: (colorSetWeights[colour]?[s] ?? 0) > 0 ? PdfColors.black : PdfColors.grey400),
                ),
              )).toList(),
              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.center,
                child: pw.Text(totalR.toString(), style: pw.TextStyle(font: boldFont, fontSize: 10)),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(totalWt.toStringAsFixed(2), style: pw.TextStyle(font: boldFont, fontSize: 10)),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(meters.toStringAsFixed(1), style: pw.TextStyle(font: boldFont, fontSize: 10)),
              ),
            ],
          ),
        );
    }

    // Grand Total Row
    rows.add(
      pw.TableRow(
        children: [
          pw.SizedBox(),
          pw.Container(
            padding: const pw.EdgeInsets.all(5),
            alignment: pw.Alignment.centerLeft,
            child: pw.Text('TOTAL', style: pw.TextStyle(font: boldFont, fontSize: 10)),
          ),
          ...List.generate(sortedSets.length, (_) => pw.SizedBox()),
          pw.Container(
            padding: const pw.EdgeInsets.all(5),
            alignment: pw.Alignment.center,
            child: pw.Text(grantTotalRolls.toString(), style: pw.TextStyle(font: boldFont, fontSize: 10)),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(5),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(grantTotalWeight.toStringAsFixed(2), style: pw.TextStyle(font: boldFont, fontSize: 10)),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(5),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(grantTotalMeters.toStringAsFixed(1), style: pw.TextStyle(font: boldFont, fontSize: 10)),
          ),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(2),
        for (int k = 0; k < sortedSets.length; k++) k + 2: const pw.FlexColumnWidth(1),
        sortedSets.length + 2: const pw.FixedColumnWidth(40),
        sortedSets.length + 3: const pw.FixedColumnWidth(60),
        sortedSets.length + 4: const pw.FixedColumnWidth(50),
      },
      children: rows,
    );
  }

  pw.Widget _buildSigBox(String label, pw.MemoryImage? img, pw.Font boldFont) {
    return pw.Column(
      children: [
        pw.Container(
          height: 60,
          width: 100,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: img != null
              ? pw.Image(img, fit: pw.BoxFit.contain)
              : pw.Center(
                  child: pw.Text(
                    'Missing',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Font boldFont, pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generated by Garments App',
          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey),
        ),
        pw.Text(
          'Software Copy - Authorized Signature',
          style: pw.TextStyle(font: boldFont, fontSize: 8),
        ),
      ],
    );
  }
}
