import 'dart:io';
import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class TransactionTile extends StatelessWidget {
  final LedgerTransaction txn;
  final VoidCallback onTap;

  const TransactionTile({super.key, required this.txn, required this.onTap});

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
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: c.bgDeep, width: 2),
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.borderHairline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                txn.type.label,
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: accent),
                              ),
                            ),
                            if (txn.mode != PaymentMode.none) ...[
                              const SizedBox(width: 6),
                              Text(txn.mode.label,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.muted)),
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
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textBody),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text('${txn.date} · ${txn.time}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.muted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isUdhar ? '+' : '-'}${formatRupees(txn.amount)}',
                        style: AppTheme.rupeeMono(accent, size: 14, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text('Bal ${formatRupees(txn.balAfter)}',
                          style: AppTheme.rupeeMono(c.muted, size: 10, weight: FontWeight.w600)),
                    ],
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

/// Bottom sheet with the full details of a single transaction, mirroring
/// the `detailsDrawerOverlay` in the HTML app.
class TransactionDetailsSheet extends StatelessWidget {
  final LedgerTransaction txn;
  const TransactionDetailsSheet({super.key, required this.txn});

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
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
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
                      decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(txn.type.label,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accent)),
                    ),
                    const SizedBox(height: 8),
                    Text(txn.desc.isEmpty ? 'No remarks' : txn.desc,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textBody)),
                    const SizedBox(height: 4),
                    Text('${txn.date} · ${txn.time}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
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
          if (txn.imagePath != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.bgSurface,
                border: Border.all(color: c.borderHairline),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRANSACTION PROOF IMAGE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c.muted)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(txn.imagePath!), fit: BoxFit.contain),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.borderHairline),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('CLOSE DETAILS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: c.muted)),
            ),
          ),
        ],
      ),
    );
  }
}
