import 'package:equatable/equatable.dart';

class BankTransaction extends Equatable {
  final int? id;
  final String cardNumber;
  final DateTime date;
  final double amount;
  final String currency;
  final double? balanceAfter;
  final String? balanceCurrency;
  final String merchant;
  final String? rawSms;
  final DateTime createdAt;

  const BankTransaction({
    this.id,
    required this.cardNumber,
    required this.date,
    required this.amount,
    required this.currency,
    this.balanceAfter,
    this.balanceCurrency,
    required this.merchant,
    this.rawSms,
    required this.createdAt,
  });

  BankTransaction copyWith({
    int? id,
    String? cardNumber,
    DateTime? date,
    double? amount,
    String? currency,
    double? balanceAfter,
    String? balanceCurrency,
    String? merchant,
    String? rawSms,
    DateTime? createdAt,
  }) {
    return BankTransaction(
      id: id ?? this.id,
      cardNumber: cardNumber ?? this.cardNumber,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      balanceCurrency: balanceCurrency ?? this.balanceCurrency,
      merchant: merchant ?? this.merchant,
      rawSms: rawSms ?? this.rawSms,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cardNumber': cardNumber,
      'date': date.toIso8601String(),
      'amount': amount,
      'currency': currency,
      'balanceAfter': balanceAfter,
      'balanceCurrency': balanceCurrency,
      'merchant': merchant,
      'rawSms': rawSms,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BankTransaction.fromMap(Map<String, dynamic> map) {
    return BankTransaction(
      id: map['id'] as int?,
      cardNumber: map['cardNumber'] as String,
      date: DateTime.parse(map['date'] as String),
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String,
      balanceAfter: map['balanceAfter'] != null
          ? (map['balanceAfter'] as num).toDouble()
          : null,
      balanceCurrency: map['balanceCurrency'] as String?,
      merchant: map['merchant'] as String,
      rawSms: map['rawSms'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// Normalized merchant name for grouping (uppercase, trimmed)
  String get normalizedMerchant => merchant.toUpperCase().trim();

  @override
  List<Object?> get props => [
        id,
        cardNumber,
        date,
        amount,
        currency,
        balanceAfter,
        balanceCurrency,
        merchant,
        rawSms,
        createdAt,
      ];
}

/// Detected subscription from recurring transactions
class DetectedSubscription extends Equatable {
  final String merchant;
  final double amount;
  final String currency;
  final int occurrences;
  final DateTime lastDate;
  final DateTime? firstDate;
  final Duration? averageInterval;

  const DetectedSubscription({
    required this.merchant,
    required this.amount,
    required this.currency,
    required this.occurrences,
    required this.lastDate,
    this.firstDate,
    this.averageInterval,
  });

  /// Estimated billing period based on average interval
  String get estimatedPeriod {
    if (averageInterval == null) return 'unknown';
    final days = averageInterval!.inDays;
    if (days >= 25 && days <= 35) return 'monthly';
    if (days >= 6 && days <= 8) return 'weekly';
    if (days >= 355 && days <= 375) return 'yearly';
    return 'unknown';
  }

  @override
  List<Object?> get props => [
        merchant,
        amount,
        currency,
        occurrences,
        lastDate,
        firstDate,
        averageInterval,
      ];
}
