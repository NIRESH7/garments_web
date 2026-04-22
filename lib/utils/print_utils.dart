import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PrintUtils {
  static pw.Widget buildCompanyHeader(pw.Font boldFont, pw.Font font, {pw.ImageProvider? logo}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 12),
                child: pw.Image(logo, height: 50, width: 50, fit: pw.BoxFit.contain),
              ),
            ],
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Om Vinayaka Garments',
                  style: pw.TextStyle(font: boldFont, fontSize: 24, color: PdfColors.blueGrey900),
                ),
                pw.Text(
                  'IDEAL innerwear',
                  style: pw.TextStyle(font: boldFont, fontSize: 13, color: PdfColors.grey700, letterSpacing: 1),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'SF No. 252/1, Balaji Nagar, Poyampalayam, Tirupur - 2. PIN: 641602',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
                ),
                pw.Text(
                  'Phone: +91 97900 52254, 97900 52252',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
                ),
                pw.Text(
                  'Email: idealovg@gmail.com | Web: www.idealinnerwear.com',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'GSTIN: 33BHNPS9629C1ZZ',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 10,
                    color: PdfColors.blue800,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.5, color: PdfColors.blueGrey100),
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
