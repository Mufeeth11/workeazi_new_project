import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class RecordDetailsScreen extends StatefulWidget {
  final Map<String, String> record;
  final List<String> permittedColumns;

  const RecordDetailsScreen({
    super.key,
    required this.record,
    required this.permittedColumns,
  });

  @override
  State<RecordDetailsScreen> createState() => _RecordDetailsScreenState();
}

class _RecordDetailsScreenState extends State<RecordDetailsScreen> {
  String _selectedExtension = '.pdf'; // Default selected extension
  bool _isDropdownOpen = false; // Whether the custom format dropdown is expanded

  String _formatValueForDocxOrCsv(String col, String val) {
    if (val.isEmpty || val == '-') return val;
    String cleanVal = val.replaceAll('\u20B9', '₹').replaceAll('₹', '₹');
    final lowerCol = col.toLowerCase();
    final isMonetary =
        lowerCol.contains('value') ||
        lowerCol.contains('amount') ||
        lowerCol.contains('price') ||
        lowerCol.contains('total') ||
        lowerCol.contains('balance') ||
        lowerCol.contains('paid');

    if (isMonetary) {
      if (!cleanVal.contains('₹') &&
          !cleanVal.contains('Rs') &&
          !cleanVal.contains('\$')) {
        return '₹$cleanVal';
      }
    }
    return cleanVal;
  }

  String _formatValueForPdf(String col, String val) {
    if (val.isEmpty || val == '-') return val;
    String cleanVal = val.replaceAll('₹', 'Rs. ').replaceAll('\u20B9', 'Rs. ');
    final lowerCol = col.toLowerCase();
    final isMonetary =
        lowerCol.contains('value') ||
        lowerCol.contains('amount') ||
        lowerCol.contains('price') ||
        lowerCol.contains('total') ||
        lowerCol.contains('balance') ||
        lowerCol.contains('paid');

    if (isMonetary) {
      if (!cleanVal.contains('Rs') && !cleanVal.contains('\$')) {
        return 'Rs. $cleanVal';
      }
    }
    return cleanVal;
  }

  String get _title {
    final ivNoKey = widget.record.keys.firstWhere(
      (k) => k.toLowerCase() == 'iv no',
      orElse: () => 'Record Details',
    );
    return widget.record[ivNoKey] ?? 'Record Details';
  }

  String get _date {
    final dateKey = widget.record.keys.firstWhere(
      (k) => k.toLowerCase() == 'date',
      orElse: () => '',
    );
    return dateKey.isNotEmpty ? (widget.record[dateKey] ?? '-') : '-';
  }

