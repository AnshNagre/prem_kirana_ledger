import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/formatters.dart';
import '../utils/google_drive_service.dart';
import '../utils/image_optimizer.dart';

class BulkTxnDraftEntry {
  final String customerName;
  final TxnType type;
  final double amount;
  final DateTime date;
  final String desc;
  final PaymentMode mode;
  final String? photoPath;

  BulkTxnDraftEntry({
    required this.customerName,
    required this.type,
    required this.amount,
    required this.date,
    this.desc = '',
    this.mode = PaymentMode.none,
    this.photoPath,
  });
}

enum HomeFilter { none, udharOnly, jamaToday }

class LedgerProvider extends ChangeNotifier {
  static const _prefsCustomersKey = 'pk_customers_v1';
  static const _prefsThemeKey = 'pk_theme_v1';

  final _uuid = const Uuid();
  final List<Customer> _customers = [];
  final List<BulkTxnDraftEntry> _bulkDraftEntries = [];
  ThemeMode _themeMode = ThemeMode.dark;
  HomeFilter _filter = HomeFilter.none;
  CustomerCategory? _categoryFilter;
  String _searchQuery = '';
  DateTime _selectedJamaDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  List<Customer> get customers => List.unmodifiable(_customers);
  List<BulkTxnDraftEntry> get bulkDraftEntries => List.unmodifiable(_bulkDraftEntries);
  ThemeMode get themeMode => _themeMode;
  HomeFilter get filter => _filter;
  CustomerCategory? get categoryFilter => _categoryFilter;
  String get searchQuery => _searchQuery;
  DateTime get selectedJamaDate => _selectedJamaDate;

  bool get isSelectedJamaDateToday {
    final now = DateTime.now();
    return _selectedJamaDate.year == now.year &&
        _selectedJamaDate.month == now.month &&
        _selectedJamaDate.day == now.day;
  }

  bool get isSelectedJamaDateYesterday {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return _selectedJamaDate.year == y.year &&
        _selectedJamaDate.month == y.month &&
        _selectedJamaDate.day == y.day;
  }

  String get jamaDateShortTitle {
    if (isSelectedJamaDateToday) return "TODAY'S";
    if (isSelectedJamaDateYesterday) return "YESTERDAY'S";
    return DateFormat('dd MMM').format(_selectedJamaDate).toUpperCase();
  }

  String get jamaDateFilterLabel {
    if (isSelectedJamaDateToday) return "Today's Jama";
    if (isSelectedJamaDateYesterday) return "Yesterday's Jama";
    return "Jama on ${DateFormat('dd MMM yyyy').format(_selectedJamaDate)}";
  }

