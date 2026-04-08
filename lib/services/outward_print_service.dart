import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../utils/print_utils.dart';

class OutwardPrintService {
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
      final response = await http.get(Uri.parse(url));
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

    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    // Fetch signatures
    final inchargeImg = await _loadNetImage(
      outward['lotInchargeSignature']?.toString(),
    );
    final authImg = await _loadNetImage(
      outward['authorizedSignature']?.toString(),
    );

    final items = outward['items'] as List<dynamic>? ?? [];

    // Process items for table: Include Set, Rack, Pallet Info
    final List<Map<String, dynamic>> flatItems = [];
    double totalWeight = 0;
    int totalRolls = 0;
    double totalMeters = 0;

    for (var set in items) {
      final setNo = set['set_no']?.toString() ?? 'N/A';
      final rack = set['rack_name']?.toString() ?? 'N/A';
      final pallet = set['pallet_number']?.toString() ?? 'N/A';
      final colours = set['colours'] as List<dynamic>? ?? [];

      for (var col in colours) {
        final name = col['colour']?.toString() ?? 'N/A';
        final wt = (col['weight'] as num?)?.toDouble() ?? 0;
        final r = (col['no_of_rolls'] as num?)?.toInt() ?? 0;

        final gsm = (col['gsm'] as num?)?.toDouble() ?? 0;
        final dia = (col['cutting_dia'] as num?)?.toDouble() ??
            (col['dia'] as num?)?.toDouble() ??
            0;

        double meters = 0;
        if (wt > 0 && gsm > 0 && dia > 0) {
          meters = (wt * 1000.0) / (gsm * (dia * 2.0 / 39.37));
        }

        flatItems.add({
          'setNo': setNo,
          'rack': rack,
          'pallet': pallet,
          'colour': name,
          'weight': wt,
          'rolls': r,
          'meters': meters,
        });

        totalWeight += wt;
        totalRolls += r;
        totalMeters += double.parse(meters.toStringAsFixed(1));
      }
    }

    // Extract distinct Set, Rack, Pallet info for the header
    final Set<String> setNos = {};
    final Set<String> racks = {};
    final Set<String> pallets = {};

    for (var set in items) {
      if (set['set_no'] != null) setNos.add(set['set_no'].toString());
      if (set['rack_name'] != null) racks.add(set['rack_name'].toString());
      if (set['pallet_number'] != null) {
        pallets.add(set['pallet_number'].toString());
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              PrintUtils.buildCompanyHeader(boldFont, font),
              _buildHeader(
                outward,
                boldFont,
                setNo: setNos.join(', '),
                rack: racks.join(', '),
                pallet: pallets.join(', '),
              ),
              pw.SizedBox(height: 20),
              _buildTable(
                flatItems,
                totalWeight,
                totalRolls,
                totalMeters,
                font,
                boldFont,
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
              pw.Spacer(),
              _buildFooter(boldFont),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(
    Map<String, dynamic> outward,
    pw.Font boldFont, {
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
            pw.Text('Party: ${outward['partyName'] ?? 'N/A'}'),
            pw.Text('Lot Name: ${outward['lotName'] ?? 'N/A'}'),
            pw.Text('Lot No: ${outward['lotNo'] ?? 'N/A'}'),
            pw.Text('DIA: ${outward['dia'] ?? 'N/A'}'),
            if (setNo != null && setNo.isNotEmpty) pw.Text('Set No: $setNo'),
            if (rack != null && rack.isNotEmpty) pw.Text('Rack: $rack'),
            if (pallet != null && pallet.isNotEmpty) pw.Text('Pallet: $pallet'),
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
            ),
            pw.Text('Vehicle: ${outward['vehicleNo'] ?? 'N/A'}'),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTable(
    List<Map<String, dynamic>> flatItems,
    double totalWt,
    int totalRolls,
    double totalMeters,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Table.fromTextArray(
      headers: ['Colour', 'Total Rolls', 'Total Weight (Kg)', 'Total Meter'],
      data: [
        ...flatItems.map(
          (row) => [
            row['colour'],
            row['rolls'].toString(),
            row['weight'].toStringAsFixed(2),
            row['meters'].toStringAsFixed(1),
          ],
        ),
        // Total Row
        [
          'TOTAL',
          totalRolls.toString(),
          totalWt.toStringAsFixed(2),
          totalMeters.toStringAsFixed(1)
        ],
      ],
      headerStyle: pw.TextStyle(
        font: boldFont,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.orange),
      cellStyle: pw.TextStyle(font: font, fontSize: 10),
      cellAlignment: pw.Alignment.center,
      border: pw.TableBorder.all(color: PdfColors.grey400),
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

  pw.Widget _buildFooter(pw.Font boldFont) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generated by Garments App',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
        ),
        pw.Text(
          'Software Copy - Authorized Signature',
          style: pw.TextStyle(font: boldFont, fontSize: 8),
        ),
      ],
    );
  }
}
