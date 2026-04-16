import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PrintUtils {
  static pw.Widget buildCompanyHeader(pw.Font boldFont, pw.Font font, {pw.ImageProvider? logo}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null) ...[
          pw.Center(
            child: pw.Image(logo, height: 50, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 4),
        ],
        pw.Text(
          'Om Vinayaka Garments',
          style: pw.TextStyle(font: boldFont, fontSize: 18),
        ),
        pw.Text(
          'IDEAL innerwear',
          style: pw.TextStyle(font: boldFont, fontSize: 14),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'SF No. 252/1, Merkalath Thottam North, Balaji Nagar, Poyampalayam,',
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
        pw.Text(
          'Pooluvapatti (P.O), Tirupur - 2.',
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'Phone: 97900 52254, 97900 52252',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          ],
        ),
        pw.Text(
          'Email: idealovg@gmail.com | Web: www.idealinnerwear.com',
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'GSTIN: 33BHNPS9629C1ZZ',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 10,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1, color: PdfColors.grey300),
      ],
    );
  }
}
