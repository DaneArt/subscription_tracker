import '../models/models.dart';
import 'package:html/parser.dart' as html_parser;

/// Data class for passing to isolate
class EmailParseRequest {
  final List<EmailDataSimple> emails;
  final int batchIndex;

  const EmailParseRequest({
    required this.emails,
    required this.batchIndex,
  });
}

/// Simplified email data for isolate (no complex objects)
class EmailDataSimple {
  final String id;
  final String? from;
  final String? subject;
  final String? body;
  final String? dateIso;
  final String? snippet;

  const EmailDataSimple({
    required this.id,
    this.from,
    this.subject,
    this.body,
    this.dateIso,
    this.snippet,
  });

  DateTime? get date => dateIso != null ? DateTime.tryParse(dateIso!) : null;
}

/// Result from isolate parsing
class ParsedEmailResult {
  final String serviceName;
  final double? amount;
  final String? currency;
  final String? billingDateIso;
  final String? lastPaymentDateIso;
  final String billingPeriod;
  final String category;
  final bool isCancelled;
  final String emailId;
  final String? emailSubject;
  final String? emailExcerpt;

  const ParsedEmailResult({
    required this.serviceName,
    this.amount,
    this.currency,
    this.billingDateIso,
    this.lastPaymentDateIso,
    this.billingPeriod = 'monthly',
    this.category = 'other',
    this.isCancelled = false,
    required this.emailId,
    this.emailSubject,
    this.emailExcerpt,
  });

