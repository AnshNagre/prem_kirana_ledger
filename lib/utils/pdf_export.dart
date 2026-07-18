import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/customer.dart';
import '../models/transaction.dart';

/// Builds and shares/prints a ledger account statement PDF for [customer],
/// matching the layout produced by jsPDF + jsPDF-autotable in the original
/// HTML app (header, customer info block, balance summary box, transactions
/// table, footer with page numbers).
Future<void> exportCustomerLedgerPdf(Customer customer) async {
  final doc = pw.Document();
  const brand = PdfColor.fromInt(0xFFE8A33D);
  const udharRed = PdfColor.fromInt(0xFFE23F49);
  const slate900 = PdfColor.fromInt(0xFF0F172A);
  const slate600 = PdfColor.fromInt(0xFF475569);
  const slate500 = PdfColor.fromInt(0xFF64748B);
  const slate400 = PdfColor.fromInt(0xFF94A3B8);
  const slate50 = PdfColor.fromInt(0xFFF8FAFC);
  const slate200 = PdfColor.fromInt(0xFFE2E8F0);

  final totalUdhar = customer.totalUdharGiven;
  final now = DateTime.now();
  final statementDate =
      '${DateFormat('dd/MM/yyyy').format(now)} ${DateFormat('hh:mm a').format(now)}';

  final tableRows = customer.transactions.map((t) {
    final prefix = t.type.isUdhar ? '+' : '-';
    return [
      t.date,
      t.time,
      t.type.label,
      '$prefix Rs. ${t.amount.toStringAsFixed(0)}',
      'Rs. ${t.balAfter.toStringAsFixed(0)}',
      t.desc.isEmpty ? '-' : t.desc,
    ];
  }).toList();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(14 * PdfPageFormat.mm, 20 * PdfPageFormat.mm,
          14 * PdfPageFormat.mm, 20 * PdfPageFormat.mm),
      header: (context) {
        if (context.pageNumber > 1) return pw.SizedBox();
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('PREM KIRANA & GENERAL STORE',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: slate900)),
            pw.SizedBox(height: 2),
            pw.Text('Swami Vivekanand Nagar, KANHAN', style: const pw.TextStyle(fontSize: 9, color: slate500)),
            pw.SizedBox(height: 8),
            pw.Divider(color: slate200, thickness: 0.5),
            pw.SizedBox(height: 8),
            pw.Text('LEDGER ACCOUNT STATEMENT',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: slate900)),
            pw.SizedBox(height: 4),
            pw.Text('Customer Name : ${customer.name}', style: const pw.TextStyle(fontSize: 10, color: slate600)),
            pw.Text('Mobile Number : ${customer.phone}', style: const pw.TextStyle(fontSize: 10, color: slate600)),
            pw.Text('Statement Date: $statementDate', style: const pw.TextStyle(fontSize: 10, color: slate600)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: pw.BoxDecoration(
                color: slate50,
                border: pw.Border.all(color: slate200, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TOTAL UDHAR GIVEN',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: slate500)),
                      pw.SizedBox(height: 4),
                      pw.Text('Rs. ${totalUdhar.toStringAsFixed(0)}',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: udharRed)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('NET OUTSTANDING BALANCE',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: slate500)),
                      pw.SizedBox(height: 4),
                      pw.Text('Rs. ${customer.balance.toStringAsFixed(0)}',
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: customer.balance > 0 ? udharRed : slate500)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
          ],
        );
      },
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: slate400)),
          pw.Text('Generated from Prem Kirana Ledger App - Confidential',
              style: const pw.TextStyle(fontSize: 8, color: slate400)),
        ],
      ),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: const ['Date', 'Time', 'Type', 'Amount', 'Balance After', 'Remarks / Description'],
          data: tableRows,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: brand),
          cellStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: slate600),
          border: pw.TableBorder.all(color: slate200, width: 0.4),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: const {
            0: pw.FlexColumnWidth(1.6),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(1.3),
            3: pw.FlexColumnWidth(1.6),
            4: pw.FlexColumnWidth(1.8),
            5: pw.FlexColumnWidth(2.6),
          },
        ),
      ],
    ),
  );

  final dateClean = DateFormat('dd_MM_yyyy').format(now);
  final nameClean = customer.name.replaceAll(RegExp(r'\s+'), '_');
  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: '${nameClean}_Ledger_$dateClean.pdf',
  );
}
