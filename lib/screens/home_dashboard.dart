import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../state/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/add_customer_sheet.dart';
import '../widgets/bulk_txn_sheet.dart';
import '../widgets/common.dart';
import '../widgets/customer_card.dart';
import '../widgets/import_excel_sheet.dart';
import '../widgets/settings_sheet.dart';
import 'customer_timeline.dart';
import '../utils/update_checker.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdate(context);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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

  void _openEditCustomer(BuildContext context, Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(color: context.colors.bgElevated, child: AddCustomerSheet(customer: customer)),
      ),
    );
  }

  void _confirmDeleteCustomer(BuildContext context, Customer customer) {
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
            Text('Delete Customer?', style: TextStyle(color: c.textBody, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete ${customer.name.toUpperCase()}${customer.accountNumber.isNotEmpty ? " (Acc: ${customer.accountNumber})" : ""} and all associated ledger transactions? This cannot be undone.',
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
              context.read<LedgerProvider>().deleteCustomer(customer);
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted customer "${customer.name}"'),
                  backgroundColor: c.udhar,
                ),
              );
            },
            child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showCustomerOptions(BuildContext context, Customer customer) {
    final c = context.colors;
    final isHindi = context.read<LedgerProvider>().isHindiMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          color: c.bgElevated,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              sheetGrabber(),
              // Customer summary header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.bgSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.borderHairline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.brandPrimary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.brandPrimary.withOpacity(0.25)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: customer.photoPath != null && File(customer.photoPath!).existsSync()
                          ? Image.file(File(customer.photoPath!), fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                customer.initials,
                                style: TextStyle(color: c.brandPrimary, fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (customer.accountNumber.trim().isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: c.brandPrimary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    customer.accountNumber,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: c.brandPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              CustomerCategoryBadge(category: customer.category),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            customer.displayName(isHindi: isHindi).toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: c.textBody),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (customer.phone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(customer.phone, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted)),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatRupees(customer.balance),
                          style: AppTheme.rupeeMono(customer.balance <= 0 ? c.jama : c.udhar, size: 14, weight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (customer.balance <= 0 ? c.jama : c.udhar).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: (customer.balance <= 0 ? c.jama : c.udhar).withOpacity(0.35), width: 1),
                          ),
                          child: Text(
                            customer.balance <= 0
                                ? (isHindi ? 'जमा' : 'JAMA')
                                : (isHindi ? 'उधार' : 'UDHAR'),
                            style: TextStyle(
                              fontSize: isHindi ? 10.5 : 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: isHindi ? 0.2 : 0.5,
                              color: customer.balance <= 0 ? c.jama : c.udhar,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Option 1: Open Ledger Timeline
              _OptionTile(
                icon: Icons.receipt_long_rounded,
                iconColor: c.brandPrimary,
                title: 'Open Ledger Timeline',
                subtitle: 'View transactions history, add Udhar/Jama, export PDF',
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CustomerTimelineScreen(customer: customer)),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Option 2: Edit Customer
              _OptionTile(
                icon: Icons.edit_outlined,
                iconColor: const Color(0xFF6366F1),
                title: 'Edit Customer Profile',
                subtitle: 'Update name, mobile number, category, or photo',
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _openEditCustomer(context, customer);
                },
              ),
              const SizedBox(height: 10),

              // Option 3: Delete Customer
              _OptionTile(
                icon: Icons.delete_outline_rounded,
                iconColor: c.udhar,
                title: 'Delete Customer Account',
                subtitle: 'Permanently remove account and all transactions',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _confirmDeleteCustomer(context, customer);
                },
              ),
            ],
          ),
        ),
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
    final isJamaTodayFilter = provider.filter == HomeFilter.jamaToday;

    return Scaffold(
      backgroundColor: c.bgDeep,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _Header(
                  onSettingsTap: () => _openSettings(context),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: provider.categoryFilter != null
                                    ? 'TOTAL UDHAR (${provider.categoryFilter!.label.toUpperCase()})'
                                    : 'TOTAL UDHAR',
                                value: formatRupees(provider.dashboardTotalUdhar),
                                color: c.udhar,
                                selected: provider.filter == HomeFilter.udharOnly,
                                onTap: () => provider.toggleFilter(HomeFilter.udharOnly),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                titleWidget: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        provider.categoryFilter != null
                                            ? "${provider.jamaDateShortTitle} JAMA (${provider.categoryFilter!.label.toUpperCase()})"
                                            : "${provider.jamaDateShortTitle} JAMA",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: provider.filter == HomeFilter.jamaToday ? c.jama : c.muted,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      _JamaDateDropdown(
                                        selectedDate: provider.selectedJamaDate,
                                        color: c.jama,
                                        isSelected: provider.filter == HomeFilter.jamaToday,
                                        onDateSelected: (pickedDate) {
                                          provider.setSelectedJamaDate(pickedDate);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                value: formatRupees(provider.dashboardSelectedJama, withSign: true),
                                color: c.jama,
                                selected: provider.filter == HomeFilter.jamaToday,
                                onTap: () => provider.toggleFilter(HomeFilter.jamaToday),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (provider.filter != HomeFilter.none || provider.categoryFilter != null) ...[
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
                              Expanded(
                                child: Text(
                                  provider.filter == HomeFilter.udharOnly
                                      ? 'Filter: Outstanding Udhar'
                                      : provider.filter == HomeFilter.jamaToday
                                          ? "Filter: ${provider.jamaDateFilterLabel} (Credit)"
                                          : 'Category: ${provider.categoryFilter!.label} Customers',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.brandPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  provider.clearFilter();
                                  _searchCtrl.clear();
                                },
                                child: Text('CLEAR FILTER',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c.brandPrimary)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchCtrl,
                        onChanged: provider.setSearchQuery,
                        decoration: InputDecoration(
                          hintText: 'Search by name, acc no, or phone...',
                          hintStyle: TextStyle(color: c.muted, fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: c.brandPrimary, size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 18, color: c.muted),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    provider.setSearchQuery('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: c.bgSurface.withOpacity(0.5),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.borderHairline)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.borderHairline)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.brandPrimary.withOpacity(0.4))),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Customer Category Filters (ALL, NEW, OLD, DAILY)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _CategoryFilterChip(
                              label: 'ALL',
                              count: provider.customers.length,
                              isSelected: provider.categoryFilter == null,
                              color: c.brandPrimary,
                              onTap: () => provider.setCategoryFilter(null),
                            ),
                            const SizedBox(width: 8),
                            _CategoryFilterChip(
                              label: 'NEW',
                              count: provider.countNewCustomers,
                              isSelected: provider.categoryFilter == CustomerCategory.newCustomer,
                              color: const Color(0xFFE8A33D),
                              onTap: () => provider.toggleCategoryFilter(CustomerCategory.newCustomer),
                            ),
                            const SizedBox(width: 8),
                            _CategoryFilterChip(
                              label: 'OLD',
                              count: provider.countOldCustomers,
                              isSelected: provider.categoryFilter == CustomerCategory.oldCustomer,
                              color: const Color(0xFF6366F1),
                              onTap: () => provider.toggleCategoryFilter(CustomerCategory.oldCustomer),
                            ),
                            const SizedBox(width: 8),
                            _CategoryFilterChip(
                              label: 'DAILY',
                              count: provider.countDailyCustomers,
                              isSelected: provider.categoryFilter == CustomerCategory.dailyCustomer,
                              color: const Color(0xFF06B6D4),
                              onTap: () => provider.toggleCategoryFilter(CustomerCategory.dailyCustomer),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isJamaTodayFilter ? "TODAY'S CREDITED ACCOUNTS" : 'CUSTOMERS LEDGER',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isJamaTodayFilter ? c.jama : c.muted, letterSpacing: 0.8),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.bgSurface.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: c.borderHairline),
                            ),
                            child: Text('${customers.length} accounts',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.muted)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (customers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, color: c.muted, size: 36),
                                const SizedBox(height: 10),
                                Text('No customers found', style: TextStyle(color: c.muted, fontSize: 13)),
                              ],
                            ),
                          ),
                        )
                      else
                        ...customers.map((customer) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: CustomerCard(
                                customer: customer,
                                showTodayJama: isJamaTodayFilter,
                                selectedJamaDate: provider.selectedJamaDate,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => CustomerTimelineScreen(customer: customer)),
                                  );
                                },
                                onLongPress: () => _showCustomerOptions(context, customer),
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
                    width: 48,
                    height: 48,
                    borderRadius: 16,
                  ),
                  const SizedBox(width: 10),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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

