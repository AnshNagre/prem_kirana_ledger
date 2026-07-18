import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/add_customer_sheet.dart';
import '../widgets/bulk_txn_sheet.dart';
import '../widgets/customer_card.dart';
import '../widgets/settings_sheet.dart';
import 'customer_timeline.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  void _openAddCustomer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(color: context.colors.bgElevated, child: const AddCustomerSheet()),
      ),
    );
  }

  void _openBulkTxn(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BulkTxnSheet(),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(color: context.colors.bgElevated, child: const SettingsSheet()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final provider = context.watch<LedgerProvider>();
    final customers = provider.visibleCustomers;

    return Scaffold(
      backgroundColor: c.bgDeep,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _Header(onSettingsTap: () => _openSettings(context)),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'TOTAL UDHAR',
                              value: formatRupees(provider.dashboardTotalUdhar),
                              color: c.udhar,
                              selected: provider.filter == HomeFilter.udharOnly,
                              onTap: () => provider.toggleFilter(HomeFilter.udharOnly),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: "TODAY'S JAMA",
                              value: formatRupees(provider.dashboardTodayJama, withSign: true),
                              color: c.jama,
                              selected: provider.filter == HomeFilter.jamaToday,
                              onTap: () => provider.toggleFilter(HomeFilter.jamaToday),
                            ),
                          ),
                        ],
                      ),
                      if (provider.filter != HomeFilter.none || provider.searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: c.brandPrimary.withOpacity(0.1),
                            border: Border.all(color: c.brandPrimary.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: c.brandPrimary, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(
                                provider.filter == HomeFilter.udharOnly
                                    ? 'Filtering: Outstanding Udhar'
                                    : provider.filter == HomeFilter.jamaToday
                                        ? "Filtering: Today's Jama"
                                        : 'Filtering by search',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.brandPrimary),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: provider.clearFilter,
                                child: Text('CLEAR',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c.brandPrimary)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        onChanged: provider.setSearchQuery,
                        decoration: InputDecoration(
                          hintText: 'Search accounts by name or phone...',
                          hintStyle: TextStyle(color: c.muted, fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: c.brandPrimary, size: 20),
                          filled: true,
                          fillColor: c.bgSurface.withOpacity(0.5),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.borderHairline)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.borderHairline)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.brandPrimary.withOpacity(0.4))),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ALL CUSTOMERS LEDGER',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.muted, letterSpacing: 0.8)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.bgSurface.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: c.borderHairline),
                            ),
                            child: Text('${customers.length} active accounts',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.muted)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (customers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text('No customers found', style: TextStyle(color: c.muted, fontSize: 13)),
                          ),
                        )
                      else
                        ...customers.map((customer) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: CustomerCard(
                                customer: customer,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CustomerTimelineScreen(customer: customer)),
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.playlist_add_outlined,
                    tooltip: 'Bulk Transactions',
                    onTap: () => _openBulkTxn(context),
                    iconColor: c.brandPrimary,
                    width: 50,
                    height: 50,
                    borderRadius: 16,
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: c.brandPrimary.withOpacity(0.55),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _openAddCustomer(context),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.brandPrimary,
                        foregroundColor: c.bgDeep,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                          side: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onSettingsTap;
  const _Header({required this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final provider = context.watch<LedgerProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderHairline))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STORE DASHBOARD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c.muted, letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Text('Prem Kirana Ledger', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.textBody)),
              ],
            ),
          ),
          _RoundIconButton(
            icon: provider.themeMode == ThemeMode.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            tooltip: 'Toggle Theme',
            onTap: provider.toggleTheme,
          ),
          const SizedBox(width: 8),
          _RoundIconButton(icon: Icons.settings_outlined, tooltip: 'Settings', onTap: onSettingsTap),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? c.brandPrimary.withOpacity(0.5) : c.borderHairline, width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c.muted, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(value, style: AppTheme.rupeeMono(color, size: 21, weight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? iconColor;
  final double width;
  final double height;
  final double borderRadius;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor,
    this.width = 44,
    this.height = 44,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: c.bgSurface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: c.borderHairline),
          ),
          child: Icon(icon, size: 18, color: iconColor ?? c.muted),
        ),
      ),
    );
  }
}
