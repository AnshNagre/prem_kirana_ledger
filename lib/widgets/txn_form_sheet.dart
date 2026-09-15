import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../models/transaction.dart';
import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'common.dart';

/// Opens the "Log Ledger Entry" or "Edit Transaction" bottom sheet for [customer].
Future<void> showTxnFormSheet(
  BuildContext context, {
  required Customer customer,
  TxnType initialType = TxnType.udhar,
  LedgerTransaction? editingTxn,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TxnFormSheet(
      customer: customer,
      initialType: initialType,
      editingTxn: editingTxn,
    ),
  );
}

class TxnFormSheet extends StatefulWidget {
  final Customer customer;
  final TxnType initialType;
  final LedgerTransaction? editingTxn;

  const TxnFormSheet({
    super.key,
    required this.customer,
    this.initialType = TxnType.udhar,
    this.editingTxn,
  });

  @override
  State<TxnFormSheet> createState() => _TxnFormSheetState();
}

class _TxnFormSheetState extends State<TxnFormSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late TxnType _type;
  PaymentMode _mode = PaymentMode.cash;
  DateTime _dateTime = DateTime.now();
  String? _photoPath;

  bool get _isEditing => widget.editingTxn != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final txn = widget.editingTxn!;
      _type = txn.type;
      _amountCtrl.text = txn.amount.toStringAsFixed(txn.amount.truncateToDouble() == txn.amount ? 0 : 2);
      _descCtrl.text = txn.desc;
      _mode = txn.mode;
      _dateTime = txn.timestamp;
      _photoPath = txn.imagePath;
    } else {
      _type = widget.initialType;
      _dateTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      setState(() {
        _dateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _dateTime.hour,
          _dateTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (pickedTime != null) {
      setState(() {
        _dateTime = DateTime(
          _dateTime.year,
          _dateTime.month,
          _dateTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
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
              Text('Attach Photo / Receipt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c.textBody)),
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

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    final provider = context.read<LedgerProvider>();

    if (!_isEditing &&
        provider.hasExistingTransaction(
          customerName: widget.customer.name,
          date: _dateTime,
          amount: amount,
          type: _type,
        )) {
      final formattedDate = DateFormat('dd/MM/yyyy').format(_dateTime);
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
              'This entry already exists for "${widget.customer.name}" on $formattedDate ($entryTypeLabel $formattedAmount).\n\nWould you like to enter this?',
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

    if (_isEditing) {
      provider.editTransaction(
        customer: widget.customer,
        transactionId: widget.editingTxn!.id,
        amount: amount,
        desc: _descCtrl.text.trim(),
        mode: _type == TxnType.jama ? _mode : PaymentMode.none,
        imagePath: _type == TxnType.udhar ? _photoPath : null,
        timestamp: _dateTime,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction updated successfully')),
      );
    } else {
      provider.addTransaction(
        widget.customer,
        type: _type,
        amount: amount,
        desc: _descCtrl.text.trim(),
        mode: _type == TxnType.jama ? _mode : PaymentMode.none,
        imagePath: _type == TxnType.udhar ? _photoPath : null,
        timestamp: _dateTime,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isJama = _type == TxnType.jama;
    final accent = isJama ? c.jama : c.udhar;

    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sheetGrabber(),
            Text(
              _isEditing
                  ? 'EDIT ${_type.label.toUpperCase()} ENTRY'
                  : (isJama ? 'LOG JAMA (CREDIT) ENTRY' : 'LOG UDHAR (DEBIT) ENTRY'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: accent, letterSpacing: 0.6),
            ),
            const SizedBox(height: 14),

            // Amount Field
            TextField(
              controller: _amountCtrl,
              autofocus: !_isEditing,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 18, color: c.textBody),
              decoration: formFieldDecoration(context, 'Enter Amount (₹)').copyWith(
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: accent)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Description / Remarks Field
            TextField(
              controller: _descCtrl,
              decoration: formFieldDecoration(context, 'Description / Items (Ex: Rice, Sugar, Oil)'),
            ),
            const SizedBox(height: 12),

            // Date & Time Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
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
                          Icon(Icons.calendar_today_outlined, size: 16, color: c.brandPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('dd MMM yyyy').format(_dateTime),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textBody),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(12),
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
                          Icon(Icons.schedule, size: 16, color: c.brandPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('hh:mm a').format(_dateTime),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textBody),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
              // Photo attachment
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.bgSurface,
                  border: Border.all(color: c.borderHairline),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ATTACH INVOICE / BILL PHOTO',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: c.muted)),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: c.bgDeep,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.borderHairline),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _photoPath != null && File(_photoPath!).existsSync()
                          ? Image.file(File(_photoPath!), fit: BoxFit.cover)
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt_outlined, color: c.muted, size: 24),
                                  const SizedBox(height: 4),
                                  Text('No Photo Attached', style: TextStyle(fontSize: 10, color: c.muted, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _showPhotoOptions,
                            icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                            style: OutlinedButton.styleFrom(side: BorderSide(color: c.borderHairline), foregroundColor: c.brandPrimary),
                            label: const Text('Add / Capture Photo'),
                          ),
                          if (_photoPath != null)
                            OutlinedButton(
                              onPressed: () => setState(() => _photoPath = null),
                              style: OutlinedButton.styleFrom(side: BorderSide(color: c.warning), foregroundColor: c.warning),
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: c.borderHairline)),
                      child: Text('Cancel', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.brandPrimary,
                        foregroundColor: c.bgDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_isEditing ? 'SAVE CHANGES' : 'CONFIRM ENTRY',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
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
        child: Text(
          mode.label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: selected ? c.bgDeep : c.muted,
          ),
        ),
      ),
    );
  }
}
