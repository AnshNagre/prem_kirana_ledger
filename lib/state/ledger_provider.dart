import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/customer.dart';
import '../models/transaction.dart';
import '../utils/formatters.dart';

enum HomeFilter { none, udharOnly, jamaToday }

class LedgerProvider extends ChangeNotifier {
  static const _prefsCustomersKey = 'pk_customers_v1';
  static const _prefsThemeKey = 'pk_theme_v1';

  final _uuid = const Uuid();
  final List<Customer> _customers = [];
  ThemeMode _themeMode = ThemeMode.dark;
  HomeFilter _filter = HomeFilter.none;
  String _searchQuery = '';

  List<Customer> get customers => List.unmodifiable(_customers);
  ThemeMode get themeMode => _themeMode;
  HomeFilter get filter => _filter;
  String get searchQuery => _searchQuery;

  LedgerProvider() {
    _restore();
  }

  // ---------------------------------------------------------------------
  // Derived dashboard totals
  // ---------------------------------------------------------------------

  double get dashboardTotalUdhar =>
      _customers.fold(0.0, (sum, c) => sum + (c.balance > 0 ? c.balance : 0));

  double get dashboardTodayJama =>
      _customers.fold(0.0, (sum, c) => sum + c.todayJama);

  /// Customers filtered by the active dashboard filter chip + search box.
  List<Customer> get visibleCustomers {
    Iterable<Customer> list = _customers;

    switch (_filter) {
      case HomeFilter.udharOnly:
        list = list.where((c) => c.balance > 0);
        break;
      case HomeFilter.jamaToday:
        list = list.where((c) => c.todayJama > 0);
        break;
      case HomeFilter.none:
        break;
    }

    if (_searchQuery.trim().isNotEmpty) {
      list = list.where((c) =>
          isFuzzyMatch(c.name, _searchQuery) || c.phone.contains(_searchQuery.trim()));
    }

    final sorted = list.toList()
      ..sort((a, b) {
        final aTime = a.lastActivity ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastActivity ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
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

  void clearFilter() {
    _filter = HomeFilter.none;
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
    bool whatsappEnabled = false,
    String? photoPath,
  }) {
    final customer = Customer(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone.trim(),
      whatsappEnabled: whatsappEnabled,
      photoPath: photoPath,
    );
    _customers.insert(0, customer);
    _persist();
    notifyListeners();
    return customer;
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

  List<Customer> autocompleteByName(String query) {
    if (query.trim().isEmpty) return [];
    return _customers.where((c) => isFuzzyMatch(c.name, query)).take(6).toList();
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
    final prevBalance = customer.balance;
    final newBalance = type.isUdhar ? prevBalance + amount : prevBalance - amount;

    final txn = LedgerTransaction(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      desc: desc.trim(),
      mode: mode,
      timestamp: timestamp ?? DateTime.now(),
      balAfter: newBalance,
      imagePath: imagePath,
    );

    customer.transactions.add(txn);
    _persist();
    notifyListeners();
    return txn;
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
      } catch (_) {
        _seedDemoData();
      }
    } else {
      _seedDemoData();
    }
    notifyListeners();
  }

  void _seedDemoData() {
    final ansh = addCustomer(name: 'Ansh Nagre', phone: '98765 00000', whatsappEnabled: true);
    addTransaction(ansh, type: TxnType.udhar, amount: 250, desc: 'Tea & Biscuits');
    addTransaction(ansh, type: TxnType.udhar, amount: 480, desc: 'Rice 5kg');
    addTransaction(ansh, type: TxnType.jama, amount: 300, mode: PaymentMode.cash);

    final priya = addCustomer(name: 'Priya Deshmukh', phone: '99887 12233');
    addTransaction(priya, type: TxnType.udhar, amount: 620, desc: 'Grocery basket');
  }
}
