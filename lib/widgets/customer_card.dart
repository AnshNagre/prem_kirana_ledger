import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showTodayJama;
  final DateTime? selectedJamaDate;

  const CustomerCard({
    super.key,
    required this.customer,
    required this.onTap,
    this.onLongPress,
    this.showTodayJama = false,
    this.selectedJamaDate,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isHindi = context.select<LedgerProvider, bool>((p) => p.isHindiMode);
    final balance = customer.balance;
    final isSettled = balance <= 0;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: showTodayJama ? c.jama.withOpacity(0.4) : c.borderHairline,
            width: showTodayJama ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            _Avatar(customer: customer),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Account Number (only if non-empty) + Category Badge
                  Row(
                    children: [
                      if (customer.accountNumber.trim().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.brandPrimary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            customer.accountNumber,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: c.brandPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      CustomerCategoryBadge(category: customer.category),
                      if (customer.whatsappEnabled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFF25D366).withOpacity(0.4), width: 0.8),
                          ),
                          child: const Text(
                            'WA',
                            style: TextStyle(
                              color: Color(0xFF25D366),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Row 2: Customer Name
                  Text(
                    customer.displayName(isHindi: isHindi).toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, height: 1.15, color: c.textBody),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),

                  // Row 3: Phone
                  Text(
                    customer.phone.trim().isNotEmpty ? customer.phone : 'No phone added',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: customer.phone.trim().isNotEmpty ? FontWeight.w600 : FontWeight.w500,
                      color: customer.phone.trim().isNotEmpty ? c.muted : c.muted.withOpacity(0.6),
                      fontStyle: customer.phone.trim().isNotEmpty ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Right side: Balance or Jama on selected date
            if (showTodayJama) () {
              final d = selectedJamaDate ?? DateTime.now();
              final now = DateTime.now();
              final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
              final yesterday = now.subtract(const Duration(days: 1));
              final isYesterday = d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day;
              final jamaAmount = customer.jamaOnDate(d);
              final badgeLabel = isToday
                  ? (isHindi ? 'आज जमा' : 'CREDITED TODAY')
                  : isYesterday
                      ? (isHindi ? 'कल जमा' : 'CREDITED YESTERDAY')
                      : (isHindi
                          ? '${DateFormat('dd MMM').format(d)} को जमा'
                          : 'CREDITED ON ${DateFormat('dd MMM').format(d).toUpperCase()}');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatRupees(jamaAmount, withSign: true),
                        style: AppTheme.rupeeMono(c.jama, size: 15, weight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: c.jama.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: c.jama.withOpacity(0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: c.jama,
                      ),
                    ),
                  ),
                ],
              );
            }()
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatRupees(balance),
                        style: AppTheme.rupeeMono(isSettled ? c.jama : c.udhar, size: 15, weight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isSettled ? c.jama : c.udhar).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isSettled ? c.jama : c.udhar).withOpacity(0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      isSettled
                          ? (isHindi ? 'जमा' : 'JAMA')
                          : (isHindi ? 'उधार' : 'UDHAR'),
                      style: TextStyle(
                        fontSize: isHindi ? 11 : 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: isHindi ? 0.2 : 0.6,
                        color: isSettled ? c.jama : c.udhar,
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

class CustomerCategoryBadge extends StatelessWidget {
  final CustomerCategory category;
  const CustomerCategoryBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (category) {
      case CustomerCategory.newCustomer:
        bg = const Color(0xFFE8A33D);
        fg = const Color(0xFFE8A33D);
        break;
      case CustomerCategory.oldCustomer:
        bg = const Color(0xFF6366F1);
        fg = const Color(0xFF6366F1);
        break;
      case CustomerCategory.dailyCustomer:
        bg = const Color(0xFF06B6D4);
        fg = const Color(0xFF06B6D4);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withOpacity(0.35), width: 0.9),
      ),
      child: Text(
        category.label.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Customer customer;
  const _Avatar({required this.customer});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final photo = customer.photoPath;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: c.brandPrimary.withOpacity(0.1),
        border: Border.all(color: c.brandPrimary.withOpacity(0.25), width: 1.2),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo != null && File(photo).existsSync()
          ? Image.file(File(photo), fit: BoxFit.cover)
          : Center(
              child: Text(
                customer.initials,
                style: TextStyle(color: c.brandPrimary, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
    );
  }
}
