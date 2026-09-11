import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'import_excel_sheet.dart';

class AddCustomerSheet extends StatefulWidget {
  final Customer? customer;
  const AddCustomerSheet({super.key, this.customer});

  @override
  State<AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<AddCustomerSheet> {
  final _accCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  CustomerCategory _category = CustomerCategory.newCustomer;
  bool _whatsapp = false;
  String? _photoPath;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      final c = widget.customer!;
      _accCtrl.text = c.accountNumber;
      _nameCtrl.text = c.name;
      _phoneCtrl.text = c.phone;
      _category = c.category;
      _whatsapp = c.whatsappEnabled;
      _photoPath = c.photoPath;
    }
  }

  @override
  void dispose() {
    _accCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
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
              Text('Select Photo Source', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c.textBody)),
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

  Customer? _checkDuplicateCustomer() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty && phone.isEmpty) return null;

    final provider = context.read<LedgerProvider>();

    if (name.isNotEmpty) {
      final match = provider.findCustomerByName(name);
      if (match != null && (!_isEditing || match.id != widget.customer!.id)) {
        return match;
      }
    }

    if (phone.isNotEmpty) {
      final match = provider.findCustomerByPhone(phone);
      if (match != null && (!_isEditing || match.id != widget.customer!.id)) {
        return match;
      }
    }

    return null;
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final acc = _accCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer name is required')),
      );
      return;
    }

    final duplicate = _checkDuplicateCustomer();
    if (duplicate != null && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Customer "${duplicate.name}" already exists!'),
          backgroundColor: context.colors.udhar,
        ),
      );
      return;
    }

    if (_isEditing) {
      context.read<LedgerProvider>().updateCustomer(
            customerId: widget.customer!.id,
            accountNumber: acc.isNotEmpty ? acc : '',
            name: name,
            phone: phone,
            category: _category,
            whatsappEnabled: _whatsapp && phone.isNotEmpty,
            photoPath: _photoPath,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer details updated successfully')),
      );
    } else {
      context.read<LedgerProvider>().addCustomer(
            accountNumber: acc.isNotEmpty ? acc : '',
            name: name,
            phone: phone,
            category: _category,
            whatsappEnabled: _whatsapp && phone.isNotEmpty,
            photoPath: _photoPath,
          );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final duplicate = _checkDuplicateCustomer();

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sheetGrabber(),
            Text(_isEditing ? 'Edit Customer Profile' : 'Register Account Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textBody)),
            const SizedBox(height: 2),
            Text(_isEditing ? 'Update ledger profile and category' : 'Open a new customer ledger account',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.muted)),
            const SizedBox(height: 16),

            if (duplicate != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: c.udhar.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.udhar.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: c.udhar),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Customer already exists: ${duplicate.name}${duplicate.accountNumber.isNotEmpty ? " (${duplicate.accountNumber})" : ""}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.udhar),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Customer Name field
            labeledField(
              context,
              'CUSTOMER NAME *',
              TextField(
                controller: _nameCtrl,
                onChanged: (_) => setState(() {}),
                decoration: formFieldDecoration(context, 'Ex: Rajesh Sharma'),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(height: 14),

            // Account Number
            labeledField(
              context,
              'ACCOUNT NO (OPTIONAL)',
              TextField(
                controller: _accCtrl,
                decoration: formFieldDecoration(context, 'Leave blank or enter custom Acc No'),
                style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, color: c.textBody, fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),

            // Customer Category Segmented Buttons (NEW / OLD / DAILY)
            Text('CUSTOMER CATEGORY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c.muted, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Row(
              children: CustomerCategory.values.map((cat) {
                final isSelected = _category == cat;
                final catColor = _getCatColor(cat);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () => setState(() => _category = cat),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? catColor : c.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? catColor : c.borderHairline,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _categoryDot(cat, isWhite: isSelected),
                            const SizedBox(width: 6),
                            Text(
                              cat.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? c.bgDeep : c.textBody,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            labeledField(
              context,
              'MOBILE NUMBER (OPTIONAL)',
              TextField(
                controller: _phoneCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.phone,
                decoration: formFieldDecoration(context, 'Ex: 98765 00000 (Optional)'),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.borderHairline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enable WhatsApp Notifications',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textBody)),
                        const SizedBox(height: 2),
                        Text('Send transaction vouchers directly via WhatsApp',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: c.muted)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _whatsapp,
                    activeThumbColor: c.brandPrimary,
                    onChanged: (v) {
                      if (v && _phoneCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a mobile number to enable WhatsApp notifications')),
                        );
                      }
                      setState(() => _whatsapp = v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.bgSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.borderHairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IDENTITY VERIFICATION PHOTO',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c.muted)),
                  const SizedBox(height: 8),
                  Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: c.bgDeep,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.borderHairline, style: BorderStyle.solid),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _photoPath != null
                        ? Image.file(File(_photoPath!), fit: BoxFit.cover)
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.camera_alt_outlined, color: c.muted, size: 26),
                                const SizedBox(height: 4),
                                Text('Photo Offline',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.muted)),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showPhotoOptions,
                          icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                          style: OutlinedButton.styleFrom(
                              side: BorderSide(color: c.borderHairline),
                              foregroundColor: c.brandPrimary),
                          label: const Text('Add / Capture Photo'),
                        ),
                        if (_photoPath != null)
                          OutlinedButton(
                            onPressed: () => setState(() => _photoPath = null),
                            style: OutlinedButton.styleFrom(
                                side: BorderSide(color: c.warning), foregroundColor: c.warning),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
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
                      child: Text(_isEditing ? 'SAVE CHANGES' : 'REGISTER ACCOUNT',
                          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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

  Color _getCatColor(CustomerCategory cat) {
    switch (cat) {
      case CustomerCategory.newCustomer:
        return const Color(0xFFE8A33D);
      case CustomerCategory.oldCustomer:
        return const Color(0xFF6366F1);
      case CustomerCategory.dailyCustomer:
        return const Color(0xFF06B6D4);
    }
  }

  Widget _categoryDot(CustomerCategory cat, {bool isWhite = false}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isWhite ? Colors.black87 : _getCatColor(cat),
        shape: BoxShape.circle,
      ),
    );
  }
}
