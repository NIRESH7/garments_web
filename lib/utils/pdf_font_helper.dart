import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfFontHelper {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<pw.Font> get regular async {
    _regular ??= await PdfGoogleFonts.robotoRegular();
    return _regular!;
  }

  static Future<pw.Font> get bold async {
    _bold ??= await PdfGoogleFonts.robotoBold();
    return _bold!;
  }

  static Future<void> preload() async {
    await regular;
    await bold;
  }
}
