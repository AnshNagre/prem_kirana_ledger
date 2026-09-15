import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../models/transaction.dart';
import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class TransactionTile extends StatelessWidget {
  final LedgerTransaction txn;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const TransactionTile({
    super.key,
    required this.txn,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isUdhar = txn.type.isUdhar;
    final accent = isUdhar ? c.udhar : c.jama;

    return Padding(
      padding: const EdgeInsets.only(left: 30, bottom: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -30 + 12,
            top: 4,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isSelected ? c.brandPrimary : accent,
                shape: BoxShape.circle,
                border: Border.all(color: c.bgDeep, width: 2),
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            onLongPress: onLongPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? c.brandPrimary.withOpacity(0.12) : c.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? c.brandPrimary : c.borderHairline,
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  if (isSelected) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: c.brandPrimary, shape: BoxShape.circle),
                      child: Icon(Icons.check, size: 12, color: c.bgDeep),
                    ),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: accent.withOpacity(0.35), width: 0.9),
                              ),
                              child: Text(
                                txn.type.label,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  color: accent,
                                ),
                              ),
                            ),
                            if (txn.mode != PaymentMode.none) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  txn.mode.label,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.muted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (txn.imagePath != null) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.image_outlined, size: 12, color: c.muted),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          txn.desc.isEmpty ? '—' : txn.desc,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.textBody),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 11, color: c.muted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${txn.date} · ${txn.time}',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${isUdhar ? '+' : '-'}${formatRupees(txn.amount)}',
                            style: AppTheme.rupeeMono(accent, size: 15, weight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Bal ${formatRupees(txn.balAfter)}',
                            style: AppTheme.rupeeMono(c.muted, size: 10, weight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with the full details of a single transaction.
class TransactionDetailsSheet extends StatelessWidget {
  final Customer customer;
  final LedgerTransaction txn;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const TransactionDetailsSheet({
    super.key,
    required this.customer,
    required this.txn,
    required this.onEdit,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isUdhar = txn.type.isUdhar;
    final accent = isUdhar ? c.udhar : c.jama;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: c.muted.withOpacity(0.35), borderRadius: BorderRadius.circular(3)),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accent.withOpacity(0.35), width: 0.9),
                      ),
                      child: Text(
                        txn.type.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(txn.desc.isEmpty ? 'No remarks' : txn.desc,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textBody)),
                    const SizedBox(height: 4),
                    Text('${txn.date} · ${txn.time}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${isUdhar ? '+' : '-'}${formatRupees(txn.amount)}',
                      style: AppTheme.rupeeMono(accent, size: 20, weight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Running Bal: ${formatRupees(txn.balAfter)}',
                      style: AppTheme.rupeeMono(c.muted, size: 11, weight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          if (txn.imagePath != null && File(txn.imagePath!).existsSync()) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _showEnlargedImage(context, txn.imagePath!),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.bgSurface,
                  border: Border.all(color: c.borderHairline),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TRANSACTION PROOF IMAGE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c.muted)),
                        Row(
                          children: [
                            Icon(Icons.zoom_in, size: 15, color: c.brandPrimary),
                            const SizedBox(width: 4),
                            Text('Tap to Enlarge',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c.brandPrimary)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(txn.imagePath!), fit: BoxFit.contain),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // 1. Edit Transaction Button (Above Share Receipt)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onEdit();
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Transaction', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.brandPrimary,
                foregroundColor: c.bgDeep,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 2. Share Receipt Button (Below Edit Transaction)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onShare();
              },
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share Receipt', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.brandPrimary.withOpacity(0.5)),
                foregroundColor: c.brandPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. Delete / Close row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                    icon: Icon(Icons.delete_outline, size: 16, color: c.udhar),
                    label: Text('Delete', style: TextStyle(fontWeight: FontWeight.w800, color: c.udhar, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.udhar.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.borderHairline),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Close', style: TextStyle(fontWeight: FontWeight.w800, color: c.muted, fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEnlargedImage(BuildContext context, String path) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Positioned(
              bottom: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Pinch or double tap to zoom',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
