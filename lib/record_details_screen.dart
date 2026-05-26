import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class RecordDetailsScreen extends StatelessWidget {
  final Map<String, String> record;
  final List<String> permittedColumns;

  const RecordDetailsScreen({
    super.key,
    required this.record,
    required this.permittedColumns,
  });

  String get _title {
    final ivNoKey = record.keys.firstWhere(
      (k) => k.toLowerCase() == 'iv no',
      orElse: () => 'Record Details',
    );
    return record[ivNoKey] ?? 'Record Details';
  }

  String get _date {
    final dateKey = record.keys.firstWhere(
      (k) => k.toLowerCase() == 'date',
      orElse: () => '',
    );
    return dateKey.isNotEmpty ? (record[dateKey] ?? '-') : '-';
  }

  Future<void> _exportToPdf(BuildContext context) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'WorkEazi Record Detail',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#4A5568'),
                        ),
                      ),
                      pw.Text(
                        _date,
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColor.fromHex('#718096'),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#E2E8F0')),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Invoice No: $_title',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#2D3748'),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E0'), width: 1),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(5),
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F7FAFC')),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Field',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Value',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      // Data Rows
                      ...permittedColumns.map((col) {
                        final actualKey = record.keys.firstWhere(
                          (k) => k.toLowerCase() == col.toLowerCase(),
                          orElse: () => col,
                        );
                        final val = record[actualKey] ?? '-';
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(col),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(val),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                  pw.SizedBox(height: 40),
                  pw.Center(
                    child: pw.Text(
                      'Generated automatically via WorkEazi User Portal.',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColor.fromHex('#A0AEC0'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/record_$_title.pdf");
      await file.writeAsBytes(await pdf.save());

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'PDF Export for $_title');
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'PDF Export failed: $e');
      }
    }
  }

  Future<void> _exportToDocx(BuildContext context) async {
    try {
      // Create a styled text document representing the details
      final buffer = StringBuffer();
      buffer.writeln('========================================');
      buffer.writeln('          WORKEAZI RECORD EXPORT        ');
      buffer.writeln('========================================');
      buffer.writeln('Invoice No: $_title');
      buffer.writeln('Date: $_date');
      buffer.writeln('----------------------------------------');
      
      for (final col in permittedColumns) {
        final actualKey = record.keys.firstWhere(
          (k) => k.toLowerCase() == col.toLowerCase(),
          orElse: () => col,
        );
        final val = record[actualKey] ?? '-';
        buffer.writeln('${col.padRight(20)}: $val');
      }
      buffer.writeln('========================================');
      buffer.writeln('Generated via WorkEazi User Portal.');

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/record_$_title.docx");
      await file.writeAsString(buffer.toString());

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'DOCX Export for $_title');
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'DOCX Export failed: $e');
      }
    }
  }

  Future<void> _exportToCsv(BuildContext context) async {
    try {
      final buffer = StringBuffer();
      
      // Header row
      buffer.writeln('Field,Value');
      
      // Invoice Info
      buffer.writeln('Invoice No,$_title');
      buffer.writeln('Date,$_date');
      
      // Columns
      for (final col in permittedColumns) {
        final actualKey = record.keys.firstWhere(
          (k) => k.toLowerCase() == col.toLowerCase(),
          orElse: () => col,
        );
        final val = record[actualKey] ?? '-';
        // Clean values for CSV compatibility
        final cleanCol = col.contains(',') ? '"$col"' : col;
        final cleanVal = val.contains(',') ? '"$val"' : val;
        buffer.writeln('$cleanCol,$cleanVal');
      }

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/record_$_title.csv");
      await file.writeAsString(buffer.toString());

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'CSV Export for $_title');
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'CSV Export failed: $e');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Export Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Invoice details',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        previousPageTitle: 'Back',
        backgroundColor: const Color(0xFFF2F2F7),
      ),
      backgroundColor: const Color(0xFFF2F2F7),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Main Branding Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'WORKEAZI INVOICE',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: CupertinoColors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _title,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.calendar,
                              color: CupertinoColors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _date,
                              style: TextStyle(
                                color: CupertinoColors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Data Fields Card
                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CupertinoColors.systemGrey5, width: 1),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: const [
                              Icon(
                                CupertinoIcons.list_bullet,
                                color: Color(0xFF667EEA),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Invoice Properties',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: CupertinoColors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 0.5, color: CupertinoColors.systemGrey5),
                        ...permittedColumns.map((col) {
                          final actualKey = record.keys.firstWhere(
                            (k) => k.toLowerCase() == col.toLowerCase(),
                            orElse: () => col,
                          );
                          final val = record[actualKey] ?? '-';
                          final isLast = permittedColumns.last == col;

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        col,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: CupertinoColors.systemGrey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        val.isEmpty ? '-' : val,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: CupertinoColors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isLast)
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  height: 0.5,
                                  color: CupertinoColors.systemGrey5,
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Premium Download / Export Options Bottom Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                border: const Border(
                  top: BorderSide(color: CupertinoColors.systemGrey5, width: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'EXPORT & DOWNLOAD OPTIONS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.systemGrey,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // PDF Download Button
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: const Color(0xFF667EEA),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () => _exportToPdf(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(CupertinoIcons.doc_richtext, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'PDF',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // DOCX Download Button
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: const Color(0xFF4A5568),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () => _exportToDocx(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(CupertinoIcons.doc_text, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'DOCX',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // CSV Download Button
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: CupertinoColors.activeGreen,
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () => _exportToCsv(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(CupertinoIcons.table, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'CSV',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
