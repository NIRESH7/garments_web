import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class ShadeCardPrintService {
  Future<void> printShadeCard(List<dynamic> groups) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    for (var group in groups) {
      final String groupName = group['groupName'] ?? 'No Lot';
      final List items = group['items'] ?? [];
      final List colours = group['colours'] ?? [];

      if (colours.isEmpty) continue;

      // Group images logic
      List<pw.Widget> colorWidgets = [];
      for (var color in colours) {
        final String? photoPath = color['photo'];
        pw.MemoryImage? netImage;
        if (photoPath != null) {
          try {
            final String fullImageUrl =
                '${ApiConstants.serverUrl}${photoPath.startsWith('/') ? photoPath : '/$photoPath'}';
            final response = await http.get(Uri.parse(fullImageUrl));
            if (response.statusCode == 200) {
              netImage = pw.MemoryImage(response.bodyBytes);
            }
          } catch (e) {}
        }

        colorWidgets.add(
          pw.Container(
            width: 140, // Slightly wider for better text fit
            margin: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.grey200, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  height: 120,
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.vertical(
                      top: pw.Radius.circular(11),
                    ),
                    image: netImage != null
                        ? pw.DecorationImage(
                            image: netImage,
                            fit: pw.BoxFit.cover,
                          )
                        : null,
                  ),
                  child: netImage == null
                      ? pw.Center(
                          child: pw.Text(
                            'NO IMAGE',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 8,
                              color: PdfColors.grey400,
                            ),
                          ),
                        )
                      : null,
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        (color['name'] ?? 'Unknown').toUpperCase(),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 10,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.indigo50,
                          borderRadius: pw.BorderRadius.all(
                            pw.Radius.circular(4),
                          ),
                        ),
                        child: pw.Text(
                          'GSM: ${color['gsm'] ?? group['gsm'] ?? 'N/A'}',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: PdfColors.indigo,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SHADE CARD MODULE',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 24,
                          color: PdfColors.indigo900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.Container(
                        height: 3,
                        width: 100,
                        margin: const pw.EdgeInsets.only(top: 4),
                        color: PdfColors.indigo,
                      ),
                    ],
                  ),
                  pw.Text(
                    'DATE: ${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'LOT NAME / GROUP',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          groupName,
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 16,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MAPPED ITEMS',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          items.isNotEmpty ? items.join(', ') : 'None',
                          style: pw.TextStyle(font: font, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 20),
            ],
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey),
            ),
          ),
          build: (context) => [
            pw.Wrap(
              spacing: 15,
              runSpacing: 15,
              alignment: pw.WrapAlignment.start,
              children: colorWidgets,
            ),
          ],
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'ShadeCardReport_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
