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
import '../widgets/add_customer_sheet.dart';
import '../widgets/customer_card.dart';
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
  final Set<String> _selectedTxnIds = {};

  void _openEditCustomer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          color: context.colors.bgElevated,
          child: AddCustomerSheet(customer: widget.customer),
        ),
      ),
    );
  }

  void _openEditTxn(LedgerTransaction txn) {
    showTxnFormSheet(
      context,
      customer: widget.customer,
      editingTxn: txn,
    );
  }

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
    final cleanPhone = widget.customer.phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No mobile number added for this customer')),
      );
      return;
    }
    final balance = widget.customer.balance;
    final balanceText = formatRupees(balance);
    final status = balance > 0 ? "outstanding Udhar (debit)" : (balance < 0 ? "advance Jama (credit)" : "settled balance");
    final message = "Hello ${widget.customer.name},\n\nYour current net balance status at Prem Kirana Store is *${balanceText.replaceAll(" ", "")}* ($status).\n\nThank you!\nPrem Kirana Ledger";
    
    var phoneForUrl = cleanPhone;
    if (phoneForUrl.length == 10) {
      phoneForUrl = "91$phoneForUrl";
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
    final cleanPhone = widget.customer.phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No mobile number added for this customer')),
      );
      return;
    }
    final balance = widget.customer.balance;
    final balanceText = formatRupees(balance);
    final status = balance > 0 ? "outstanding Udhar" : (balance < 0 ? "advance Jama" : "settled balance");
    final message = "Hello ${widget.customer.name},\n\nYour current net balance status at Prem Kirana Store is ${balanceText.replaceAll(" ", "")} ($status).\n\nThank you!\nPrem Kirana Ledger";
    final url = "sms:$cleanPhone?body=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Share.share(message, subject: "Ledger Statement Reminder");
    }
  }

  void _confirmDeleteSingleTxn(LedgerTransaction txn) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: c.udhar, size: 22),
            const SizedBox(width: 8),
            Text('Delete Transaction?', style: TextStyle(color: c.textBody, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this ${txn.type.label} of ${formatRupees(txn.amount)}? Customer balance will be updated.',
          style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.udhar,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              context.read<LedgerProvider>().deleteSingleTransaction(widget.customer, txn);
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Transaction deleted & balance recalculated'),
                  backgroundColor: c.udhar,
                ),
              );
            },
            child: const Text('Delete Entry', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelected() {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: c.udhar, size: 22),
            const SizedBox(width: 8),
            Text('Delete ${_selectedTxnIds.length} Transactions?',
                style: TextStyle(color: c.textBody, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete the ${_selectedTxnIds.length} selected transaction(s)? Customer balance will be recalculated automatically.',
          style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.udhar,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final provider = context.read<LedgerProvider>();
              final txnsToDelete = widget.customer.transactions
                  .where((t) => _selectedTxnIds.contains(t.id))
                  .toList();
              for (final t in txnsToDelete) {
                provider.deleteSingleTransaction(widget.customer, t);
              }
              setState(() {
                _selectedTxnIds.clear();
              });
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted ${txnsToDelete.length} transaction(s)'),
                  backgroundColor: c.udhar,
                ),
              );
            },
            child: const Text('Delete Selected', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
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
      builder: (_) => TransactionDetailsSheet(
        customer: widget.customer,
        txn: txn,
        onEdit: () => _openEditTxn(txn),
        onShare: () => _shareTxn(txn),
        onDelete: () => _confirmDeleteSingleTxn(txn),
      ),
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
    final provider = context.watch<LedgerProvider>();
    final customer = widget.customer;
    final balance = customer.balance;
    final allTxns = _filteredTxns;
    final showAll = _showAllHistory || allTxns.length <= 3 || _query.trim().isNotEmpty;
    final txnsToShow = showAll ? allTxns : allTxns.sublist(allTxns.length - 3);
    final inSelectionMode = _selectedTxnIds.isNotEmpty;

    return Scaffold(
      backgroundColor: c.bgDeep,
      appBar: AppBar(
        backgroundColor: inSelectionMode ? c.brandPrimary.withOpacity(0.15) : c.bgDeep,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: inSelectionMode ? 0 : 12,
        leading: inSelectionMode
            ? IconButton(
                icon: Icon(Icons.close, color: c.textBody),
                onPressed: () => setState(() => _selectedTxnIds.clear()),
              )
            : null,
        title: inSelectionMode
            ? Text(
                '${_selectedTxnIds.length} Selected',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textBody),
              )
            : Row(
                children: [
                  InkWell(
                    onTap: _openEditCustomer,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.brandPrimary.withOpacity(0.12),
                        border: Border.all(color: c.brandPrimary.withOpacity(0.25)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: customer.photoPath != null && File(customer.photoPath!).existsSync()
                          ? Image.file(File(customer.photoPath!), fit: BoxFit.cover)
                          : Text(customer.initials, style: TextStyle(color: c.brandPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            customer.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: c.textBody,
                              height: 1.15,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Balance: ${formatRupees(balance)}',
                          style: AppTheme.rupeeMono(balance > 0 ? c.udhar : c.jama, size: 11.5, weight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: inSelectionMode
            ? [
                IconButton(
                  icon: Icon(Icons.delete_outline, color: c.udhar, size: 22),
                  tooltip: 'Delete Selected',
                  onPressed: _confirmDeleteSelected,
                ),
              ]
            : [
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 36),
                  icon: Icon(_searchOpen ? Icons.close : Icons.search, color: c.muted, size: 20),
                  tooltip: 'Search timeline',
                  onPressed: () => setState(() {
                    _searchOpen = !_searchOpen;
                    if (!_searchOpen) _query = '';
                  }),
                ),
                if (customer.whatsappEnabled)
                  IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    constraints: const BoxConstraints(minWidth: 34, minHeight: 36),
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 19),
                    tooltip: 'Send statement via WhatsApp',
                    onPressed: _sendLedgerViaWhatsApp,
                  ),
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 36),
                  icon: Icon(Icons.message_outlined, color: c.muted, size: 19),
                  tooltip: 'Send reminder via SMS',
                  onPressed: _sendLedgerViaSMS,
                ),
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 36),
                  icon: Icon(Icons.picture_as_pdf_outlined, color: c.muted, size: 19),
                  tooltip: 'Export statement to PDF',
                  onPressed: _exportPdf,
                ),
                const SizedBox(width: 4),
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
                      final isSelected = _selectedTxnIds.contains(txn.id);

                      return TransactionTile(
                        txn: txn,
                        isSelected: isSelected,
                        onTap: () {
                          if (inSelectionMode) {
                            setState(() {
                              if (isSelected) {
                                _selectedTxnIds.remove(txn.id);
                              } else {
                                _selectedTxnIds.add(txn.id);
                              }
                            });
                          } else {
                            _showTxnDetails(txn);
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTxnIds.remove(txn.id);
                            } else {
                              _selectedTxnIds.add(txn.id);
                            }
                          });
                        },
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
          border: Border.all(color: color.withOpacity(0.4), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
