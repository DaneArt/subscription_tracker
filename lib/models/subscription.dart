import 'package:equatable/equatable.dart';

enum BillingPeriod {
  monthly,
  yearly,
  weekly,
  unknown;

  String get displayName {
    switch (this) {
      case BillingPeriod.monthly:
        return 'Ежемесячно';
      case BillingPeriod.yearly:
        return 'Ежегодно';
      case BillingPeriod.weekly:
        return 'Еженедельно';
      case BillingPeriod.unknown:
        return 'Неизвестно';
    }
  }
}

enum SubscriptionStatus {
  active,
  cancelled,
  paused,
  unknown;

  String get displayName {
    switch (this) {
      case SubscriptionStatus.active:
        return 'Активна';
      case SubscriptionStatus.cancelled:
        return 'Отменена';
      case SubscriptionStatus.paused:
        return 'Приостановлена';
      case SubscriptionStatus.unknown:
        return 'Неизвестно';
    }
  }
}

enum SubscriptionCategory {
  streaming,
  cloud,
  software,
  vpn,
  fitness,
  education,
  other;

  String get displayName {
    switch (this) {
      case SubscriptionCategory.streaming:
        return 'Стриминг';
      case SubscriptionCategory.cloud:
        return 'Облако';
      case SubscriptionCategory.software:
        return 'Софт';
      case SubscriptionCategory.vpn:
        return 'VPN';
      case SubscriptionCategory.fitness:
        return 'Фитнес';
      case SubscriptionCategory.education:
        return 'Образование';
      case SubscriptionCategory.other:
        return 'Другое';
    }
  }
}

class Subscription extends Equatable {
  final int? id;
  final String serviceName;
  final String? serviceIcon;
  final double amount;
  final String currency;
  final DateTime? nextBillingDate;
  final DateTime? lastPaymentDate;
  final BillingPeriod billingPeriod;
  final SubscriptionStatus status;
  final SubscriptionCategory category;
  final String? emailId;
  final String? emailSubject;
  final String? emailExcerpt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Subscription({
    this.id,
    required this.serviceName,
    this.serviceIcon,
    required this.amount,
    this.currency = 'RUB',
    this.nextBillingDate,
    this.lastPaymentDate,
    this.billingPeriod = BillingPeriod.monthly,
    this.status = SubscriptionStatus.active,
    this.category = SubscriptionCategory.other,
    this.emailId,
    this.emailSubject,
    this.emailExcerpt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Subscription copyWith({
    int? id,
    String? serviceName,
    String? serviceIcon,
    double? amount,
    String? currency,
    DateTime? nextBillingDate,
    DateTime? lastPaymentDate,
    BillingPeriod? billingPeriod,
    SubscriptionStatus? status,
    SubscriptionCategory? category,
    String? emailId,
    String? emailSubject,
    String? emailExcerpt,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      serviceName: serviceName ?? this.serviceName,
      serviceIcon: serviceIcon ?? this.serviceIcon,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      billingPeriod: billingPeriod ?? this.billingPeriod,
      status: status ?? this.status,
      category: category ?? this.category,
      emailId: emailId ?? this.emailId,
      emailSubject: emailSubject ?? this.emailSubject,
      emailExcerpt: emailExcerpt ?? this.emailExcerpt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serviceName': serviceName,
      'serviceIcon': serviceIcon,
      'amount': amount,
      'currency': currency,
      'nextBillingDate': nextBillingDate?.toIso8601String(),
      'lastPaymentDate': lastPaymentDate?.toIso8601String(),
      'billingPeriod': billingPeriod.name,
      'status': status.name,
      'category': category.name,
      'emailId': emailId,
      'emailSubject': emailSubject,
      'emailExcerpt': emailExcerpt,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'] as int?,
      serviceName: map['serviceName'] as String,
      serviceIcon: map['serviceIcon'] as String?,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'RUB',
      nextBillingDate: map['nextBillingDate'] != null
          ? DateTime.parse(map['nextBillingDate'] as String)
          : null,
      lastPaymentDate: map['lastPaymentDate'] != null
          ? DateTime.parse(map['lastPaymentDate'] as String)
          : null,
      billingPeriod: BillingPeriod.values.firstWhere(
        (e) => e.name == map['billingPeriod'],
        orElse: () => BillingPeriod.unknown,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SubscriptionStatus.unknown,
      ),
      category: SubscriptionCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => SubscriptionCategory.other,
      ),
      emailId: map['emailId'] as String?,
      emailSubject: map['emailSubject'] as String?,
      emailExcerpt: map['emailExcerpt'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String get formattedAmount {
    final symbol = switch (currency) {
      'RUB' => '₽',
      'USD' => '\$',
      'EUR' => '€',
      _ => currency,
    };
    return '${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)} $symbol';
  }

  @override
  List<Object?> get props => [
        id,
        serviceName,
        serviceIcon,
        amount,
        currency,
        nextBillingDate,
        lastPaymentDate,
        billingPeriod,
        status,
        category,
        emailId,
        emailSubject,
        emailExcerpt,
        notes,
        createdAt,
        updatedAt,
      ];
}