class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : c.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : c.borderHairline,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isSelected ? c.bgDeep : c.textBody,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? c.bgDeep.withOpacity(0.2) : c.brandPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? c.bgDeep : c.brandPrimary,
                ),
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
                Text('Prem Kirana Store', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.textBody)),
              ],
            ),
          ),
          InkWell(
            onTap: provider.toggleHindiMode,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: provider.isHindiMode ? c.brandPrimary.withOpacity(0.18) : c.bgSurface,
                border: Border.all(
                  color: provider.isHindiMode ? c.brandPrimary : c.borderHairline,
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'EN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: !provider.isHindiMode ? FontWeight.w900 : FontWeight.w600,
                      color: !provider.isHindiMode ? c.brandPrimary : c.muted,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text('⇄', style: TextStyle(fontSize: 10, color: c.muted)),
                  ),
                  Text(
                    'हि',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: provider.isHindiMode ? FontWeight.w900 : FontWeight.w600,
                      color: provider.isHindiMode ? c.brandPrimary : c.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
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

class _JamaDateDropdown extends StatelessWidget {
  final DateTime selectedDate;
  final Color color;
  final bool isSelected;
  final ValueChanged<DateTime> onDateSelected;

  const _JamaDateDropdown({
    required this.selectedDate,
    required this.color,
    required this.isSelected,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sel = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isToday = sel == today;
    final isYesterday = sel == yesterday;
    final isCustom = !isToday && !isYesterday;

    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: c.bgElevated,
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Change Jama Date',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.borderHairline),
        ),
        color: c.bgElevated,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Icon(
            Icons.arrow_drop_down_rounded,
            size: 18,
            color: isSelected ? color : c.muted,
          ),
        ),
        onSelected: (val) async {
          if (val == 'today') {
            onDateSelected(DateTime.now());
          } else if (val == 'yesterday') {
            onDateSelected(DateTime.now().subtract(const Duration(days: 1)));
          } else if (val == 'custom') {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (dialogCtx, child) {
                return Theme(
                  data: Theme.of(dialogCtx).copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: c.jama,
                      onPrimary: c.bgDeep,
                      surface: c.bgElevated,
                      onSurface: c.textBody,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              onDateSelected(picked);
            }
          }
        },
        itemBuilder: (ctx) {
          return [
            PopupMenuItem(
              value: 'today',
              height: 40,
              child: Row(
                children: [
                  Icon(Icons.today_rounded, size: 16, color: isToday ? c.jama : c.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Today (${DateFormat('dd MMM').format(today)})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                        color: isToday ? c.jama : c.textBody,
                      ),
                    ),
                  ),
                  if (isToday) Icon(Icons.check, size: 16, color: c.jama),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'yesterday',
              height: 40,
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 16, color: isYesterday ? c.jama : c.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Yesterday (${DateFormat('dd MMM').format(yesterday)})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isYesterday ? FontWeight.w900 : FontWeight.w600,
                        color: isYesterday ? c.jama : c.textBody,
                      ),
                    ),
                  ),
                  if (isYesterday) Icon(Icons.check, size: 16, color: c.jama),
                ],
              ),
            ),
            const PopupMenuDivider(height: 8),
            PopupMenuItem(
              value: 'custom',
              height: 40,
              child: Row(
                children: [
                  Icon(Icons.edit_calendar_rounded, size: 16, color: isCustom ? c.jama : c.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCustom
                          ? 'Custom (${DateFormat('dd MMM yyyy').format(selectedDate)})'
                          : 'Custom Date...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCustom ? FontWeight.w900 : FontWeight.w600,
                        color: isCustom ? c.jama : c.textBody,
                      ),
                    ),
                  ),
                  if (isCustom) Icon(Icons.check, size: 16, color: c.jama),
                ],
              ),
            ),
          ];
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final String value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatCard({
    this.title,
    this.titleWidget,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color.withOpacity(0.7) : c.borderHairline,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 18,
              child: Align(
                alignment: Alignment.centerLeft,
                child: titleWidget ??
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title ?? '',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: selected ? color : c.muted,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 28,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: AppTheme.rupeeMono(color, size: 20, weight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive ? iconColor.withOpacity(0.3) : c.borderHairline,
            width: isDestructive ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconColor.withOpacity(0.3)),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDestructive ? iconColor : c.textBody,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: c.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: c.muted),
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
