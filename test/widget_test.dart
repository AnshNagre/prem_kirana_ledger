import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:prem_kirana_ledger/models/customer.dart';
import 'package:prem_kirana_ledger/models/transaction.dart';
import 'package:prem_kirana_ledger/state/ledger_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Customer and Transaction JSON serialization round-trip retains 100% data integrity', () {
    final now = DateTime.now();
    final customer = Customer(
      id: 'cust-1234',
      accountNumber: 'PK-105',
      name: 'Ramesh Patel',
      phone: '9876543210',
      category: CustomerCategory.dailyCustomer,
      whatsappEnabled: true,
      transactions: [
        LedgerTransaction(
          id: 'txn-1',
          type: TxnType.udhar,
          amount: 500.0,
          timestamp: now,
          balAfter: 500.0,
          desc: 'Monthly spices and grains',
        ),
        LedgerTransaction(
          id: 'txn-2',
          type: TxnType.jama,
          amount: 200.0,
          timestamp: now.add(const Duration(hours: 2)),
          balAfter: 300.0,
          mode: PaymentMode.cash,
          desc: 'Cash payment',
        ),
      ],
    );

    final json = customer.toJson();
    final jsonString = jsonEncode(json);
    final decodedJson = jsonDecode(jsonString) as Map<String, dynamic>;
    final restoredCustomer = Customer.fromJson(decodedJson);

    expect(restoredCustomer.id, equals('cust-1234'));
    expect(restoredCustomer.accountNumber, equals('PK-105'));
    expect(restoredCustomer.name, equals('Ramesh Patel'));
    expect(restoredCustomer.phone, equals('9876543210'));
    expect(restoredCustomer.category, equals(CustomerCategory.dailyCustomer));
    expect(restoredCustomer.whatsappEnabled, isTrue);
    expect(restoredCustomer.transactions.length, equals(2));
    expect(restoredCustomer.balance, equals(300.0));
    expect(restoredCustomer.totalUdharGiven, equals(500.0));
    expect(restoredCustomer.transactions[1].mode, equals(PaymentMode.cash));
  });

  test('LedgerProvider restoreFromBackup updates in-memory and persisted state', () async {
    final provider = LedgerProvider();

    final testCustomer = Customer(
      id: 'cust-999',
      accountNumber: 'PK-999',
      name: 'Backup Test User',
      phone: '9999988888',
      category: CustomerCategory.oldCustomer,
    );

    provider.restoreFromBackup([testCustomer]);

    expect(provider.customers.length, equals(1));
    expect(provider.customers.first.name, equals('Backup Test User'));
    expect(provider.customers.first.accountNumber, equals('PK-999'));
  });
  test('Search relevance scoring ranks exact match before partial prefix', () {
    final provider = LedgerProvider();
    final c1 = Customer(id: '1', accountNumber: 'PK-1', name: 'Shalu Naade', phone: '111');
    final c2 = Customer(id: '2', accountNumber: 'PK-2', name: 'Nagre', phone: '222');
    final c3 = Customer(id: '3', accountNumber: 'PK-3', name: 'Ansh Nagre', phone: '333');

    provider.restoreFromBackup([c1, c2, c3]);

    provider.setSearchQuery('Nagre');
    final visible = provider.visibleCustomers;

    expect(visible.first.name, equals('Nagre'));
    expect(visible[1].name, equals('Ansh Nagre'));
  });

  test('Transaction editing and deletion recalculates running balances correctly', () {
    final provider = LedgerProvider();
    final customer = Customer(id: '1', accountNumber: '', name: 'Test Customer', phone: '12345');
    provider.restoreFromBackup([customer]);

    provider.addTransaction(customer, type: TxnType.udhar, amount: 1000, desc: 'Initial');
    provider.addTransaction(customer, type: TxnType.jama, amount: 400, desc: 'Payment');

    expect(customer.balance, equals(600.0));

    final txnToEdit = customer.transactions.first;
    provider.editTransaction(
      customer: customer,
      transactionId: txnToEdit.id,
      amount: 1500.0,
      desc: 'Updated Udhar',
    );

    expect(customer.balance, equals(1100.0));
    expect(customer.transactions.first.balAfter, equals(1500.0));
    expect(customer.transactions.last.balAfter, equals(1100.0));

    provider.deleteSingleTransaction(customer, customer.transactions.last);
    expect(customer.transactions.length, equals(1));
    expect(customer.balance, equals(1500.0));
  });

  test('Bulk draft persistence saves and restores draft entries', () {
    final provider = LedgerProvider();
    expect(provider.bulkDraftEntries.isEmpty, isTrue);

    final draft = BulkTxnDraftEntry(
      customerName: 'Draft Customer',
      type: TxnType.udhar,
      amount: 250,
      date: DateTime.now(),
    );

    provider.setBulkDraftEntries([draft]);
    expect(provider.bulkDraftEntries.length, equals(1));
    expect(provider.bulkDraftEntries.first.customerName, equals('Draft Customer'));

    provider.clearBulkDraftEntries();
    expect(provider.bulkDraftEntries.isEmpty, isTrue);
  });

  test('Customer categories (New, Old, Daily) and account numbers are preserved and not reset to Daily on restore', () async {
    final cNew = Customer(
      id: 'c1',
      accountNumber: 'PK-101',
      name: 'New Buyer',
      phone: '9111122222',
      category: CustomerCategory.newCustomer,
    );
    final cOld = Customer(
      id: 'c2',
      accountNumber: 'PK-102',
      name: 'Old Regular',
      phone: '9333344444',
      category: CustomerCategory.oldCustomer,
    );
    final cDaily = Customer(
      id: 'c3',
      accountNumber: 'PK-103',
      name: 'Daily Milk',
      phone: '9555566666',
      category: CustomerCategory.dailyCustomer,
    );

    // Save them to shared_preferences JSON
    final jsonList = jsonEncode([cNew.toJson(), cOld.toJson(), cDaily.toJson()]);
    SharedPreferences.setMockInitialValues({'pk_customers_v1': jsonList});

    final provider = LedgerProvider();
    // Allow asynchronous _restore to complete
    await Future.delayed(const Duration(milliseconds: 50));

    expect(provider.customers.length, equals(3));
    final restoredNew = provider.customers.firstWhere((c) => c.name == 'New Buyer');
    final restoredOld = provider.customers.firstWhere((c) => c.name == 'Old Regular');
    final restoredDaily = provider.customers.firstWhere((c) => c.name == 'Daily Milk');

    expect(restoredNew.category, equals(CustomerCategory.newCustomer));
    expect(restoredNew.accountNumber, equals('PK-101'));

    expect(restoredOld.category, equals(CustomerCategory.oldCustomer));
    expect(restoredOld.accountNumber, equals('PK-102'));

    expect(restoredDaily.category, equals(CustomerCategory.dailyCustomer));
    expect(restoredDaily.accountNumber, equals('PK-103'));
  });

  test('Garbage demo records are automatically purged without removing legitimate old entries', () async {
    final demo1 = Customer(
      id: 'd1',
      accountNumber: 'PK-1',
      name: 'Ansh Nagre',
      phone: '98765 00000',
      category: CustomerCategory.dailyCustomer,
    );
    final realCustomer = Customer(
      id: 'r1',
      accountNumber: 'PK-55',
      name: 'Santosh Sharma',
      phone: '9823011223',
      category: CustomerCategory.oldCustomer,
    );

    final jsonList = jsonEncode([demo1.toJson(), realCustomer.toJson()]);
    SharedPreferences.setMockInitialValues({'pk_customers_v1': jsonList});

    final provider = LedgerProvider();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(provider.customers.length, equals(1));
    expect(provider.customers.first.name, equals('Santosh Sharma'));
    expect(provider.customers.first.category, equals(CustomerCategory.oldCustomer));
  });

  test('Customer accounts are naturally sorted by account number in visibleCustomers', () {
    final provider = LedgerProvider();
    final c10 = Customer(id: '1', accountNumber: 'PK-10', name: 'User 10', phone: '10');
    final c2 = Customer(id: '2', accountNumber: 'PK-2', name: 'User 2', phone: '2');
    final c1 = Customer(id: '3', accountNumber: 'PK-1', name: 'User 1', phone: '1');
    final c100 = Customer(id: '4', accountNumber: 'PK-100', name: 'User 100', phone: '100');

    provider.restoreFromBackup([c10, c2, c1, c100]);

    final visible = provider.visibleCustomers;
    expect(visible.map((c) => c.accountNumber).toList(), equals(['PK-1', 'PK-2', 'PK-10', 'PK-100']));
  });

  test('Dashboard Total Udhar and Today Jama dynamically reflect selected category', () {
    final provider = LedgerProvider();
    final now = DateTime.now();

    final cNew = Customer(
      id: 'n1',
      accountNumber: 'PK-1',
      name: 'New Guy',
      phone: '111',
      category: CustomerCategory.newCustomer,
      transactions: [
        LedgerTransaction(id: 't1', type: TxnType.udhar, amount: 500.0, timestamp: now, balAfter: 500.0),
        LedgerTransaction(id: 't2', type: TxnType.jama, amount: 100.0, timestamp: now, balAfter: 400.0),
      ],
    );

    final cOld = Customer(
      id: 'o1',
      accountNumber: 'PK-2',
      name: 'Old Guy',
      phone: '222',
      category: CustomerCategory.oldCustomer,
      transactions: [
        LedgerTransaction(id: 't3', type: TxnType.udhar, amount: 2000.0, timestamp: now, balAfter: 2000.0),
        LedgerTransaction(id: 't4', type: TxnType.jama, amount: 300.0, timestamp: now, balAfter: 1700.0),
      ],
    );

    provider.restoreFromBackup([cNew, cOld]);

    // 1. Unfiltered (ALL)
    provider.setCategoryFilter(null);
    expect(provider.dashboardTotalUdhar, equals(2100.0)); // 400 + 1700 balance
    expect(provider.dashboardTodayJama, equals(400.0)); // 100 + 300

    // 2. Filter by NEW
    provider.setCategoryFilter(CustomerCategory.newCustomer);
    expect(provider.dashboardTotalUdhar, equals(400.0));
    expect(provider.dashboardTodayJama, equals(100.0));

    // 3. Filter by OLD
    provider.setCategoryFilter(CustomerCategory.oldCustomer);
    expect(provider.dashboardTotalUdhar, equals(1700.0));
    expect(provider.dashboardTodayJama, equals(300.0));

    // 4. Filter by DAILY (empty)
    provider.setCategoryFilter(CustomerCategory.dailyCustomer);
    expect(provider.dashboardTotalUdhar, equals(0.0));
    expect(provider.dashboardTodayJama, equals(0.0));
  });

  test('Jama date selection accurately calculates total jama and filters visible customers', () {
    final provider = LedgerProvider();
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final fiveDaysAgo = today.subtract(const Duration(days: 5));

    final cust1 = Customer(
      id: 'c1',
      accountNumber: 'PK-1',
      name: 'Today Buyer',
      phone: '111',
      transactions: [
        LedgerTransaction(id: 't1', type: TxnType.jama, amount: 500.0, timestamp: today, balAfter: 0),
      ],
    );

    final cust2 = Customer(
      id: 'c2',
      accountNumber: 'PK-2',
      name: 'Yesterday Buyer',
      phone: '222',
      transactions: [
        LedgerTransaction(id: 't2', type: TxnType.jama, amount: 350.0, timestamp: yesterday, balAfter: 0),
      ],
    );

    final cust3 = Customer(
      id: 'c3',
      accountNumber: 'PK-3',
      name: 'Past Buyer',
      phone: '333',
      transactions: [
        LedgerTransaction(id: 't3', type: TxnType.jama, amount: 900.0, timestamp: fiveDaysAgo, balAfter: 0),
      ],
    );

    provider.restoreFromBackup([cust1, cust2, cust3]);

    // 1. By default: Today
    provider.setSelectedJamaDate(today);
    expect(provider.isSelectedJamaDateToday, isTrue);
    expect(provider.dashboardSelectedJama, equals(500.0));

    // When Jama filter is toggled for today
    provider.toggleFilter(HomeFilter.jamaToday);
    expect(provider.visibleCustomers.length, equals(1));
    expect(provider.visibleCustomers.first.name, equals('Today Buyer'));

    // 2. Select Yesterday
    provider.setSelectedJamaDate(yesterday);
    expect(provider.isSelectedJamaDateYesterday, isTrue);
    expect(provider.dashboardSelectedJama, equals(350.0));
    expect(provider.visibleCustomers.length, equals(1));
    expect(provider.visibleCustomers.first.name, equals('Yesterday Buyer'));

    // 3. Select Custom Past Date
    provider.setSelectedJamaDate(fiveDaysAgo);
    expect(provider.isSelectedJamaDateToday, isFalse);
    expect(provider.isSelectedJamaDateYesterday, isFalse);
    expect(provider.dashboardSelectedJama, equals(900.0));
    expect(provider.visibleCustomers.length, equals(1));
    expect(provider.visibleCustomers.first.name, equals('Past Buyer'));
  });

  test('Hindi transliteration converts customer names accurately and respects Hindi mode', () {
    final c1 = Customer(id: '1', name: 'Ramesh Patel', phone: '123');
    final c2 = Customer(id: '2', name: 'Ansh Nagre', phone: '456');

    expect(c1.displayName(isHindi: false), equals('Ramesh Patel'));
    expect(c1.displayName(isHindi: true), contains('रमेश'));
    expect(c2.displayName(isHindi: true), contains('अंश'));

    // TxnType labels
    expect(TxnType.udhar.displayLabel(isHindi: false), equals('UDHAR'));
    expect(TxnType.udhar.displayLabel(isHindi: true), equals('उधार'));
    expect(TxnType.jama.displayLabel(isHindi: false), equals('JAMA'));
    expect(TxnType.jama.displayLabel(isHindi: true), equals('जमा'));
  });

  test('hasExistingTransaction correctly detects duplicate entries on the same date', () {
    final provider = LedgerProvider();
    final today = DateTime.now();
    final customer = Customer(id: '1', name: 'Suresh Kumar', phone: '999');
    provider.restoreFromBackup([customer]);

    provider.addTransaction(
      customer,
      type: TxnType.udhar,
      amount: 450.0,
      timestamp: today,
    );

    // Identical entry on same day: duplicate
    final isDup = provider.hasExistingTransaction(
      customerName: 'Suresh Kumar',
      date: today,
      amount: 450.0,
      type: TxnType.udhar,
    );
    expect(isDup, isTrue);

    // Different amount on same day: not duplicate
    final diffAmt = provider.hasExistingTransaction(
      customerName: 'Suresh Kumar',
      date: today,
      amount: 500.0,
      type: TxnType.udhar,
    );
    expect(diffAmt, isFalse);

    // Different date: not duplicate
    final diffDate = provider.hasExistingTransaction(
      customerName: 'Suresh Kumar',
      date: today.subtract(const Duration(days: 2)),
      amount: 450.0,
      type: TxnType.udhar,
    );
    expect(diffDate, isFalse);
  });

  test('autocompleteByName in bulk transaction entry prioritizes prefix and exact matches at the top', () {
    final provider = LedgerProvider();
    final c1 = Customer(id: '1', accountNumber: 'PK-10', name: 'Kamal Kishore', phone: '111');
    final c2 = Customer(id: '2', accountNumber: 'PK-2', name: 'Ramesh Patel', phone: '222');
    final c3 = Customer(id: '3', accountNumber: 'PK-30', name: 'Kamesh Gupta', phone: '333');

    provider.restoreFromBackup([c1, c2, c3]);

    final results = provider.autocompleteByName('Ramesh');
    expect(results.isNotEmpty, isTrue);
    expect(results.first.name, equals('Ramesh Patel'));
  });
}
