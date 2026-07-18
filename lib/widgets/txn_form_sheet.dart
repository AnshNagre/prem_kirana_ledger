import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../models/transaction.dart';
import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Opens the "Log Ledger Entry" bottom sheet for [customer] pre-set to
/// [initialType] (UDHAR or JAMA), mirroring `txnFormModal` in the HTML app.
Future<void> showTxnFormSheet(
  BuildContext context, {
  required Customer customer,
  required TxnType initialType,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TxnFormSheet(customer: customer, initialType: initialType),
  );
}

class TxnFormSheet extends StatefulWidget {
  final Customer customer;
  final TxnType initialType;
  const TxnFormSheet({super.key, required this.customer, required this.initialType});

  @override
  State<TxnFormSheet> createState() => _TxnFormSheetState();
}

class _TxnFormSheetState extends State<TxnFormSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late TxnType _type;
  PaymentMode _mode = PaymentMode.cash;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file != null) setState(() => _photoPath = file.path);
  }

  void _save() {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    context.read<LedgerProvider>().addTransaction(
          widget.customer,
          type: _type,
          amount: amount,
          desc: _descCtrl.text,
          mode: _type == TxnType.jama ? _mode : PaymentMode.none,
          imagePath: _photoPath,
        );
    Navigator.pop(context);
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
            Text(
              isJama ? 'LOG JAMA (CREDIT) ENTRY' : 'LOG UDHAR (DEBIT) ENTRY',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: accent, letterSpacing: 0.6),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: c.textBody),
              decoration: formFieldDecoration(context, 'Enter Amount (₹)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              decoration: formFieldDecoration(context, 'Description Remarks (Ex: Rice, Tea)'),
            ),
            if (isJama) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _modeChip(context, PaymentMode.cash)),
                  const SizedBox(width: 8),
                  Expanded(child: _modeChip(context, PaymentMode.online)),
                ],
              ),
            ],
            const SizedBox(height: 12),
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
                  Text('ATTACH TRANSACTION INVOICE SNAPSHOT',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c.muted)),
                  const SizedBox(height: 8),
                  Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: c.bgDeep,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.borderHairline),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _photoPath != null
                        ? Image.file(File(_photoPath!), fit: BoxFit.cover)
                        : Center(
                            child: Icon(Icons.camera_alt_outlined, color: c.muted, size: 24),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _capturePhoto,
                          style: OutlinedButton.styleFrom(side: BorderSide(color: c.borderHairline), foregroundColor: c.brandPrimary),
                          child: const Text('Capture'),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
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
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.brandPrimary,
                        foregroundColor: c.bgDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('CONFIRM ENTRY', style: TextStyle(fontWeight: FontWeight.w900)),
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
