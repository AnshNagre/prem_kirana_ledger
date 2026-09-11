import 'package:intl/intl.dart';

/// Entry type — mirrors the HTML app's two ledger entry kinds.
enum TxnType { udhar, jama }

extension TxnTypeX on TxnType {
  String get label => this == TxnType.udhar ? 'UDHAR' : 'JAMA';
  bool get isUdhar => this == TxnType.udhar;
  String displayLabel({bool isHindi = false}) {
    if (isHindi) {
      return this == TxnType.udhar ? 'उधार' : 'जमा';
    }
    return label;
  }
}

/// Payment mode, only meaningful for JAMA (credit) entries.
enum PaymentMode { cash, online, none }

extension PaymentModeX on PaymentMode {
  String get label {
    switch (this) {
      case PaymentMode.cash:
        return 'Cash';
      case PaymentMode.online:
        return 'Online';
      case PaymentMode.none:
        return '';
    }
  }
}

class LedgerTransaction {
  final String id;
  final TxnType type;
  final double amount;
  final String desc;
  final DateTime timestamp;
  final PaymentMode mode;

  /// Running account balance immediately after this transaction was posted.
  final double balAfter;

  /// Optional attached invoice / proof snapshot.
  final String? imagePath;

  LedgerTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.timestamp,
    required this.balAfter,
    this.desc = '',
    this.mode = PaymentMode.none,
    this.imagePath,
  });

  String get date => DateFormat('dd/MM/yyyy').format(timestamp);
  String get time => DateFormat('hh:mm a').format(timestamp);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'desc': desc,
        'timestamp': timestamp.toIso8601String(),
        'mode': mode.name,
        'balAfter': balAfter,
        'imagePath': imagePath,
      };

  factory LedgerTransaction.fromJson(Map<String, dynamic> json) {
    return LedgerTransaction(
      id: json['id'] as String,
      type: TxnType.values.byName(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      desc: json['desc'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      mode: PaymentMode.values.byName(json['mode'] as String? ?? 'none'),
      balAfter: (json['balAfter'] as num).toDouble(),
      imagePath: json['imagePath'] as String?,
    );
  }
}
