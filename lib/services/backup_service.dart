import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';
import '../models/transaction_record.dart';

class BackupService {
  final DBHelper _dbHelper = DBHelper();

  // Export transaction logs to CSV and share the file
  Future<void> exportToCSV(List<TransactionRecord> records, String currency, {String fileName = 'abhi_atm_transactions'}) async {
    if (records.isEmpty) return;

    final StringBuffer csvBuffer = StringBuffer();
    // CSV Headers
    csvBuffer.writeln('ATM ID,Date,Transaction Count,Rate,Total Earnings ($currency),Remarks');

    // Add rows
    for (var record in records) {
      csvBuffer.writeln(
        '"${record.atmId}","${record.dateString}",${record.count},${record.rate},${record.total},"${record.remarks ?? ''}"',
      );
    }

    final directory = await getTemporaryDirectory();
    final sanitizedFileName = fileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final file = File(p.join(directory.path, '$sanitizedFileName.csv'));
    await file.writeAsString(csvBuffer.toString());

    // Share file
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Abhi ATM Transactions CSV Export',
    );
  }

  // Export transaction logs to Excel (represented as CSV formatted for Excel)
  Future<void> exportToExcel(List<TransactionRecord> records, String currency, {String fileName = 'abhi_atm_transactions_excel'}) async {
    if (records.isEmpty) return;

    final StringBuffer csvBuffer = StringBuffer();
    // Excel-friendly CSV with BOM for encoding support
    csvBuffer.write('\uFEFF'); // Byte Order Mark for Excel UTF-8
    csvBuffer.writeln('ATM ID,Date,Transaction Count,Rate,Total Earnings ($currency),Remarks');

    for (var record in records) {
      csvBuffer.writeln(
        '"${record.atmId}","${record.dateString}",${record.count},${record.rate},${record.total},"${record.remarks ?? ''}"',
      );
    }

    final directory = await getTemporaryDirectory();
    final sanitizedFileName = fileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final file = File(p.join(directory.path, '$sanitizedFileName.xlsx'));
    await file.writeAsString(csvBuffer.toString());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: 'Abhi ATM Transactions Excel Export',
    );
  }

  // Export transaction logs to PDF report and share the file
  Future<void> exportToPDF(
    List<TransactionRecord> records,
    String currency,
    String employeeName, {
    String reportType = 'All-Time',
    String? periodRange,
  }) async {
    final pdf = pw.Document();

    // Summary calculations
    final totalTransactions = records.fold<int>(0, (sum, r) => sum + r.count);
    final totalEarnings = records.fold<double>(0, (sum, r) => sum + r.total);
    final averageCount = records.isEmpty ? 0 : totalTransactions / records.length;
    final averageEarnings = records.isEmpty ? 0 : totalEarnings / records.length;

    // Add page to PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header Group
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Abhi ATM Manager',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                    ),
                    pw.Text(
                      reportType,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Employee: $employeeName', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    if (periodRange != null)
                      pw.Text(
                        'Report Period: $periodRange',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    pw.Text(
                      'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.green800),
            pw.SizedBox(height: 16),

            // Summary Table
            pw.Text('Summary Statistics', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Value'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
              cellAlignment: pw.Alignment.centerLeft,
              data: [
                ['Total Logs', '${records.length} days'],
                ['Total ATM Transactions', '$totalTransactions'],
                ['Total Earnings', '$currency ${totalEarnings.toStringAsFixed(2)}'],
                ['Average Transactions/Day', averageCount.toStringAsFixed(1)],
                ['Average Earnings/Day', '$currency ${averageEarnings.toStringAsFixed(2)}'],
              ],
            ),
            pw.SizedBox(height: 20),

            // History Table
            pw.Text('Transaction Logs', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['ATM ID', 'Date', 'Transactions', 'Rate ($currency)', 'Total ($currency)', 'Remarks'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              cellAlignment: pw.Alignment.centerLeft,
              data: records.map((record) {
                return [
                  record.atmId,
                  record.dateString,
                  '${record.count}',
                  record.rate.toStringAsFixed(2),
                  record.total.toStringAsFixed(2),
                  record.remarks ?? '',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 30),

            // Branded Footer
            pw.Divider(thickness: 0.8, color: PdfColors.grey400),
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Column(
                children: [
                  pw.Text(
                    'Generated by Abhi ATM Manager',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Designed & Developed with ❤️ by Amitesh Nagar',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    '© 2026 All Rights Reserved.',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final sanitizedReportType = reportType.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final file = File(p.join(directory.path, 'abhi_atm_${sanitizedReportType}_report.pdf'));
    await file.writeAsBytes(await pdf.save());

    // Share PDF file
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Abhi ATM $reportType Transactions PDF Report',
    );
  }

  // Backup SQLite database file
  Future<void> backupDatabase() async {
    await _dbHelper.closeDatabase(); // Ensure connection is closed
    final dbPath = await _dbHelper.getDbPath();
    final dbFile = File(dbPath);

    if (await dbFile.exists()) {
      final directory = await getTemporaryDirectory();
      final backupFile = File(p.join(directory.path, 'abhi_transactions_backup.db'));
      
      // Copy database file
      await dbFile.copy(backupFile.path);
      
      // Share backup file
      await Share.shareXFiles(
        [XFile(backupFile.path)],
        subject: 'Abhi ATM SQLite Database Backup',
      );
    }
  }

  // Restore SQLite database file from user selection
  Future<bool> restoreDatabase() async {
    // Pick SQLite file
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any, // Safe fallback
    );

    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;
      
      // Basic check
      if (!selectedPath.endsWith('.db')) {
        return false;
      }

      final backupFile = File(selectedPath);
      if (await backupFile.exists()) {
        // Delete current database file
        await _dbHelper.deleteDatabaseFile();
        
        final dbPath = await _dbHelper.getDbPath();
        
        // Copy selected file to standard database location
        await backupFile.copy(dbPath);
        
        // Trigger database initialization to verify
        await _dbHelper.database;
        return true;
      }
    }
    return false;
  }
}
