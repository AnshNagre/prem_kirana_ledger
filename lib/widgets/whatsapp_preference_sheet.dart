import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class WhatsappPreferenceSheet extends StatelessWidget {
  const WhatsappPreferenceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final provider = context.watch<LedgerProvider>();
    final customers = provider.customers;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sheetGrabber(),
          Text('Route Selection Matrix', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c.textBody)),
          const SizedBox(height: 4),
          Text('Toggle which accounts receive WhatsApp voucher receipts.',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.muted)),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: customers.isEmpty
                ? Center(child: Text('No customers yet', style: TextStyle(color: c.muted)))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final customer = customers[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.bgSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.borderHairline),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(customer.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textBody)),
                          subtitle: Text(customer.phone, style: TextStyle(fontSize: 11, color: c.muted)),
                          value: customer.whatsappEnabled,
                          activeColor: c.brandPrimary,
                          onChanged: (v) => provider.updateWhatsappPreference(customer, v),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.brandPrimary,
                foregroundColor: c.bgDeep,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('SAVE PREFERENCES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}
