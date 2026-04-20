import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PrintUtils {
  static pw.Widget buildCompanyHeader(pw.Font boldFont, pw.Font font, {pw.ImageProvider? logo}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 10),
                child: pw.Image(logo, height: 60, width: 60, fit: pw.BoxFit.contain),
              ),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Om Vinayaka Garments',
                    style: pw.TextStyle(font: boldFont, fontSize: 20),
                  ),
                  pw.Text(
                    'IDEAL innerwear',
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'SF No. 252/1, Merkalath Thottam North, Balaji Nagar, Poyampalayam,',
                    style: pw.TextStyle(font: font, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'Pooluvapatti (P.O), Tirupur - 2.',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'Phone: 97900 52254, 97900 52252',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                  pw.Text(
                    'Email: idealovg@gmail.com | Web: www.idealinnerwear.com',
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'GSTIN: 33BHNPS9629C1ZZ',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 9,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
            ),
            // Mirror spacer so company name stays centered
            if (logo != null) pw.SizedBox(width: 60),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.5, color: PdfColors.grey300),
      ],
    );
  }

  static pw.Widget buildColourCell(String name, pw.Font font, {pw.MemoryImage? image, String? hexColor}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 10,
          height: 10,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            color: hexColor != null ? PdfColor.fromHex(hexColor) : PdfColors.grey300,
            image: image != null ? pw.DecorationImage(image: image, fit: pw.BoxFit.cover) : null,
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(name.toUpperCase(), style: pw.TextStyle(font: font, fontSize: 13)),
      ],
    );
  }
}
