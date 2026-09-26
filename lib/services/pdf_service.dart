import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/document_model.dart';

class PdfService {
  /// Builds a multi-page PDF matching A4 dimensions from document pages
  static Future<File> generatePdf(DocumentItem document) async {
    final pdf = pw.Document();

    for (final page in document.pages) {
      final imagePath = page.displayPath;
      final file = File(imagePath);
      if (!await file.exists()) continue;

      final imageBytes = await file.readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);

      // A4 format: 595.28 x 841.89 points
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Image(
                  pdfImage,
                  fit: pw.BoxFit.contain,
                ),
              ),
            );
          },
        ),
      );
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final cleanDocName = document.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final pdfFile = File('${outputDir.path}/$cleanDocName.pdf');
    await pdfFile.writeAsBytes(await pdf.save());
    return pdfFile;
  }

  /// Direct print / preview PDF dialog
  static Future<void> printDocument(DocumentItem document) async {
    final pdf = pw.Document();

    for (final page in document.pages) {
      final imagePath = page.displayPath;
      final file = File(imagePath);
      if (!await file.exists()) continue;

      final imageBytes = await file.readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Image(
                  pdfImage,
                  fit: pw.BoxFit.contain,
                ),
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: document.name,
    );
  }
}
