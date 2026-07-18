import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class AddCustomerSheet extends StatefulWidget {
  const AddCustomerSheet({super.key});

  @override
  State<AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<AddCustomerSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _whatsapp = false;
  String? _photoPath;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file != null) setState(() => _photoPath = file.path);
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and mobile number are required')),
      );
      return;
    }
    context.read<LedgerProvider>().addCustomer(
          name: _nameCtrl.text,
          phone: _phoneCtrl.text,
          whatsappEnabled: _whatsapp,
          photoPath: _photoPath,
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
            Text('Register Account Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textBody)),
            const SizedBox(height: 4),
            Text('Enter the customer\'s details to open a new ledger account.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.muted)),
            const SizedBox(height: 18),
            labeledField(context, 'CUSTOMER NAME',
                TextField(controller: _nameCtrl, decoration: formFieldDecoration(context, 'Ex: Rajesh Sharma'))),
            const SizedBox(height: 14),
            labeledField(
              context,
              'MOBILE NUMBER',
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: formFieldDecoration(context, 'Ex: 98765 00000'),
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
                    activeColor: c.brandPrimary,
                    onChanged: (v) => setState(() => _whatsapp = v),
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
                    height: 150,
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
                                Icon(Icons.camera_alt_outlined, color: c.muted, size: 28),
                                const SizedBox(height: 6),
                                Text('Viewfinder Offline',
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
                        OutlinedButton(
                          onPressed: _capturePhoto,
                          style: OutlinedButton.styleFrom(
                              side: BorderSide(color: c.borderHairline),
                              foregroundColor: c.brandPrimary),
                          child: const Text('Capture Photo'),
                        ),
                        if (_photoPath != null)
                          OutlinedButton(
                            onPressed: () => setState(() => _photoPath = null),
                            style: OutlinedButton.styleFrom(
                                side: BorderSide(color: c.warning), foregroundColor: c.warning),
                            child: const Text('Clear Frame'),
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
                      child: const Text('REGISTER ACCOUNT',
                          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
}
