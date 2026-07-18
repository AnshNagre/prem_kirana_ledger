import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'whatsapp_preference_sheet.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final provider = context.watch<LedgerProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sheetGrabber(),
          Text('Application Settings Hub', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c.textBody)),
          const SizedBox(height: 4),
          Text('Manage messaging automation and appearance preferences.',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.muted)),
          const SizedBox(height: 16),
          _SettingsRow(
            icon: Icons.dark_mode_outlined,
            title: 'Dark / Light Theme',
            subtitle: 'Switch between the ledger\'s dark and light appearance.',
            trailing: Switch(
              value: provider.themeMode == ThemeMode.dark,
              activeColor: c.brandPrimary,
              onChanged: (_) => provider.toggleTheme(),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            icon: Icons.chat_bubble_outline,
            title: 'WhatsApp Messages Preference',
            subtitle: 'Choose which accounts get voucher receipts via WhatsApp.',
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const WhatsappPreferenceSheet(),
              );
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(side: BorderSide(color: c.borderHairline)),
              child: Text('CLOSE PANEL', style: TextStyle(fontWeight: FontWeight.w800, color: c.muted, fontSize: 11, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borderHairline),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.brandPrimary.withOpacity(0.1),
                border: Border.all(color: c.brandPrimary.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: c.brandPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textBody)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: c.muted)),
                ],
              ),
            ),
            if (trailing != null) trailing! else Icon(Icons.chevron_right, color: c.brandPrimary, size: 18),
          ],
        ),
      ),
    );
  }
}
