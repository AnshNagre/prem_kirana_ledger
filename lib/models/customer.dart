import '../utils/hindi_transliterator.dart';
import 'transaction.dart';

enum CustomerCategory {
  newCustomer,
  oldCustomer,
  dailyCustomer;

  String get label {
    switch (this) {
      case CustomerCategory.newCustomer:
        return 'New';
      case CustomerCategory.oldCustomer:
        return 'Old';
      case CustomerCategory.dailyCustomer:
        return 'Daily';
    }
  }

  static CustomerCategory fromString(String? val) {
    if (val == null) return CustomerCategory.newCustomer;
    final lower = val.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
    if (lower == 'old' || lower == 'purana' || lower == 'oldcustomer' || lower == 'oldcust') {
      return CustomerCategory.oldCustomer;
    }
    if (lower == 'daily' || lower == 'roz' || lower == 'roj' || lower == 'dailycustomer' || lower == 'regulardaily' || lower == 'dailycust') {
      return CustomerCategory.dailyCustomer;
    }
    return CustomerCategory.newCustomer;
  }
}

class Customer {
  final String id;
  String accountNumber;
  String name;
  String phone;
  CustomerCategory category;
  bool whatsappEnabled;
  String? photoPath;
  final List<LedgerTransaction> transactions;

  Customer({
    required this.id,
    String? accountNumber,
    required this.name,
    required this.phone,
    CustomerCategory? category,
    this.whatsappEnabled = false,
    this.photoPath,
    List<LedgerTransaction>? transactions,
  })  : accountNumber = (accountNumber != null) ? accountNumber.trim() : '',
        category = category ?? CustomerCategory.newCustomer,
        transactions = transactions ?? [];

  /// Returns the customer name in English or Hindi Devanagari based on [isHindi].
  String displayName({bool isHindi = false}) {
    if (!isHindi) return name;
    return HindiTransliterator.toHindi(name);
  }

  /// Two-letter avatar initials, e.g. "Ansh Nagre" -> "AN".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  /// Net outstanding balance = running balance after the latest transaction.
  /// Positive => customer owes the store (udhar), zero/negative => settled.
  double get balance => transactions.isEmpty ? 0 : transactions.last.balAfter;

  /// Sum of every UDHAR (debit) entry ever logged for this account.
  double get totalUdharGiven => transactions
      .where((t) => t.type == TxnType.udhar)
      .fold(0.0, (sum, t) => sum + t.amount);

  /// Sum of JAMA (credit) entries posted on a specific calendar date.
  double jamaOnDate(DateTime date) {
    return transactions
        .where((t) =>
            t.type == TxnType.jama &&
            t.timestamp.year == date.year &&
            t.timestamp.month == date.month &&
            t.timestamp.day == date.day)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Sum of JAMA (credit) entries posted today.
  double get todayJama => jamaOnDate(DateTime.now());

  DateTime? get lastActivity =>
      transactions.isEmpty ? null : transactions.last.timestamp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountNumber': accountNumber,
        'name': name,
        'phone': phone,
        'category': category.name,
        'whatsappEnabled': whatsappEnabled,
        'photoPath': photoPath,
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };

  factory Customer.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final rawAcc = json['accountNumber'] as String? ?? '';

    return Customer(
      id: id,
      accountNumber: rawAcc,
      name: json['name'] as String? ?? 'Unnamed',
      phone: json['phone'] as String? ?? '',
      category: CustomerCategory.fromString(json['category'] as String?),
      whatsappEnabled: json['whatsappEnabled'] as bool? ?? false,
      photoPath: json['photoPath'] as String?,
      transactions: (json['transactions'] as List<dynamic>? ?? [])
          .map((e) => LedgerTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
