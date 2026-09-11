import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/customer.dart';
import '../models/transaction.dart';

class ParsedCustomerRow {
  final String accountNumber;
  final String name;
  final String phone;
  final CustomerCategory category;
  final double openingUdhar;
  final bool isValid;
  final String? error;

  ParsedCustomerRow({
    required this.accountNumber,
    required this.name,
    required this.phone,
    required this.category,
    this.openingUdhar = 0.0,
    this.isValid = true,
    this.error,
  });
}

class ExcelImporter {
  static const _uuid = Uuid();

  /// Robust CSV parser supporting quotes, commas, and line endings.
  static List<List<dynamic>> parseCsvContent(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final List<List<dynamic>> rows = [];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final row = <String>[];
      final buffer = StringBuffer();
      bool inQuotes = false;
      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == '"') {
          inQuotes = !inQuotes;
        } else if (char == ',' && !inQuotes) {
          row.add(buffer.toString().trim());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
      row.add(buffer.toString().trim());
      rows.add(row);
    }
    return rows;
  }

  /// Parses an .xlsx, .xls, or .csv file and returns a list of candidate customer rows.
  static Future<List<ParsedCustomerRow>> parseFile(String filePath, String startingAccNo) async {
    final file = File(filePath);
    if (!file.existsSync()) return [];

    final extension = filePath.split('.').last.toLowerCase();
    List<List<dynamic>> rawRows = [];

    if (extension == 'csv') {
      try {
        final content = await file.readAsString();
        rawRows = parseCsvContent(content);
      } catch (_) {
        final bytes = await file.readAsBytes();
        final content = String.fromCharCodes(bytes);
        rawRows = parseCsvContent(content);
      }
    } else {
      // Excel .xlsx or .xls
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables.keys.firstWhere(
        (k) => excel.tables[k]?.rows.isNotEmpty ?? false,
        orElse: () => excel.tables.keys.first,
      );

      final sheet = excel.tables[table];
      if (sheet != null) {
        for (final row in sheet.rows) {
          rawRows.add(row.map((cell) => cell?.value?.toString() ?? '').toList());
        }
      }
    }

    if (rawRows.isEmpty) return [];

    // Detect column indexes from header row
    int nameCol = -1;
    int phoneCol = -1;
    int accCol = -1;
    int categoryCol = -1;
    int balanceCol = -1;

    int headerRowIndex = 0;

    for (int i = 0; i < rawRows.length && i < 5; i++) {
      final row = rawRows[i];
      for (int c = 0; c < row.length; c++) {
        final cell = row[c].toString().trim().toLowerCase();
        if (cell.contains('name') || cell.contains('naam') || cell.contains('नाम') || cell == 'customer') {
          nameCol = c;
          headerRowIndex = i;
        } else if (cell.contains('phone') || cell.contains('mobile') || cell.contains('contact') || cell.contains('फोन')) {
          phoneCol = c;
        } else if (cell.contains('acc') || cell.contains('account') || cell.contains('khata') || cell.contains('खाता')) {
          accCol = c;
        } else if (cell.contains('cat') || cell.contains('type') || cell.contains('group') || cell.contains('श्रेणी')) {
          categoryCol = c;
        } else if (cell.contains('balance') || cell.contains('udhar') || cell.contains('amount') || cell.contains('opening') || cell.contains('बाकी')) {
          balanceCol = c;
        }
      }
      if (nameCol != -1) break;
    }

    // Fallback column positions if no header matched
    if (nameCol == -1) {
      if (rawRows.first.isNotEmpty) {
        nameCol = 0;
        phoneCol = rawRows.first.length > 1 ? 1 : -1;
        categoryCol = rawRows.first.length > 2 ? 2 : -1;
        balanceCol = rawRows.first.length > 3 ? 3 : -1;
      }
    }

    int currentAccNum = 100;
    final accMatch = RegExp(r'(\d+)').firstMatch(startingAccNo);
    if (accMatch != null) {
      currentAccNum = int.tryParse(accMatch.group(1)!) ?? 100;
    }

    final List<ParsedCustomerRow> results = [];

    for (int r = headerRowIndex + 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      if (row.isEmpty) continue;

      final name = nameCol >= 0 && nameCol < row.length ? row[nameCol].toString().trim() : '';
      if (name.isEmpty || name.toLowerCase() == 'name' || name.toLowerCase() == 'customer name') continue;

      final phone = phoneCol >= 0 && phoneCol < row.length ? _cleanPhone(row[phoneCol].toString()) : '';
      
      String rawAcc = accCol >= 0 && accCol < row.length ? row[accCol].toString().trim() : '';
      if (rawAcc.isEmpty) {
        currentAccNum++;
        rawAcc = 'PK-$currentAccNum';
      }

      final categoryStr = categoryCol >= 0 && categoryCol < row.length ? row[categoryCol].toString().trim() : '';
      final category = CustomerCategory.fromString(categoryStr);

      double openingUdhar = 0.0;
      if (balanceCol >= 0 && balanceCol < row.length) {
        final val = row[balanceCol].toString().replaceAll(RegExp(r'[^\d.]'), '');
        openingUdhar = double.tryParse(val) ?? 0.0;
      }

      results.add(ParsedCustomerRow(
        accountNumber: rawAcc,
        name: name,
        phone: phone,
        category: category,
        openingUdhar: openingUdhar,
        isValid: true,
      ));
    }

    return results;
  }

  static String _cleanPhone(String raw) {
    if (raw.isEmpty || raw == 'null') return '';
    // Strip trailing .0 if excel parsed integer as float
    var s = raw.replaceAll(RegExp(r'\.0$'), '').trim();
    return s;
  }

  /// Converts parsed rows into full Customer models with opening transactions if applicable.
  static List<Customer> convertToCustomers(List<ParsedCustomerRow> rows) {
    final List<Customer> list = [];
    final now = DateTime.now();

    for (final row in rows) {
      if (!row.isValid) continue;

      final customer = Customer(
        id: _uuid.v4(),
        accountNumber: row.accountNumber,
        name: row.name,
        phone: row.phone,
        category: row.category,
        whatsappEnabled: row.phone.trim().isNotEmpty,
      );

      if (row.openingUdhar > 0) {
        customer.transactions.add(LedgerTransaction(
          id: _uuid.v4(),
          type: TxnType.udhar,
          amount: row.openingUdhar,
          desc: 'Opening Udhar Balance (Excel Import)',
          balAfter: row.openingUdhar,
          timestamp: now,
        ));
      }

      list.add(customer);
    }
    return list;
  }

  /// Generates and triggers system share for a pre-formatted Excel template.
  static Future<void> shareSampleExcelTemplate() async {
    final excel = Excel.createExcel();
    const sheetName = 'PremKirana_Customers';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    sheet.appendRow([
      TextCellValue('Account No'),
      TextCellValue('Customer Name'),
      TextCellValue('Mobile Number'),
      TextCellValue('Category (New / Old / Daily)'),
      TextCellValue('Opening Udhar Balance (₹)'),
    ]);

    sheet.appendRow([
      TextCellValue('PK-101'),
      TextCellValue('Rajesh Sharma'),
      TextCellValue('9876543210'),
      TextCellValue('New'),
      IntCellValue(500),
    ]);

    sheet.appendRow([
      TextCellValue('PK-102'),
      TextCellValue('Sunil Gupta'),
      TextCellValue('9823012345'),
      TextCellValue('Daily'),
      IntCellValue(0),
    ]);

    sheet.appendRow([
      TextCellValue('PK-103'),
      TextCellValue('Kavita Patel'),
      TextCellValue(''),
      TextCellValue('Old'),
      IntCellValue(1250),
    ]);

    sheet.appendRow([
      TextCellValue('PK-104'),
      TextCellValue('Manoj Verma'),
      TextCellValue('9811223344'),
      TextCellValue('Daily'),
      IntCellValue(340),
    ]);

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Prem_Kirana_Customer_Import_Template.xlsx');
      await file.writeAsBytes(fileBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Prem Kirana Customer Import Template',
        text: 'Prem Kirana Ledger - Sample Customer Excel Import Sheet',
      );
    }
  }
}
