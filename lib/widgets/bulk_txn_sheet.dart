import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../models/transaction.dart';
import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'add_customer_sheet.dart';
import 'common.dart';

class _StagedEntry {
  final String customerName;
  final TxnType type;
  final double amount;
  final DateTime date;
  final String desc;
  final PaymentMode mode;
  final String? photoPath;

  _StagedEntry({
    required this.customerName,
    required this.type,
    required this.amount,
    required this.date,
    this.desc = '',
    this.mode = PaymentMode.none,
    this.photoPath,
  });
}

class BulkTxnSheet extends StatefulWidget {
  const BulkTxnSheet({super.key});

  @override
  State<BulkTxnSheet> createState() => _BulkTxnSheetState();
}

class _BulkTxnSheetState extends State<BulkTxnSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  TxnType _type = TxnType.udhar;
  PaymentMode _mode = PaymentMode.cash;
  List<Customer> _suggestions = [];
  final List<_StagedEntry> _queue = [];
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    final drafts = context.read<LedgerProvider>().bulkDraftEntries;
    for (final d in drafts) {
      _queue.add(_StagedEntry(
        customerName: d.customerName,
        type: d.type,
        amount: d.amount,
        date: d.date,
        desc: d.desc,
        mode: d.mode,
        photoPath: d.photoPath,
      ));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _syncDrafts() {
    final provider = context.read<LedgerProvider>();
    provider.setBulkDraftEntries(_queue.map((e) => BulkTxnDraftEntry(
      customerName: e.customerName,
      type: e.type,
      amount: e.amount,
      date: e.date,
      desc: e.desc,
      mode: e.mode,
      photoPath: e.photoPath,
    )).toList());
  }

  void _onNameChanged(String value) {
    final provider = context.read<LedgerProvider>();
    setState(() => _suggestions = provider.autocompleteByName(value));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (file != null) setState(() => _photoPath = file.path);
  }

  void _showPhotoOptions() {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          color: c.bgElevated,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              sheetGrabber(),
              Text('Attach Photo / Proof', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c.textBody)),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: c.brandPrimary),
                title: Text('Take Live Photo', style: TextStyle(fontWeight: FontWeight.w800, color: c.textBody)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: c.bgSurface,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: const Color(0xFF6366F1)),
                title: Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w800, color: c.textBody)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: c.bgSurface,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToQueue() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a customer name')));
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    final provider = context.read<LedgerProvider>();
    final hasExistingInLedger = provider.hasExistingTransaction(
      customerName: name,
      date: _date,
      amount: amount,
      type: _type,
    );
    final hasExistingInQueue = _queue.any((e) =>
        e.customerName.trim().toLowerCase() == name.toLowerCase() &&
        e.type == _type &&
        (e.amount - amount).abs() < 0.001 &&
        e.date.year == _date.year &&
        e.date.month == _date.month &&
        e.date.day == _date.day);

    if (hasExistingInLedger || hasExistingInQueue) {
      final formattedDate = '${_date.day}/${_date.month}/${_date.year}';
      final formattedAmount = formatRupees(amount);
      final entryTypeLabel = _type.label;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) {
          final c = dialogCtx.colors;
          return AlertDialog(
            backgroundColor: c.bgElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: c.borderHairline),
            ),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: c.warning, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Duplicate Entry Alert',
                  style: TextStyle(
                    color: c.textBody,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            content: Text(
              'This entry already exists for "$name" on $formattedDate ($entryTypeLabel $formattedAmount).\n\nWould you like to enter this?',
              style: TextStyle(
                color: c.textBody,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text(
                  'No',
                  style: TextStyle(
                    color: c.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.brandPrimary,
                  foregroundColor: c.bgDeep,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Yes',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          );
        },
      );

      if (confirm != true) {
        return;
      }
    }

    setState(() {
      _queue.add(_StagedEntry(
        customerName: name,
        type: _type,
        amount: amount,
        date: _date,
        desc: _remarksCtrl.text,
        mode: _type == TxnType.jama ? _mode : PaymentMode.none,
        photoPath: _type == TxnType.udhar ? _photoPath : null,
      ));
      _amountCtrl.clear();
      _remarksCtrl.clear();
      _photoPath = null;
      _syncDrafts();
    });
  }

  void _clearAllStaged() {
    setState(() {
      _queue.clear();
      context.read<LedgerProvider>().clearBulkDraftEntries();
    });
  }

  Future<void> _createCustomerShortcut() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(color: context.colors.bgElevated, child: const AddCustomerSheet()),
      ),
    );
    setState(() {});
  }

  void _commit() {
    if (_queue.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final provider = context.read<LedgerProvider>();
    for (final entry in _queue) {
      var customer = provider.findCustomerByName(entry.customerName);
      customer ??= provider.addCustomer(name: entry.customerName, phone: '');
      provider.addTransaction(
        customer,
        type: entry.type,
        amount: entry.amount,
        desc: entry.desc,
        mode: entry.mode,
        imagePath: entry.photoPath,
        timestamp: entry.date,
      );
    }
    provider.clearBulkDraftEntries();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final c = context.colors;
    final isJama = _type == TxnType.jama;
    final customerExists = provider.findCustomerByName(_nameCtrl.text) != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            sheetGrabber(),
            Text('Bulk Transaction Entry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c.textBody)),
            const SizedBox(height: 4),
            Text('Stage and commit multiple credit/debit entries at once.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.muted)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.bgSurface,
                border: Border.all(color: c.borderHairline),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labeledField(
                    context,
                    'CUSTOMER NAME',
                    TextField(
                      controller: _nameCtrl,
                      onChanged: _onNameChanged,
                      decoration: formFieldDecoration(context, 'Type customer name...'),
                    ),
                  ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: c.bgElevated,
                        border: Border.all(color: c.borderHairline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView(
                        shrinkWrap: true,
                        children: _suggestions
                            .map((s) => ListTile(
                                  dense: true,
                                  title: Row(
                                    children: [
                                      Text(
                                        s.name,
                                        style: TextStyle(color: c.textBody, fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 6),
                                      Text('(${s.accountNumber})', style: TextStyle(color: c.brandPrimary, fontSize: 11, fontFamily: 'monospace')),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${s.category.label} · ${s.phone.isNotEmpty ? s.phone : 'No phone added'}',
                                    style: TextStyle(color: c.muted, fontSize: 11),
                                  ),
                                  onTap: () {
                                    _nameCtrl.text = s.name;
                                    setState(() => _suggestions = []);
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                  if (_nameCtrl.text.trim().isNotEmpty && !customerExists) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: c.warning),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('Customer not found',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.udhar)),
                        ),
                        TextButton(
                          onPressed: _createCustomerShortcut,
                          child: const Text('+ Create new', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: labeledField(
                          context,
                          'AMOUNT (₹)',
                          TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: formFieldDecoration(context, 'Ex: 500'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: labeledField(
                          context,
                          'TRANSACTION DATE',
                          InkWell(
                            onTap: _pickDate,
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.centerLeft,
                              decoration: BoxDecoration(
                                color: c.bgSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.borderHairline),
                              ),
                              child: Text('${_date.day}/${_date.month}/${_date.year}',
                                  style: TextStyle(fontSize: 13, color: c.textBody, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  labeledField(
                    context,
                    'ENTRY TYPE',
                    Row(
                      children: [
                        Expanded(child: _typeToggle(context, TxnType.udhar, 'UDHAR (DEBIT)', c.udhar)),
                        const SizedBox(width: 8),
                        Expanded(child: _typeToggle(context, TxnType.jama, 'JAMA (CREDIT)', c.jama)),
                      ],
                    ),
                  ),
                  if (isJama) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _modeChip(context, PaymentMode.cash)),
                        const SizedBox(width: 8),
                        Expanded(child: _modeChip(context, PaymentMode.online)),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    labeledField(
                      context,
                      'REMARKS / DESCRIPTION',
                      TextField(controller: _remarksCtrl, decoration: formFieldDecoration(context, 'Remarks (Ex: Rice, Tea)')),
                    ),
                    const SizedBox(height: 12),
                    labeledField(
                      context,
                      'ATTACH TRANSACTION PHOTO',
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: c.bgSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.borderHairline),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.image_outlined, size: 18, color: c.muted),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _photoPath != null
                                          ? 'Photo attached (${_photoPath!.split("/").last})'
                                          : 'No photo attached',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _photoPath != null ? c.brandPrimary : c.muted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _showPhotoOptions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.bgSurface,
                              foregroundColor: c.brandPrimary,
                              side: BorderSide(color: c.borderHairline),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              minimumSize: const Size(0, 48),
                            ),
                            icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                            label: const Text('Add Photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                          if (_photoPath != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: c.warning, size: 20),
                              onPressed: () => setState(() => _photoPath = null),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _addToQueue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.brandPrimary,
                        foregroundColor: c.bgDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('ADD TO STAGED QUEUE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('STAGED QUEUE (${_queue.length})',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.muted, letterSpacing: 0.6)),
                if (_queue.isNotEmpty)
                  GestureDetector(
                    onTap: _clearAllStaged,
                    child: Text('CLEAR ALL',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c.udhar, letterSpacing: 0.5)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_queue.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No entries staged yet. Add entries above and they will be saved automatically.',
                        style: TextStyle(color: c.muted, fontSize: 11), textAlign: TextAlign.center)),
              )
            else
              ..._queue.asMap().entries.map((e) {
                final i = e.key;
                final entry = e.value;
                final accent = entry.type.isUdhar ? c.udhar : c.jama;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.bgSurface,
                    border: Border.all(color: c.borderHairline),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      if (entry.photoPath != null) ...[
                        Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.borderHairline),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.file(File(entry.photoPath!), fit: BoxFit.cover),
                        ),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.customerName,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.textBody),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${entry.type.label} · ${entry.date.day}/${entry.date.month}/${entry.date.year}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.muted),
                            ),
                          ],
                        ),
                      ),
                      Text(formatRupees(entry.amount), style: AppTheme.rupeeMono(accent, size: 13, weight: FontWeight.w800)),
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: c.muted),
                        onPressed: () {
                          setState(() {
                            _queue.removeAt(i);
                            _syncDrafts();
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: c.borderHairline)),
                      child: Text('Close', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _commit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.brandPrimary,
                        foregroundColor: c.bgDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('COMMIT ALL ENTRIES', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeToggle(BuildContext context, TxnType type, String label, Color accent) {
    final selected = _type == type;
    final c = context.colors;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent : c.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? accent : c.borderHairline),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: selected ? Colors.white : c.muted)),
      ),
    );
  }

  Widget _modeChip(BuildContext context, PaymentMode mode) {
    final c = context.colors;
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.brandPrimary : c.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? c.brandPrimary : c.borderHairline),
        ),
        child: Text(mode.label.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: selected ? c.bgDeep : c.muted)),
      ),
    );
  }
}