  Future<void> _exportToPdf() async {
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
                  pw.Divider(
                    thickness: 1.5,
                    color: PdfColor.fromHex('#E2E8F0'),
                  ),
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
                    border: pw.TableBorder.all(
                      color: PdfColor.fromHex('#CBD5E0'),
                      width: 1,
                    ),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(5),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#F7FAFC'),
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Field',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Value',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ...widget.permittedColumns.map((col) {
                        final actualKey = widget.record.keys.firstWhere(
                          (k) => k.toLowerCase() == col.toLowerCase(),
                          orElse: () => col,
                        );
                        final val = widget.record[actualKey] ?? '-';
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(col),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(_formatValueForPdf(col, val)),
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

      final xFile = XFile(file.path, mimeType: 'application/pdf');
      await Share.shareXFiles([xFile], text: 'PDF Export for $_title');
    } catch (e) {
      if (mounted) {
        _showError('PDF Export failed: $e');
      }
    }
  }

  Future<void> _exportToDoc() async {
    try {
      final buffer = StringBuffer();

      buffer.write(r'{\rtf1\ansi\deff0 {\fonttbl {\f0\fnil\fcharset0 Arial;}}');
      buffer.write(
        r'{\colortbl ;\red102\green126\blue234;\red74\green85\blue104;\red113\green128\blue150;}',
      );

      buffer.write(r'\fs36\b\cf1 WorkEazi Record Export\b0\fs24\cf0\par');
      buffer.write(r'\cf3 Date: ' + _date + r'\cf0\par\par');
      buffer.write(r'\cf2\fs28\b Invoice Details:\b0\cf0\fs24\par');
      buffer.write(
        r'--------------------------------------------------\par\par',
      );

      for (final col in widget.permittedColumns) {
        final actualKey = widget.record.keys.firstWhere(
          (k) => k.toLowerCase() == col.toLowerCase(),
          orElse: () => col,
        );
        final val = widget.record[actualKey] ?? '-';
        final formattedVal = _formatValueForDocxOrCsv(col, val);

        buffer.write(r'\b ' + col + r':\b0  ' + formattedVal + r'\par\par');
      }

      buffer.write(
        r'--------------------------------------------------\par\par',
      );
      buffer.write(r'\fs18\i Generated via WorkEazi User Portal.\i0\par}');

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/record_$_title.doc");
      await file.writeAsString(buffer.toString());

      final xFile = XFile(file.path, mimeType: 'application/msword');
      await Share.shareXFiles([
        xFile,
      ], text: 'Word Document Export for $_title');
    } catch (e) {
      if (mounted) {
        _showError('Word Document Export failed: $e');
      }
    }
  }

  Future<void> _exportToCsv() async {
    try {
      final buffer = StringBuffer();

      buffer.writeln('Field,Value');
      buffer.writeln('Invoice No,$_title');
      buffer.writeln('Date,$_date');

      for (final col in widget.permittedColumns) {
        final actualKey = widget.record.keys.firstWhere(
          (k) => k.toLowerCase() == col.toLowerCase(),
          orElse: () => col,
        );
        final val = widget.record[actualKey] ?? '-';
        final formattedVal = _formatValueForDocxOrCsv(col, val);
        final cleanCol = col.contains(',') ? '"$col"' : col;
        final cleanVal = formattedVal.contains(',')
            ? '"$formattedVal"'
            : formattedVal;
        buffer.writeln('$cleanCol,$cleanVal');
      }

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/record_$_title.csv");
      await file.writeAsString(buffer.toString());

      final xFile = XFile(file.path, mimeType: 'text/csv');
      await Share.shareXFiles([xFile], text: 'CSV Export for $_title');
    } catch (e) {
      if (mounted) {
        _showError('CSV Export failed: $e');
      }
    }
  }

  void _triggerExport() {
    switch (_selectedExtension) {
      case '.pdf':
        _exportToPdf();
        break;
      case '.doc':
        _exportToDoc();
        break;
      case '.csv':
        _exportToCsv();
        break;
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownItem(
    String ext,
    String title,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedExtension == ext;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedExtension = ext;
          _isDropdownOpen = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected
            ? color.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            if (isSelected)
              Icon(Icons.check, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  IconData _getExtensionIcon() {
    switch (_selectedExtension) {
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
      case '.doc':
        return Icons.description_outlined;
      case '.csv':
        return Icons.table_chart_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getExtensionColor() {
    switch (_selectedExtension) {
      case '.pdf':
        return const Color(0xFF667EEA);
      case '.doc':
        return const Color(0xFF4A5568);
      case '.csv':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Invoice Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
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
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  color: Colors.white,
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
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _date,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.list_alt_outlined,
                                color: Color(0xFF667EEA),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Invoice Properties',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey.shade200),
                        ...widget.permittedColumns.map((col) {
                          final actualKey = widget.record.keys.firstWhere(
                            (k) => k.toLowerCase() == col.toLowerCase(),
                            orElse: () => col,
                          );
                          final val = widget.record[actualKey] ?? '-';
                          final isLast = widget.permittedColumns.last == col;

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        col,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        _formatValueForDocxOrCsv(
                                          col,
                                          val.isEmpty ? '-' : val,
                                        ),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isLast)
                                Divider(
                                  height: 1,
                                  color: Colors.grey.shade200,
                                  indent: 16,
                                  endIndent: 16,
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

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDropdownOpen = !_isDropdownOpen;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getExtensionIcon(),
                                color: _getExtensionColor(),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Export File Format',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                _selectedExtension.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _getExtensionColor(),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _isDropdownOpen
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isDropdownOpen) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildDropdownItem(
                            '.pdf',
                            'PDF Document (.pdf)',
                            Icons.picture_as_pdf_outlined,
                            const Color(0xFF667EEA),
                          ),
                          Divider(height: 1, color: Colors.grey.shade200),
                          _buildDropdownItem(
                            '.doc',
                            'Word Document (.doc)',
                            Icons.description_outlined,
                            const Color(0xFF4A5568),
                          ),
                          Divider(height: 1, color: Colors.grey.shade200),
                          _buildDropdownItem(
                            '.csv',
                            'Spreadsheet (.csv)',
                            Icons.table_chart_outlined,
                            Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  ElevatedButton(
                    onPressed: _triggerExport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667EEA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.share_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Export & Share $_selectedExtension',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
}
