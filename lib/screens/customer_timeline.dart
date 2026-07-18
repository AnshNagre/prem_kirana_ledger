import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../models/customer.dart';
import '../models/transaction.dart';
import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/pdf_export.dart';
import '../widgets/share_receipt_sheet.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/txn_form_sheet.dart';

class CustomerTimelineScreen extends StatefulWidget {
  final Customer customer;
  const CustomerTimelineScreen({super.key, required this.customer});

  @override
  State<CustomerTimelineScreen> createState() => _CustomerTimelineScreenState();
}

class _CustomerTimelineScreenState extends State<CustomerTimelineScreen> {
  bool _searchOpen = false;
  String _query = '';
  bool _showAllHistory = false;

  List<LedgerTransaction> get _filteredTxns {
    final all = widget.customer.transactions.toList();
    if (_query.trim().isEmpty) return all;
    final q = _query.trim().toLowerCase();
    return all.where((t) {
      return t.desc.toLowerCase().contains(q) ||
          t.date.contains(q) ||
          t.amount.toStringAsFixed(0).contains(q);
    }).toList();
  }

  Future<void> _exportPdf() async {
    if (widget.customer.transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export yet')),
      );
      return;
    }
    await exportCustomerLedgerPdf(widget.customer);
  }

  Future<void> _sendLedgerViaWhatsApp() async {
    final balance = widget.customer.balance;
    final balanceText = formatRupees(balance);
    final status = balance > 0 ? "outstanding Udhar (debit)" : (balance < 0 ? "advance Jama (credit)" : "settled balance");
    final message = "Hello ${widget.customer.name},\n\nYour current net balance status at Prem Kirana Store is *${balanceText.replaceAll(" ", "")}* ($status).\n\nThank you!\nPrem Kirana Ledger";
    final cleanPhone = widget.customer.phone.replaceAll(RegExp(r'\D'), '');
    
    // Fallback if country code is not present
    var phoneForUrl = cleanPhone;
    if (phoneForUrl.length == 10) {
      phoneForUrl = "91$phoneForUrl"; // default to Indian country code
    }
    
    final url = "https://wa.me/$phoneForUrl?text=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp')),
      );
    }
  }

  Future<void> _sendLedgerViaSMS() async {
    final balance = widget.customer.balance;
    final balanceText = formatRupees(balance);
    final status = balance > 0 ? "outstanding Udhar" : (balance < 0 ? "advance Jama" : "settled balance");
    final message = "Hello ${widget.customer.name},\n\nYour current net balance status at Prem Kirana Store is ${balanceText.replaceAll(" ", "")} ($status).\n\nThank you!\nPrem Kirana Ledger";
    final cleanPhone = widget.customer.phone.replaceAll(RegExp(r'\D'), '');
    final url = "sms:$cleanPhone?body=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Share.share(message, subject: "Ledger Statement Reminder");
    }
  }

  Future<void> _shareLedgerSummary() async {
    final balance = widget.customer.balance;
    final balanceText = formatRupees(balance);
    final status = balance > 0 ? "outstanding Udhar" : (balance < 0 ? "advance Jama" : "settled balance");
    final message = "Prem Kirana Ledger Statement:\n"
        "Customer: ${widget.customer.name}\n"
        "Net Balance: ${balanceText.replaceAll(" ", "")} ($status)\n"
        "Total Transactions: ${widget.customer.transactions.length}\n\n"
        "Generated via Prem Kirana Ledger App.";
    await Share.share(message, subject: "${widget.customer.name} - Ledger Summary");
  }

  void _confirmDeleteAll() {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear Timeline?', style: TextStyle(color: c.textBody, fontWeight: FontWeight.w800)),
        content: Text(
          'This permanently deletes every transaction for ${widget.customer.name}. This cannot be undone.',
          style: TextStyle(color: c.muted, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: c.muted))),
          TextButton(
            onPressed: () {
              context.read<LedgerProvider>().deleteCustomerTransactions(widget.customer);
              Navigator.pop(context);
            },
            child: Text('Delete All', style: TextStyle(color: c.udhar, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showTxnDetails(LedgerTransaction txn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => TransactionDetailsSheet(txn: txn),
    );
  }

  void _shareTxn(LedgerTransaction txn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.bgDeep,
      builder: (_) => ShareReceiptSheet(customer: widget.customer, txn: txn),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Re-watch the provider so the header balance updates live.
    context.watch<LedgerProvider>();
    final customer = widget.customer;
    final balance = customer.balance;
    final allTxns = _filteredTxns;
    final showAll = _showAllHistory || allTxns.length <= 3 || _query.trim().isNotEmpty;
    final txnsToShow = showAll ? allTxns : allTxns.sublist(allTxns.length - 3);

    return Scaffold(
      backgroundColor: c.bgDeep,
      appBar: AppBar(
        backgroundColor: c.bgDeep,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: c.muted), onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.brandPrimary.withOpacity(0.1),
                border: Border.all(color: c.brandPrimary.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: customer.photoPath != null && File(customer.photoPath!).existsSync()
                  ? Image.file(File(customer.photoPath!), fit: BoxFit.cover)
                  : Text(customer.initials, style: TextStyle(color: c.brandPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(customer.name.toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c.textBody), overflow: TextOverflow.ellipsis),
                  Text('Net Bal: ${formatRupees(balance)}',
                      style: AppTheme.rupeeMono(balance > 0 ? c.udhar : c.jama, size: 11, weight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.close : Icons.search, color: c.muted, size: 20),
            onPressed: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) _query = '';
            }),
          ),
          if (customer.whatsappEnabled)
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 20),
              tooltip: 'Send ledger summary via WhatsApp',
              onPressed: _sendLedgerViaWhatsApp,
            ),
          IconButton(
            icon: Icon(Icons.message_outlined, color: c.muted, size: 19),
            tooltip: 'Send ledger summary via SMS',
            onPressed: _sendLedgerViaSMS,
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf_outlined, color: c.muted, size: 19),
            tooltip: 'Export to PDF',
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: c.textBody, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search amt, date, remarks...',
                  hintStyle: TextStyle(color: c.muted, fontSize: 12),
                  filled: true,
                  fillColor: c.bgSurface.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.borderHairline)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.borderHairline)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.brandPrimary)),
                ),
              ),
            ),
          Expanded(
            child: allTxns.isEmpty
                ? Center(
                    child: Text('No transactions yet', style: TextStyle(color: c.muted, fontSize: 13)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                    itemCount: txnsToShow.length + (showAll ? 0 : 1),
                    itemBuilder: (context, i) {
                      if (!showAll && i == 0) {
                        final hiddenCount = allTxns.length - 3;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _showAllHistory = true),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: c.brandPrimary.withOpacity(0.3)),
                              foregroundColor: c.brandPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.history, size: 16),
                            label: Text('SHOW OLDER TRANSACTIONS ($hiddenCount)'),
                          ),
                        );
                      }
                      final txn = txnsToShow[showAll ? i : i - 1];
                      return GestureDetector(
                        onTap: () => _showTxnDetails(txn),
                        onLongPress: () => _shareTxn(txn),
                        child: TransactionTile(txn: txn, onTap: () => _showTxnDetails(txn)),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.bgElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.borderHairline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _actionButton(
                    context,
                    label: 'JAMA',
                    color: c.jama,
                    icon: Icons.remove,
                    onTap: () => showTxnFormSheet(context, customer: customer, initialType: TxnType.jama),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: _confirmDeleteAll,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.borderHairline),
                    ),
                    child: Icon(Icons.delete_outline, size: 18, color: c.warning),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    context,
                    label: 'UDHAR',
                    color: c.udhar,
                    icon: Icons.add,
                    onTap: () => showTxnFormSheet(context, customer: customer, initialType: TxnType.udhar),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, {required String label, required Color color, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: context.colors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}