  void setSelectedJamaDate(DateTime date) {
    _selectedJamaDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  /// Checks whether a customer already has an identical transaction on the specified date.
  bool hasExistingTransaction({
    required String customerName,
    required DateTime date,
    required double amount,
    required TxnType type,
  }) {
    final customer = findCustomerByName(customerName);
    if (customer == null) return false;
    return customer.transactions.any((t) =>
        t.type == type &&
        (t.amount - amount).abs() < 0.001 &&
        t.timestamp.year == date.year &&
        t.timestamp.month == date.month &&
        t.timestamp.day == date.day);
  }

  LedgerProvider() {
    _restore();
  }

  // ---------------------------------------------------------------------
  // Bulk Entry Drafts
  // ---------------------------------------------------------------------

  void setBulkDraftEntries(List<BulkTxnDraftEntry> entries) {
    _bulkDraftEntries
      ..clear()
      ..addAll(entries);
  }

  void clearBulkDraftEntries() {
    _bulkDraftEntries.clear();
  }

  // ---------------------------------------------------------------------
  // Derived dashboard totals (scoped to active category filter if selected)
  // ---------------------------------------------------------------------

  Iterable<Customer> get _metricsCustomers =>
      _categoryFilter == null ? _customers : _customers.where((c) => c.category == _categoryFilter);

  double get dashboardTotalUdhar =>
      _metricsCustomers.fold(0.0, (sum, c) => sum + (c.balance > 0 ? c.balance : 0));

  double get dashboardTodayJama => dashboardSelectedJama;

  double get dashboardSelectedJama =>
      _metricsCustomers.fold(0.0, (sum, c) => sum + c.jamaOnDate(_selectedJamaDate));

  int get countNewCustomers =>
      _customers.where((c) => c.category == CustomerCategory.newCustomer).length;

  int get countOldCustomers =>
      _customers.where((c) => c.category == CustomerCategory.oldCustomer).length;

  int get countDailyCustomers =>
      _customers.where((c) => c.category == CustomerCategory.dailyCustomer).length;

  /// Next sequential account number suggestion, e.g. PK-101, PK-102...
  String get nextSuggestedAccountNumber {
    int maxNumber = 100;
    for (final c in _customers) {
      final match = RegExp(r'(\d+)').firstMatch(c.accountNumber);
      if (match != null) {
        final n = int.tryParse(match.group(1)!);
        if (n != null && n > maxNumber) {
          maxNumber = n;
        }
      }
    }
    return 'PK-${maxNumber + 1}';
  }

  /// Natural alphanumeric account number comparator (e.g. PK-1, PK-2, PK-10, PK-100).
  static int compareAccountNumbers(String rawA, String rawB) {
    final a = rawA.trim();
    final b = rawB.trim();

    // Empty account numbers go last
    if (a.isEmpty && b.isEmpty) return 0;
    if (a.isEmpty) return 1;
    if (b.isEmpty) return -1;

    final matchA = RegExp(r'\d+').firstMatch(a);
    final matchB = RegExp(r'\d+').firstMatch(b);

    if (matchA != null && matchB != null) {
      final prefixA = a.substring(0, matchA.start).toLowerCase();
      final prefixB = b.substring(0, matchB.start).toLowerCase();
      if (prefixA != prefixB) {
        return prefixA.compareTo(prefixB);
      }

      final intA = int.tryParse(matchA.group(0)!);
      final intB = int.tryParse(matchB.group(0)!);
      if (intA != null && intB != null && intA != intB) {
        return intA.compareTo(intB);
      }
    }

    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  int _calculateSearchScore(Customer customer, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return 0;

    final name = customer.name.trim().toLowerCase();
    final acc = customer.accountNumber.trim().toLowerCase();
    final phone = customer.phone.trim().toLowerCase();
    final cat = customer.category.label.toLowerCase();

    // 1. Exact match on full name
    if (name == q) return 1000;

    // 2. Name starts with query or word in name starts with query
    final nameWords = name.split(RegExp(r'\s+'));
    if (name.startsWith(q)) return 800;
    if (nameWords.any((w) => w == q)) return 750;
    if (nameWords.any((w) => w.startsWith(q))) return 700;

    // 3. Name contains query as continuous substring
    if (name.contains(q)) return 500;

    // 4. Account number or phone exact/prefix match
    if (acc == q) return 400;
    if (acc.contains(q)) return 350;
    if (phone.contains(q)) return 300;
    if (cat.contains(q)) return 200;

    // 5. Strict fuzzy match fallback
    if (isFuzzyMatch(customer.name, query)) return 100;

    return 0;
  }

  /// Customers filtered by active filter chip + category chip + search box,
  /// sorted naturally by account number (e.g. PK-1, PK-2, PK-10).
  List<Customer> get visibleCustomers {
    Iterable<Customer> list = _customers;

    switch (_filter) {
      case HomeFilter.udharOnly:
        list = list.where((c) => c.balance > 0);
        break;
      case HomeFilter.jamaToday:
        list = list.where((c) => c.jamaOnDate(_selectedJamaDate) > 0);
        break;
      case HomeFilter.none:
        break;
    }

    if (_categoryFilter != null) {
      list = list.where((c) => c.category == _categoryFilter);
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((c) => _calculateSearchScore(c, q) > 0);
    }

    final sorted = list.toList()
      ..sort((a, b) {
        if (_searchQuery.trim().isNotEmpty) {
          final scoreA = _calculateSearchScore(a, _searchQuery);
          final scoreB = _calculateSearchScore(b, _searchQuery);
          if (scoreA != scoreB) {
            return scoreB.compareTo(scoreA); // higher relevance first
          }
        }
        final accCmp = compareAccountNumbers(a.accountNumber, b.accountNumber);
        if (accCmp != 0) return accCmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return sorted;
  }

  // ---------------------------------------------------------------------
  // Filter / search / theme controls
  // ---------------------------------------------------------------------

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleFilter(HomeFilter tapped) {
    _filter = _filter == tapped ? HomeFilter.none : tapped;
    notifyListeners();
  }

  void toggleCategoryFilter(CustomerCategory cat) {
    _categoryFilter = _categoryFilter == cat ? null : cat;
    notifyListeners();
  }

  void setCategoryFilter(CustomerCategory? cat) {
    _categoryFilter = cat;
    notifyListeners();
  }

  void clearFilter() {
    _filter = HomeFilter.none;
    _categoryFilter = null;
    _searchQuery = '';
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    _persistTheme();
  }

  void toggleTheme() {
    setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  // ---------------------------------------------------------------------
  // Customer CRUD
  // ---------------------------------------------------------------------

  Customer addCustomer({
    required String name,
    required String phone,
    String? accountNumber,
    CustomerCategory category = CustomerCategory.newCustomer,
    bool whatsappEnabled = false,
    String? photoPath,
  }) {
    final acc = (accountNumber != null) ? accountNumber.trim() : '';

    final customer = Customer(
      id: _uuid.v4(),
      accountNumber: acc,
      name: name.trim(),
      phone: phone.trim(),
      category: category,
      whatsappEnabled: whatsappEnabled,
      photoPath: photoPath,
    );
    _customers.insert(0, customer);
    _persist();
    notifyListeners();
    return customer;
  }

  void addCustomersBulk(List<Customer> newCustomers) {
    if (newCustomers.isEmpty) return;
    _customers.insertAll(0, newCustomers);
    _persist();
    notifyListeners();
  }

  /// Restores entire ledger state from a backup list of customers and persists immediately.
  void restoreFromBackup(List<Customer> restoredCustomers) {
    _customers
      ..clear()
      ..addAll(restoredCustomers);
    _persist();
    notifyListeners();
  }

  Customer? findCustomerByName(String name) {
    final normalized = name.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    if (normalized.isEmpty) return null;
    try {
      return _customers.firstWhere((c) =>
          c.name.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase() == normalized);
    } catch (_) {
      return null;
    }
  }

  Customer? findCustomerByPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '').trim();
    if (clean.isEmpty) return null;
    try {
      return _customers.firstWhere((c) =>
          c.phone.replaceAll(RegExp(r'\D'), '').trim() == clean);
    } catch (_) {
      return null;
    }
  }

  List<Customer> autocompleteByName(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final matches = _customers.where((c) => _calculateSearchScore(c, q) > 0).toList();
    matches.sort((a, b) {
      final scoreA = _calculateSearchScore(a, q);
      final scoreB = _calculateSearchScore(b, q);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      return compareAccountNumbers(a.accountNumber, b.accountNumber);
    });
    return matches.take(10).toList();
  }

  /// Recalculates running balance (balAfter) for all transactions of [customer].
  void _recomputeCustomerBalances(Customer customer) {
    customer.transactions.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    double running = 0.0;
    for (int i = 0; i < customer.transactions.length; i++) {
      final t = customer.transactions[i];
      running = t.type.isUdhar ? running + t.amount : running - t.amount;
      customer.transactions[i] = LedgerTransaction(
        id: t.id,
        type: t.type,
        amount: t.amount,
        desc: t.desc,
        timestamp: t.timestamp,
        mode: t.mode,
        balAfter: running,
        imagePath: t.imagePath,
      );
    }
  }

  /// Adds a transaction to [customer] and recomputes its running balance.
  LedgerTransaction addTransaction(
    Customer customer, {
    required TxnType type,
    required double amount,
    String desc = '',
    PaymentMode mode = PaymentMode.none,
    String? imagePath,
    DateTime? timestamp,
  }) {
    final txn = LedgerTransaction(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      desc: desc.trim(),
      mode: mode,
      timestamp: timestamp ?? DateTime.now(),
      balAfter: 0.0,
      imagePath: imagePath,
    );

    customer.transactions.add(txn);
    _recomputeCustomerBalances(customer);
    _persist();
    notifyListeners();
    return txn;
  }

  /// Edits an existing transaction in [customer] and recalculates all running balances.
  void editTransaction({
    required Customer customer,
    required String transactionId,
    TxnType? type,
    required double amount,
    required String desc,
    PaymentMode mode = PaymentMode.none,
    String? imagePath,
    DateTime? timestamp,
  }) {
    final index = customer.transactions.indexWhere((t) => t.id == transactionId);
    if (index == -1) return;

    final existing = customer.transactions[index];
    customer.transactions[index] = LedgerTransaction(
      id: existing.id,
      type: type ?? existing.type,
      amount: amount,
      desc: desc.trim(),
      timestamp: timestamp ?? existing.timestamp,
      mode: mode,
      balAfter: 0.0,
      imagePath: imagePath ?? existing.imagePath,
    );

    _recomputeCustomerBalances(customer);
    _persist();
    notifyListeners();
  }

  /// Deletes a single transaction from [customer] and updates remaining balances.
  void deleteSingleTransaction(Customer customer, LedgerTransaction txn) {
    customer.transactions.removeWhere((t) => t.id == txn.id);
    _recomputeCustomerBalances(customer);
    _persist();
    notifyListeners();
  }

  void deleteCustomerTransactions(Customer customer) {
    customer.transactions.clear();
    _persist();
    notifyListeners();
  }

  void deleteCustomer(Customer customer) {
    _customers.removeWhere((c) => c.id == customer.id);
    _persist();
    notifyListeners();
  }

  Customer? updateCustomer({
    required String customerId,
    required String name,
    required String phone,
    String? accountNumber,
    CustomerCategory category = CustomerCategory.newCustomer,
    bool whatsappEnabled = false,
    String? photoPath,
  }) {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index == -1) return null;

    final existing = _customers[index];
    final updatedAcc = (accountNumber != null)
        ? accountNumber.trim()
        : existing.accountNumber;

    existing.name = name.trim();
    existing.phone = phone.trim();
    existing.accountNumber = updatedAcc;
    existing.category = category;
    existing.whatsappEnabled = whatsappEnabled && phone.trim().isNotEmpty;
    existing.photoPath = photoPath;

    _persist();
    notifyListeners();
    return existing;
  }

  void updateWhatsappPreference(Customer customer, bool enabled) {
    customer.whatsappEnabled = enabled;
    _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Persistence (SharedPreferences mirrors the HTML app's localStorage use)
  // ---------------------------------------------------------------------

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_customers.map((c) => c.toJson()).toList());
    await prefs.setString(_prefsCustomersKey, raw);

    // Instant background sync to Google Drive
    if (GoogleDriveService.instance.isConnected) {
      GoogleDriveService.instance.syncData(_customers);
    }
  }

  Future<void> _persistTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsThemeKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTheme = prefs.getString(_prefsThemeKey);
    if (savedTheme != null) {
      _themeMode = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;
    }

    final raw = prefs.getString(_prefsCustomersKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _customers
          ..clear()
          ..addAll(decoded.map((e) => Customer.fromJson(e as Map<String, dynamic>)));

        // Safely remove only sample demo/garbage accounts if present
        final initialLength = _customers.length;
        _customers.removeWhere((c) {
          final isBlank = c.name.trim().isEmpty;
          final isDemoAnsh = c.name.trim() == 'Ansh Nagre' && c.phone.trim() == '98765 00000';
          final isDemoPriya = c.name.trim() == 'Priya Deshmukh' && c.phone.trim() == '99887 12233';
          final isDemoRamesh = c.name.trim() == 'Ramesh Verma' && c.phone.trim() == '98221 44556';
          return isBlank || isDemoAnsh || isDemoPriya || isDemoRamesh;
        });

        if (_customers.length != initialLength) {
          _persist();
        }
      } catch (_) {
        // Leave existing list empty on corrupted storage
      }
    }

    // Initialize Google Drive service & background image compression
    GoogleDriveService.instance.init();
    ImageOptimizer.optimizeAllCustomerImages(_customers);

    notifyListeners();
  }

  void _seedDemoData() {
    // Keep empty so no fake placeholder data is inserted
  }
}
