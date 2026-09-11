import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/customer.dart';
import '../models/transaction.dart';
import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import 'formatters.dart';

class BackupManager {
  /// Exports all customers and transactions to a structured .json backup file and triggers share/save.
  static Future<void> exportBackupJson(BuildContext context, List<Customer> customers) async {
    final c = context.colors;
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final formattedDisplayDate = DateFormat('dd MMM yyyy, hh:mm a').format(now);

      final totalUdhar = customers.fold(0.0, (sum, cust) => sum + (cust.balance > 0 ? cust.balance : 0));
      final totalTxnCount = customers.fold(0, (sum, cust) => sum + cust.transactions.length);

      final backupPayload = {
        'app': 'Prem Kirana Ledger',
        'version': '1.0.2',
        'exportDate': now.toIso8601String(),
        'exportDateDisplay': formattedDisplayDate,
        'customerCount': customers.length,
        'transactionCount': totalTxnCount,
        'totalUdhar': totalUdhar,
        'customers': customers.map((cust) => cust.toJson()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backupPayload);
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/prem_kirana_backup_$dateStr.json';
      final file = File(filePath);
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Prem Kirana Ledger Backup ($dateStr)',
        text: 'Prem Kirana Ledger full data backup created on $formattedDisplayDate ($totalTxnCount transactions, ${customers.length} accounts).',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup created: ${customers.length} accounts & $totalTxnCount entries ready to save/share.'),
            backgroundColor: c.jama,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate backup: $e'),
            backgroundColor: c.udhar,
          ),
        );
      }
    }
  }

  /// Opens a file picker for the user to select a .json backup file, validates it, and restores data.
  static Future<void> importBackupJson(BuildContext context) async {
    final c = context.colors;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return;
      }

      final file = File(result.files.first.path!);
      final content = await file.readAsString();

      dynamic decoded;
      try {
        decoded = jsonDecode(content);
      } catch (err) {
        if (context.mounted) {
          _showErrorDialog(context, 'Invalid File Format', 'The selected file is not a valid JSON file. Please select a valid Prem Kirana Ledger backup file.');
        }
        return;
      }

      List<dynamic> rawCustomersList = [];
      String? backupDateDisplay;

      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('customers') && decoded['customers'] is List) {
          rawCustomersList = decoded['customers'] as List<dynamic>;
          backupDateDisplay = decoded['exportDateDisplay'] as String?;
        } else {
          if (context.mounted) {
            _showErrorDialog(context, 'Unrecognized Backup', 'This JSON file does not contain a valid "customers" ledger array.');
          }
          return;
        }
      } else if (decoded is List) {
        rawCustomersList = decoded;
      } else {
        if (context.mounted) {
          _showErrorDialog(context, 'Unrecognized Format', 'Could not parse ledger data from this file.');
        }
        return;
      }

      final List<Customer> restoredCustomers = [];
      for (final item in rawCustomersList) {
        if (item is Map<String, dynamic>) {
          restoredCustomers.add(Customer.fromJson(item));
        }
      }

      if (restoredCustomers.isEmpty) {
        if (context.mounted) {
          _showErrorDialog(context, 'No Accounts Found', 'The backup file contained 0 customer accounts.');
        }
        return;
      }

      final totalTxnCount = restoredCustomers.fold(0, (sum, cust) => sum + cust.transactions.length);
      final totalUdhar = restoredCustomers.fold(0.0, (sum, cust) => sum + (cust.balance > 0 ? cust.balance : 0));

      if (!context.mounted) return;

      // Show confirmation dialog before replacing state
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: c.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.brandPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.settings_backup_restore_rounded, color: c.brandPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Restore Ledger Data?', style: TextStyle(color: c.textBody, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will restore your ledger accounts and all past transactions from the backup file.',
                style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.borderHairline),
                ),
                child: Column(
                  children: [
                    _StatRow(label: 'Total Accounts', value: '${restoredCustomers.length} Customers', valueColor: c.textBody),
                    const Divider(height: 16),
                    _StatRow(label: 'Total Transactions', value: '$totalTxnCount Entries', valueColor: c.textBody),
                    const Divider(height: 16),
                    _StatRow(label: 'Total Udhar (Debit)', value: formatRupees(totalUdhar), valueColor: c.udhar),
                    if (backupDateDisplay != null) ...[
                      const Divider(height: 16),
                      _StatRow(label: 'Backup Timestamp', value: backupDateDisplay, valueColor: c.muted),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text('Cancel', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.brandPrimary,
                foregroundColor: c.bgDeep,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Restore All Data', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );

      if (confirm == true && context.mounted) {
        context.read<LedgerProvider>().restoreFromBackup(restoredCustomers);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully restored ${restoredCustomers.length} accounts ($totalTxnCount transactions)!'),
            backgroundColor: c.jama,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Restore Error', 'An error occurred while restoring data: $e');
      }
    }
  }

  /// Exports full ledger into an Excel sheet with 2 tabs: Customers and All Transactions.
  static Future<void> exportFullLedgerExcel(BuildContext context, List<Customer> customers) async {
    final c = context.colors;
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final excel = Excel.createExcel();

      // Tab 1: Customers
      const sheetCustomers = 'Customers_Summary';
      final sheet1 = excel[sheetCustomers];
      excel.setDefaultSheet(sheetCustomers);
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      sheet1.appendRow([
        TextCellValue('Account No'),
        TextCellValue('Customer Name'),
        TextCellValue('Mobile Number'),
        TextCellValue('Category'),
        TextCellValue('Net Balance (₹)'),
        TextCellValue('Balance Type'),
        TextCellValue('Total Udhar Taken (₹)'),
        TextCellValue('Total Transactions'),
        TextCellValue('WhatsApp Alerts'),
      ]);

      for (final cust in customers) {
        sheet1.appendRow([
          TextCellValue(cust.accountNumber),
          TextCellValue(cust.name),
          TextCellValue(cust.phone),
          TextCellValue(cust.category.label),
          DoubleCellValue(cust.balance),
          TextCellValue(cust.balance <= 0 ? 'JAMA / SETTLED' : 'UDHAR'),
          DoubleCellValue(cust.totalUdharGiven),
          IntCellValue(cust.transactions.length),
          TextCellValue(cust.whatsappEnabled ? 'YES' : 'NO'),
        ]);
      }

      // Tab 2: All Transactions
      const sheetTransactions = 'All_Transactions';
      final sheet2 = excel[sheetTransactions];

      sheet2.appendRow([
        TextCellValue('Transaction ID'),
        TextCellValue('Date'),
        TextCellValue('Time'),
        TextCellValue('Account No'),
        TextCellValue('Customer Name'),
        TextCellValue('Type'),
        TextCellValue('Amount (₹)'),
        TextCellValue('Payment Mode'),
        TextCellValue('Balance After (₹)'),
        TextCellValue('Description / Note'),
      ]);

      final allTxnsWithCust = <_TxnExportRow>[];
      for (final cust in customers) {
        for (final txn in cust.transactions) {
          allTxnsWithCust.add(_TxnExportRow(customer: cust, txn: txn));
        }
      }

      allTxnsWithCust.sort((a, b) => b.txn.timestamp.compareTo(a.txn.timestamp));

      for (final item in allTxnsWithCust) {
        sheet2.appendRow([
          TextCellValue(item.txn.id.substring(0, 8)),
          TextCellValue(item.txn.date),
          TextCellValue(item.txn.time),
          TextCellValue(item.customer.accountNumber),
          TextCellValue(item.customer.name),
          TextCellValue(item.txn.type.label),
          DoubleCellValue(item.txn.amount),
          TextCellValue(item.txn.mode.label),
          DoubleCellValue(item.txn.balAfter),
          TextCellValue(item.txn.desc),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/Prem_Kirana_Full_Ledger_$dateStr.xlsx');
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Prem Kirana Full Ledger Export',
          text: 'Prem Kirana Ledger full statement export ($dateStr) containing ${customers.length} accounts and ${allTxnsWithCust.length} transactions.',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel ledger generated: ${customers.length} accounts, ${allTxnsWithCust.length} transactions.'),
              backgroundColor: c.jama,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export Excel ledger: $e'),
            backgroundColor: c.udhar,
          ),
        );
      }
    }
  }

  static void _showErrorDialog(BuildContext context, String title, String message) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: c.udhar, fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text(message, style: TextStyle(color: c.muted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: c.brandPrimary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatRow({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: valueColor)),
      ],
    );
  }
}

class _TxnExportRow {
  final Customer customer;
  final LedgerTransaction txn;
  _TxnExportRow({required this.customer, required this.txn});
}
