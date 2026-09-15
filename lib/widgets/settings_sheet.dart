import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/backup_manager.dart';
import '../utils/excel_importer.dart';
import '../utils/google_drive_service.dart';
import '../utils/image_optimizer.dart';
import 'common.dart';
import 'import_excel_sheet.dart';
import 'whatsapp_preference_sheet.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  void _showWebhookSetupDialog(BuildContext context) {
    final c = context.colors;
    final urlCtrl = TextEditingController(text: GoogleDriveService.instance.scriptUrl ?? '');
    final provider = context.read<LedgerProvider>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final drive = GoogleDriveService.instance;
          return AlertDialog(
            backgroundColor: c.bgElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.cloud_sync_rounded, color: Color(0xFF4285F4), size: 22),
                const SizedBox(width: 8),
                Text('Google Drive Auto-Sync', style: TextStyle(color: c.textBody, fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Direct Drive Sync via your private Google Apps Script (Zero OAuth / No setup restrictions):',
                    style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: urlCtrl,
                    style: TextStyle(fontSize: 12, color: c.textBody, fontFamily: 'monospace'),
                    decoration: formFieldDecoration(context, 'Paste Google Apps Script Web App URL').copyWith(
                      prefixIcon: const Icon(Icons.link, size: 18, color: Color(0xFF4285F4)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.bgDeep,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.borderHairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('1-MINUTE SETUP INSTRUCTIONS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c.brandPrimary)),
                        const SizedBox(height: 6),
                        Text(
                          '1. Open script.google.com in your browser\n2. Click "New Project" and paste the code\n3. Click Deploy -> New deployment -> Web app\n4. Set "Who has access" to Anyone -> Click Deploy\n5. Copy the generated Web App URL and paste above!',
                          style: TextStyle(color: c.muted, fontSize: 10.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy Script Code'),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: GoogleDriveService.sampleScriptCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied Google Apps Script code to clipboard!')),
                  );
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final url = urlCtrl.text.trim();
                  if (url.isEmpty) return;

                  Navigator.pop(ctx);
                  final success = await drive.connectWithUrl(url, provider.customers);
                  if (context.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Connected! Ledger & photos backed up to Prem_Kirana_backup in Drive.'),
                          backgroundColor: c.jama,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Connection failed: ${drive.lastError}'),
                          backgroundColor: c.udhar,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Connect & Sync'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final provider = context.watch<LedgerProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sheetGrabber(),
            Text('Application Settings Hub', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textBody)),
            const SizedBox(height: 4),
            Text('Manage cloud auto-sync, backups, messaging, and appearance preferences.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.muted)),
            const SizedBox(height: 16),

            // Section 1: Google Drive Real-Time Cloud Sync
            _SectionHeader(title: 'GOOGLE DRIVE CLOUD SYNC', icon: Icons.cloud_sync_rounded, color: const Color(0xFF4285F4)),
            const SizedBox(height: 8),

            ListenableBuilder(
              listenable: GoogleDriveService.instance,
              builder: (ctx, _) {
                final drive = GoogleDriveService.instance;
                final isConnected = drive.isConnected;

                return Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.add_to_drive_rounded,
                      iconColor: const Color(0xFF4285F4),
                      title: 'Google Drive Auto-Sync',
                      subtitle: isConnected
                          ? 'Connected to your Drive (Folder: Prem_Kirana_backup)\nStatus: ${drive.syncStatus}'
                          : 'Real-time backup of all accounts, transactions & receipt images.',
                      trailing: Switch(
                        value: isConnected,
                        activeThumbColor: const Color(0xFF4285F4),
                        onChanged: (enabled) async {
                          if (enabled) {
                            _showWebhookSetupDialog(context);
                          } else {
                            await drive.disconnect();
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Google Drive Auto-Sync disconnected.')),
                              );
                            }
                          }
                        },
                      ),
                      onTap: () {
                        _showWebhookSetupDialog(context);
                      },
                    ),
                    if (isConnected) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4285F4).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 16, color: const Color(0xFF4285F4)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                drive.isSyncing
                                    ? 'Syncing changes to Google Drive...'
                                    : 'Auto-sync active: Prem_Kirana_backup',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4285F4)),
                              ),
                            ),
                            InkWell(
                              onTap: drive.isSyncing
                                  ? null
                                  : () async {
                                      await drive.syncData(provider.customers);
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(content: Text('Synced latest ledger to Google Drive!')),
                                        );
                                      }
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text(
                                  drive.isSyncing ? 'SYNCING...' : 'SYNC NOW',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: drive.isSyncing ? c.muted : const Color(0xFF4285F4),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 8),

            _SettingsRow(
              icon: Icons.compress_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Optimize Photos (MB to KB)',
              subtitle: 'Compress receipt and KYC photos over 1 MB down to ~50–120 KB.',
              onTap: () async {
                final count = await ImageOptimizer.optimizeAllCustomerImages(provider.customers);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(count > 0 ? 'Optimized $count photo(s) down to KBs!' : 'All photos are already optimized in KBs!'),
                      backgroundColor: c.jama,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 18),

            // Section 2: Data Safety & Backups
            _SectionHeader(title: 'MANUAL DATA BACKUPS', icon: Icons.shield_outlined, color: c.jama),
            const SizedBox(height: 8),

            _SettingsRow(
              icon: Icons.cloud_upload_outlined,
              iconColor: c.jama,
              title: 'Export Full Backup (JSON)',
              subtitle: 'Save complete accounts & transaction history to WhatsApp or Drive.',
              onTap: () {
                BackupManager.exportBackupJson(context, provider.customers);
              },
            ),
            const SizedBox(height: 8),

            _SettingsRow(
              icon: Icons.settings_backup_restore_rounded,
              iconColor: const Color(0xFF6366F1),
              title: 'Restore from Backup (JSON)',
              subtitle: 'Load ledger accounts and past transactions from a backup file.',
              onTap: () {
                BackupManager.importBackupJson(context);
              },
            ),
            const SizedBox(height: 8),

            _SettingsRow(
              icon: Icons.table_view_rounded,
              iconColor: const Color(0xFF0EA5E9),
              title: 'Export Full Ledger to Excel (.xlsx)',
              subtitle: 'Generate a 2-sheet spreadsheet of all customers and transaction history.',
              onTap: () {
                BackupManager.exportFullLedgerExcel(context, provider.customers);
              },
            ),
            const SizedBox(height: 18),

            // Section 2: Excel Tools & Messaging
            _SectionHeader(title: 'SPREADSHEETS & IMPORT', icon: Icons.table_chart_outlined, color: c.brandPrimary),
            const SizedBox(height: 8),

            _SettingsRow(
              icon: Icons.file_upload_outlined,
              iconColor: c.brandPrimary,
              title: 'Excel / CSV Customer Import',
              subtitle: 'Batch upload new customer accounts from spreadsheets.',
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const ImportExcelSheet(),
                );
              },
            ),
            const SizedBox(height: 8),

            _SettingsRow(
              icon: Icons.download_for_offline_outlined,
              iconColor: const Color(0xFFE8A33D),
              title: 'Download Excel Template',
              subtitle: 'Share pre-formatted spreadsheet template with sample data.',
              onTap: () {
                ExcelImporter.shareSampleExcelTemplate();
              },
            ),
            const SizedBox(height: 18),

            // Section 3: Preferences
            _SectionHeader(title: 'PREFERENCES', icon: Icons.tune_rounded, color: c.muted),
            const SizedBox(height: 8),

            _SettingsRow(
              icon: Icons.chat_bubble_outline,
              iconColor: const Color(0xFF25D366),
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
            const SizedBox(height: 8),

            _SettingsRow(
              icon: Icons.dark_mode_outlined,
              iconColor: c.brandPrimary,
              title: 'Dark / Light Theme',
              subtitle: 'Switch between dark and light appearance.',
              trailing: Switch(
                value: provider.themeMode == ThemeMode.dark,
                activeThumbColor: c.brandPrimary,
                onChanged: (_) => provider.toggleTheme(),
              ),
            ),
            const SizedBox(height: 20),

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
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final activeColor = iconColor ?? c.brandPrimary;
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
                color: activeColor.withOpacity(0.12),
                border: Border.all(color: activeColor.withOpacity(0.25)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: activeColor),
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
            if (trailing != null) trailing! else Icon(Icons.chevron_right, color: c.brandPrimary.withOpacity(0.6), size: 18),
          ],
        ),
      ),
    );
  }
}
