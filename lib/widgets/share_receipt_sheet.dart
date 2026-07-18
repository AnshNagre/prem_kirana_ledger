import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../models/customer.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Ticket-style transaction receipt preview, mirroring the `shareModalOverlay`
/// design in the HTML app (cream ticket card + dashed dividers).
class ShareReceiptSheet extends StatelessWidget {
  final Customer customer;
  final LedgerTransaction txn;
  const ShareReceiptSheet({super.key, required this.customer, required this.txn});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isUdhar = txn.type.isUdhar;
    final bannerColor = isUdhar ? const Color(0xFFE23F49) : const Color(0xFF1FAA59);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFBF7),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8A33D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A0A0D))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Prem Kirana & General Store's KANHAN",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0D5C4B))),
                          SizedBox(height: 2),
                          Text('Swami Vivekanand Nagar KANHAN',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFA78BFA))),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _dashedDivider(),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(color: bannerColor, borderRadius: BorderRadius.circular(30)),
                    child: Text(
                      isUdhar ? 'DEBIT RECEIPT' : 'CREDIT RECEIPT',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _infoRow(Icons.person_outline, customer.name),
                const SizedBox(height: 10),
                _infoRow(Icons.access_time, '${txn.date} ${txn.time}', color: const Color(0xFF7C3AED)),
                const SizedBox(height: 10),
                _infoRow(Icons.receipt_long_outlined, txn.desc.isEmpty ? '—' : txn.desc, italic: true),
                if (txn.imagePath != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(txn.imagePath!), height: 90, width: 90, fit: BoxFit.cover),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _dashedDivider(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                    Text(formatRupees(txn.amount),
                        style: TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.w900, color: bannerColor)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Closing Balance:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                      Text(formatRupees(txn.balAfter),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFE23F49))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (customer.whatsappEnabled) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _sendReceiptViaWhatsApp(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('SEND VIA WHATSAPP', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => _shareReceiptText(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.brandPrimary,
                foregroundColor: c.bgDeep,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('SHARE RECEIPT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                foregroundColor: Colors.white70,
              ),
              child: const Text('DISMISS PREVIEW', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareReceiptText(BuildContext context) async {
    final isUdhar = txn.type.isUdhar;
    final amountText = formatRupees(txn.amount);
    final balanceText = formatRupees(txn.balAfter);
    final message = "Prem Kirana Store Receipt:\n\n"
        "Customer: ${customer.name}\n"
        "Type: ${isUdhar ? 'UDHAR (DEBIT)' : 'JAMA (CREDIT)'}\n"
        "Amount: ${amountText.replaceAll(" ", "")}\n"
        "Date: ${txn.date} ${txn.time}\n"
        "Remarks: ${txn.desc.isEmpty ? '—' : txn.desc}\n\n"
        "Closing Balance: ${balanceText.replaceAll(" ", "")}\n\n"
        "Thank you!";
    await Share.share(message, subject: "Transaction Receipt - ${customer.name}");
  }

  Future<void> _sendReceiptViaWhatsApp(BuildContext context) async {
    final isUdhar = txn.type.isUdhar;
    final amountText = formatRupees(txn.amount);
    final balanceText = formatRupees(txn.balAfter);
    final message = "Hello ${customer.name},\n\nHere is your receipt from Prem Kirana Store:\n\n"
        "Type: *${isUdhar ? 'UDHAR (DEBIT)' : 'JAMA (CREDIT)'}*\n"
        "Amount: *${amountText.replaceAll(" ", "")}*\n"
        "Date: *${txn.date} ${txn.time}*\n"
        "Remarks: *${txn.desc.isEmpty ? '—' : txn.desc}*\n\n"
        "Closing Balance: *${balanceText.replaceAll(" ", "")}*\n\n"
        "Thank you!\nPrem Kirana Ledger";
    final cleanPhone = customer.phone.replaceAll(RegExp(r'\D'), '');
    
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }

  Widget _infoRow(IconData icon, String text, {Color? color, bool italic = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color ?? const Color(0xFF1E293B),
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dashedDivider() {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.5;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
