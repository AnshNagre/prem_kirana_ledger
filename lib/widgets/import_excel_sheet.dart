import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/excel_importer.dart';
import '../utils/formatters.dart';
import 'common.dart';

class ImportExcelSheet extends StatefulWidget {
  const ImportExcelSheet({super.key});

  @override
  State<ImportExcelSheet> createState() => _ImportExcelSheetState();
}

class _ImportExcelSheetState extends State<ImportExcelSheet> {
  bool _isLoading = false;
  String? _pickedFileName;
  List<ParsedCustomerRow> _parsedRows = [];

  Future<void> _pickFile() async {
    final provider = context.read<LedgerProvider>();
    final nextAcc = provider.nextSuggestedAccountNumber;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
          _pickedFileName = result.files.single.name;
        });

        final rows = await ExcelImporter.parseFile(
          result.files.single.path!,
          nextAcc,
        );

        if (!mounted) return;

        setState(() {
          _parsedRows = rows;
          _isLoading = false;
        });

        if (rows.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid customer rows found in the selected file')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e')),
        );
      }
    }
  }

  void _commitImport() {
    if (_parsedRows.isEmpty) return;

    final customers = ExcelImporter.convertToCustomers(_parsedRows);
    context.read<LedgerProvider>().addCustomersBulk(customers);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully imported ${customers.length} customers from Excel!'),
        backgroundColor: const Color(0xFF1FAA59),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final validCount = _parsedRows.where((r) => r.isValid).length;

    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sheetGrabber(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Import Customers via Excel',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textBody)),
                  const SizedBox(height: 2),
                  Text('Upload .xlsx, .xls or .csv spreadsheet',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.muted)),
                ],
              ),
              IconButton(
                icon: Icon(Icons.download_for_offline_outlined, color: c.brandPrimary, size: 22),
                tooltip: 'Download / Share Sample Excel Template',
                onPressed: ExcelImporter.shareSampleExcelTemplate,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Upload File Card
          InkWell(
            onTap: _isLoading ? null : _pickFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: c.bgSurface,
                border: Border.all(
                  color: _pickedFileName != null ? c.brandPrimary : c.borderHairline,
                  width: _pickedFileName != null ? 1.5 : 1.0,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.brandPrimary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _pickedFileName != null ? Icons.table_chart : Icons.upload_file_outlined,
                      color: c.brandPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pickedFileName ?? 'Tap to Select Excel / CSV File',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _pickedFileName != null ? c.brandPrimary : c.textBody,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _pickedFileName != null
                              ? 'Found $validCount customer entries'
                              : 'Supports .xlsx, .xls, .csv files',
                          style: TextStyle(fontSize: 11, color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _isLoading ? null : _pickFile,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.brandPrimary.withOpacity(0.4)),
                      foregroundColor: c.brandPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(_pickedFileName != null ? 'Change' : 'Browse',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading) ...[
            const SizedBox(height: 24),
            Center(child: CircularProgressIndicator(color: c.brandPrimary)),
            const SizedBox(height: 24),
          ],

          if (_parsedRows.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PREVIEW CUSTOMERS (${_parsedRows.length})',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c.muted, letterSpacing: 0.8),
                ),
                Text(
                  'Ready to add',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.jama),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: c.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.borderHairline),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _parsedRows.length,
                  separatorBuilder: (_, __) => Divider(color: c.borderHairline, height: 1),
                  itemBuilder: (context, i) {
                    final row = _parsedRows[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.brandPrimary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              row.accountNumber,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: c.brandPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      row.name,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textBody),
                                    ),
                                    const SizedBox(width: 6),
                                    _CategoryBadge(category: row.category),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  row.phone.isNotEmpty ? row.phone : 'No phone added',
                                  style: TextStyle(fontSize: 10, color: c.muted),
                                ),
                              ],
                            ),
                          ),
                          if (row.openingUdhar > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatRupees(row.openingUdhar),
                                  style: AppTheme.rupeeMono(c.udhar, size: 12, weight: FontWeight.w800),
                                ),
                                Text(
                                  'Opening Udhar',
                                  style: TextStyle(fontSize: 9, color: c.muted, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.borderHairline),
                      foregroundColor: c.muted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _parsedRows.isEmpty ? null : _commitImport,
                    icon: const Icon(Icons.group_add_outlined, size: 18),
                    label: Text(
                      _parsedRows.isEmpty ? 'SELECT FILE FIRST' : 'IMPORT (${_parsedRows.length}) CUSTOMERS',
                      style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.brandPrimary,
                      foregroundColor: c.bgDeep,
                      disabledBackgroundColor: c.bgSurface,
                      disabledForegroundColor: c.muted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final CustomerCategory category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (category) {
      case CustomerCategory.newCustomer:
        bg = const Color(0xFFE8A33D).withOpacity(0.15);
        fg = const Color(0xFFE8A33D);
        break;
      case CustomerCategory.oldCustomer:
        bg = const Color(0xFF6366F1).withOpacity(0.15);
        fg = const Color(0xFF6366F1);
        break;
      case CustomerCategory.dailyCustomer:
        bg = const Color(0xFF06B6D4).withOpacity(0.15);
        fg = const Color(0xFF06B6D4);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        category.label.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }
}
