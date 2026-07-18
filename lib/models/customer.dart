import 'transaction.dart';

class Customer {
  final String id;
  String name;
  String phone;
  bool whatsappEnabled;
  String? photoPath;
  final List<LedgerTransaction> transactions;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.whatsappEnabled = false,
    this.photoPath,
    List<LedgerTransaction>? transactions,
  }) : transactions = transactions ?? [];

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

  /// Sum of JAMA (credit) entries posted today.
  double get todayJama {
    final now = DateTime.now();
    return transactions
        .where((t) =>
            t.type == TxnType.jama &&
            t.timestamp.year == now.year &&
            t.timestamp.month == now.month &&
            t.timestamp.day == now.day)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  DateTime? get lastActivity =>
      transactions.isEmpty ? null : transactions.last.timestamp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'whatsappEnabled': whatsappEnabled,
        'photoPath': photoPath,
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      whatsappEnabled: json['whatsappEnabled'] as bool? ?? false,
      photoPath: json['photoPath'] as String?,
      transactions: (json['transactions'] as List<dynamic>? ?? [])
          .map((e) => LedgerTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
