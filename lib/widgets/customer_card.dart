import 'dart:io';
import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const CustomerCard({super.key, required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final balance = customer.balance;
    final isSettled = balance <= 0;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.borderHairline),
        ),
        child: Row(
          children: [
            _Avatar(customer: customer),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          customer.name.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (customer.whatsappEnabled) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                          ),
                          child: const Text(
                            'WA',
                            style: TextStyle(
                              color: Color(0xFF25D366),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    customer.phone,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupees(balance),
                  style: AppTheme.rupeeMono(isSettled ? c.jama : c.udhar, size: 15, weight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isSettled ? c.jama : c.udhar).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isSettled ? 'Jama' : 'Udhar',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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

class _Avatar extends StatelessWidget {
  final Customer customer;
  const _Avatar({required this.customer});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final photo = customer.photoPath;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.2),
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