  Subscription toSubscription() {
    final now = DateTime.now();
    return Subscription(
      serviceName: serviceName,
      amount: amount ?? 0,
      currency: currency ?? 'RUB',
      nextBillingDate: billingDateIso != null ? DateTime.tryParse(billingDateIso!) : null,
      lastPaymentDate: lastPaymentDateIso != null ? DateTime.tryParse(lastPaymentDateIso!) : null,
      billingPeriod: BillingPeriod.values.firstWhere(
        (e) => e.name == billingPeriod,
        orElse: () => BillingPeriod.monthly,
      ),
      status: isCancelled ? SubscriptionStatus.cancelled : SubscriptionStatus.active,
      category: SubscriptionCategory.values.firstWhere(
        (e) => e.name == category,
        orElse: () => SubscriptionCategory.other,
      ),
      emailId: emailId,
      emailSubject: emailSubject,
      emailExcerpt: emailExcerpt,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// Top-level function for compute() - parses a batch of emails
List<ParsedEmailResult> parseEmailBatch(EmailParseRequest request) {
  final results = <ParsedEmailResult>[];

  for (final email in request.emails) {
    final result = _parseEmailInIsolate(email);
    if (result != null) {
      results.add(result);
    }
  }

  return results;
}

// ============================================================================
// Isolate-safe parsing logic (copy of EmailParserService logic)
// ============================================================================

const _billingKeywords = [
  'receipt', 'invoice', 'payment', 'billing', 'charged', 'subscription',
  'чек', 'оплата', 'счет', 'списан', 'подписка', 'квитанция',
  'your receipt', 'payment received', 'payment confirmation',
  'cancelled', 'canceled', 'отменен', 'отмена', 'cancellation',
];

const _promoKeywords = [
  'recommend', 'watch now', 'new on', 'coming soon', 'don\'t miss',
  'рекомендации', 'смотрите', 'новинки', 'скоро выйдет', 'не пропустите',
  'посмотрите', 'выходит', 'напоминание', 'reminder',
];

const _cancellationKeywords = [
  'cancelled', 'canceled', 'cancellation', 'has been cancelled',
  'subscription cancelled', 'subscription canceled',
  'отменена', 'отменен', 'отмена подписки', 'подписка отменена',
  'вы отменили', 'успешно отменена', 'прекращена',
  'is expiring', 'will expire', 'expires on', 'will end',
  'истекает', 'закончится', 'завершится',
];

ParsedEmailResult? _parseEmailInIsolate(EmailDataSimple email) {
  if (!_isBillingEmail(email)) {
    return null;
  }

  if (_isAppleReceipt(email)) {
    return _parseAppleReceipt(email);
  }

  final knownService = _identifyService(email);
  if (knownService == null) {
    return null;
  }

  final textContent = _extractTextContent(email);
  final amountResult = _extractAmount(textContent, knownService);
  final billingDate = _extractBillingDate(textContent);
  final billingPeriod = _extractBillingPeriod(textContent);
  final emailExcerpt = _extractPaymentExcerpt(textContent, amountResult);
  final isCancelled = _isCancelledSubscription(textContent, email.subject ?? '');

  return ParsedEmailResult(
    serviceName: knownService.name,
    amount: amountResult?.$1,
    currency: amountResult?.$2,
    billingDateIso: billingDate?.toIso8601String(),
    lastPaymentDateIso: email.date?.toIso8601String(),
    billingPeriod: billingPeriod.name,
    category: knownService.category.name,
    isCancelled: isCancelled,
    emailId: email.id,
    emailSubject: email.subject,
    emailExcerpt: emailExcerpt,
  );
}

bool _isBillingEmail(EmailDataSimple email) {
  final subject = (email.subject ?? '').toLowerCase();
  final snippet = (email.snippet ?? '').toLowerCase();
  final combined = '$subject $snippet';

  for (final keyword in _billingKeywords) {
    if (combined.contains(keyword.toLowerCase())) {
      return true;
    }
  }

  for (final keyword in _promoKeywords) {
    if (subject.contains(keyword.toLowerCase())) {
      return false;
    }
  }

  return false;
}

bool _isCancelledSubscription(String text, String subject) {
  final combined = '$subject $text'.toLowerCase();
  for (final keyword in _cancellationKeywords) {
    if (combined.contains(keyword.toLowerCase())) {
      return true;
    }
  }
  return false;
}

bool _isAppleReceipt(EmailDataSimple email) {
  final from = (email.from ?? '').toLowerCase();
  final subject = (email.subject ?? '').toLowerCase();
  return from.contains('apple.com') &&
      (subject.contains('receipt') ||
          subject.contains('invoice') ||
          subject.contains('subscription is confirmed') ||
          subject.contains('subscription is expiring'));
}

ParsedEmailResult? _parseAppleReceipt(EmailDataSimple email) {
  final textContent = _extractTextContent(email);
  final textLower = textContent.toLowerCase();

  String serviceName = 'Apple Purchase';
  String category = 'software';

  if (textLower.contains('chatgpt')) {
    serviceName = 'ChatGPT Plus';
    category = 'software';
  } else if (textLower.contains('icloud')) {
    serviceName = 'iCloud+';
    category = 'cloud';
  } else if (textLower.contains('apple music')) {
    serviceName = 'Apple Music';
    category = 'streaming';
  } else if (textLower.contains('apple one')) {
    serviceName = 'Apple One';
    category = 'streaming';
  } else if (textLower.contains('apple tv')) {
    serviceName = 'Apple TV+';
    category = 'streaming';
  } else if (textLower.contains('bevel')) {
    serviceName = 'Bevel';
    category = 'fitness';
  } else if (textLower.contains('duolingo')) {
    serviceName = 'Duolingo';
    category = 'education';
  } else if (textLower.contains('spotify')) {
    serviceName = 'Spotify';
    category = 'streaming';
  }

  final amountMatch = RegExp(r'(\d+[.,]\d{2})\s*([€$₽£])').firstMatch(textContent);
  double? amount;
  String currency = 'EUR';

  if (amountMatch != null) {
    amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '.'));
    final symbol = amountMatch.group(2)!;
    currency = symbol == '€' ? 'EUR' : symbol == '\$' ? 'USD' : symbol == '₽' ? 'RUB' : symbol == '£' ? 'GBP' : 'EUR';
  }

  final billingDate = _extractBillingDate(textContent);
  final billingPeriod = _extractBillingPeriod(textContent);
  final isCancelled = _isCancelledSubscription(textContent, email.subject ?? '');

  final excerptMatch = RegExp(
    r'([A-Za-zА-Яа-я0-9\s\-:]+(?:Monthly|Yearly|месяц|год)[^\n]*\d+[.,]\d{2}\s*[€$₽£])',
    caseSensitive: false,
  ).firstMatch(textContent);

  return ParsedEmailResult(
    serviceName: serviceName,
    amount: amount,
    currency: currency,
    billingDateIso: billingDate?.toIso8601String(),
    lastPaymentDateIso: email.date?.toIso8601String(),
    billingPeriod: billingPeriod.name,
    category: category,
    isCancelled: isCancelled,
    emailId: email.id,
    emailSubject: email.subject,
    emailExcerpt: excerptMatch?.group(0)?.trim(),
  );
}

KnownService? _identifyService(EmailDataSimple email) {
  final fromLower = (email.from ?? '').toLowerCase();
  final subjectLower = (email.subject ?? '').toLowerCase();
  final snippetLower = (email.snippet ?? '').toLowerCase();

  // Exclude Yandex Market
  if (fromLower.contains('market.yandex') ||
      fromLower.contains('яндекс маркет') ||
      subjectLower.contains('маркет') ||
      subjectLower.contains('market')) {
    return null;
  }

  for (final service in knownServices) {
    for (final pattern in service.emailPatterns) {
      if (fromLower.contains(pattern.toLowerCase())) {
        return service;
      }
    }

    for (final pattern in service.subjectPatterns) {
      if (subjectLower.contains(pattern.toLowerCase()) ||
          snippetLower.contains(pattern.toLowerCase())) {
        return service;
      }
    }
  }

  return null;
}

String _extractTextContent(EmailDataSimple email) {
  final parts = [
    email.subject ?? '',
    email.snippet ?? '',
    _stripHtml(email.body ?? ''),
  ];
  return parts.join(' ');
}

String _stripHtml(String html) {
  try {
    final document = html_parser.parse(html);
    return document.body?.text ?? html;
  } catch (_) {
    return html.replaceAll(RegExp(r'<[^>]*>'), ' ');
  }
}

(double, String)? _extractAmount(String text, KnownService service) {
  // Simplified amount extraction for isolate
  final patterns = [
    (RegExp(r'(\d+[.,]?\d*)\s*([₽$€]|руб|usd|eur)', caseSensitive: false), true),
    (RegExp(r'([₽$€])\s*(\d+[.,]?\d*)'), false),
  ];

  for (final (pattern, amountFirst) in patterns) {
    for (final match in pattern.allMatches(text)) {
      double? amount;
      String currency = 'RUB';

      if (amountFirst) {
        amount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        final currStr = match.group(2)!.toLowerCase();
        if (currStr.contains('₽') || currStr.contains('руб')) {
          currency = 'RUB';
        } else if (currStr.contains('\$') || currStr.contains('usd')) {
          currency = 'USD';
        } else if (currStr.contains('€') || currStr.contains('eur')) {
          currency = 'EUR';
        }
      } else {
        final symbol = match.group(1)!;
        amount = double.tryParse(match.group(2)!.replaceAll(',', '.'));
        currency = symbol == '₽' ? 'RUB' : symbol == '\$' ? 'USD' : symbol == '€' ? 'EUR' : 'RUB';
      }

      if (amount != null && amount > 0 && amount < 50000) {
        if (service.isTypicalAmount(amount, currency)) {
          return (amount, currency);
        }
      }
    }
  }

  // Fallback: find any reasonable amount
  for (final (pattern, amountFirst) in patterns) {
    for (final match in pattern.allMatches(text)) {
      double? amount;
      String currency = 'RUB';

      if (amountFirst) {
        amount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        final currStr = match.group(2)!.toLowerCase();
        if (currStr.contains('₽') || currStr.contains('руб')) {
          currency = 'RUB';
        } else if (currStr.contains('\$') || currStr.contains('usd')) {
          currency = 'USD';
        } else if (currStr.contains('€') || currStr.contains('eur')) {
          currency = 'EUR';
        }
      } else {
        final symbol = match.group(1)!;
        amount = double.tryParse(match.group(2)!.replaceAll(',', '.'));
        currency = symbol == '₽' ? 'RUB' : symbol == '\$' ? 'USD' : symbol == '€' ? 'EUR' : 'RUB';
      }

      if (amount != null && amount > 0 && amount < 50000) {
        return (amount, currency);
      }
    }
  }

  return null;
}

DateTime? _extractBillingDate(String text) {
  // ISO format
  var match = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(text);
  if (match != null) {
    final date = DateTime.tryParse(match.group(1)!);
    if (date != null && _isReasonableDate(date)) {
      return date;
    }
  }

  // DD.MM.YYYY
  match = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(text);
  if (match != null) {
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day != null && month != null && year != null) {
      try {
        final date = DateTime(year, month, day);
        if (_isReasonableDate(date)) {
          return date;
        }
      } catch (_) {}
    }
  }

  return null;
}

bool _isReasonableDate(DateTime date) {
  final now = DateTime.now();
  final twoYearsAgo = now.subtract(const Duration(days: 730));
  final twoYearsAhead = now.add(const Duration(days: 730));
  return date.isAfter(twoYearsAgo) && date.isBefore(twoYearsAhead);
}

BillingPeriod _extractBillingPeriod(String text) {
  final textLower = text.toLowerCase();

  final yearlyPatterns = ['ежегодн', 'yearly', 'annual', '/год', '/year', 'per year', 'в год'];
  for (final pattern in yearlyPatterns) {
    if (textLower.contains(pattern)) {
      return BillingPeriod.yearly;
    }
  }

  final weeklyPatterns = ['еженедельн', 'weekly', '/неделю', '/week', 'per week', 'в неделю'];
  for (final pattern in weeklyPatterns) {
    if (textLower.contains(pattern)) {
      return BillingPeriod.weekly;
    }
  }

  return BillingPeriod.monthly;
}

String? _extractPaymentExcerpt(String text, (double, String)? amount) {
  if (amount == null) return null;

  final paymentKeywords = [
    'оплата', 'списан', 'charge', 'payment', 'подписка', 'subscription',
    'итого', 'total', 'сумма', 'amount', 'тариф', 'план', 'plan',
  ];

  final sentences = text.split(RegExp(r'[.!?\n]+'));

  for (final sentence in sentences) {
    final sentenceLower = sentence.toLowerCase();
    final containsAmount = sentence.contains(amount.$1.toString()) ||
        sentence.contains(amount.$1.toInt().toString()) ||
        sentence.contains('₽') ||
        sentence.contains('\$') ||
        sentence.contains('€');

    if (containsAmount) {
      for (final keyword in paymentKeywords) {
        if (sentenceLower.contains(keyword)) {
          final trimmed = sentence.trim();
          if (trimmed.length > 10 && trimmed.length < 300) {
            return trimmed;
          }
        }
      }
    }
  }

  return null;
}
