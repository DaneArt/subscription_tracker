import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/models.dart';

class ParsedSubscription {
  final String serviceName;
  final double? amount;
  final String? currency;
  final DateTime? billingDate;
  final DateTime? lastPaymentDate;
  final BillingPeriod billingPeriod;
  final SubscriptionCategory category;
  final bool isCancelled;
  final String emailId;
  final String? emailSubject;
  final String? emailExcerpt;

  const ParsedSubscription({
    required this.serviceName,
    this.amount,
    this.currency,
    this.billingDate,
    this.lastPaymentDate,
    this.billingPeriod = BillingPeriod.unknown,
    this.category = SubscriptionCategory.other,
    this.isCancelled = false,
    required this.emailId,
    this.emailSubject,
    this.emailExcerpt,
  });
}

class AmountCandidate {
  final double amount;
  final String currency;
  final int priority; // Lower is better

  const AmountCandidate({
    required this.amount,
    required this.currency,
    required this.priority,
  });
}

class EmailParserService {
  // Keywords that indicate a billing/payment email
  static const _billingKeywords = [
    'receipt', 'invoice', 'payment', 'billing', 'charged', 'subscription',
    'чек', 'оплата', 'счет', 'списан', 'подписка', 'квитанция',
    'your receipt', 'payment received', 'payment confirmation',
    'cancelled', 'canceled', 'отменен', 'отмена', 'cancellation',
  ];

  // Keywords that indicate promotional/non-billing email
  static const _promoKeywords = [
    'recommend', 'watch now', 'new on', 'coming soon', 'don\'t miss',
    'рекомендации', 'смотрите', 'новинки', 'скоро выйдет', 'не пропустите',
    'посмотрите', 'выходит', 'снова на netflix',
    'новое на netflix', 'лучшие рекомендации', 'готовы увидеть', 'вечером netflix',
    'top picks', 'what to watch', 'trending now', 'because you watched',
    // Subscription management/tracker alert emails (not actual receipts)
    'subscription alert', 'upcoming subscription', 'subscriptions this week',
    'upcoming subscriptions', 'cancel unwanted', 'your concierge',
    // Discount/deal promotional emails
    'deal ends', '% off', 'off annual', 'off premium',
    'special offer', 'limited time',
    'скидка', 'акция', 'специальное предложение',
    // CI/development notification emails (not billing)
    'run failed', 'run succeeded', 'workflow run',
    'build passed', 'build failed',
  ];

  // Keywords that indicate subscription cancellation
  static const _cancellationKeywords = [
    'cancelled', 'canceled', 'cancellation', 'has been cancelled',
    'subscription cancelled', 'subscription canceled',
    'отменена', 'отменен', 'отмена подписки', 'подписка отменена',
    'вы отменили', 'успешно отменена', 'прекращена',
    'has expired', 'expired', 'is expiring', 'will expire', 'expires on', 'will end',
    'истек', 'истекла', 'истекает', 'закончилась', 'закончится', 'завершится',
  ];

  bool _isBillingEmail(EmailData email) {
    final subject = (email.subject ?? '').toLowerCase();
    final snippet = (email.snippet ?? '').toLowerCase();
    final combined = '$subject $snippet';

    // First check if it's clearly a promo email (check subject and snippet)
    for (final keyword in _promoKeywords) {
      if (combined.contains(keyword.toLowerCase())) {
        debugPrint('[EmailParser] Promo email detected: "$keyword"');
        return false;
      }
    }

    // Check for discount patterns: "$X off", "X% off"
    if (RegExp(r'\$\d+\s*off|\d+%\s*off', caseSensitive: false).hasMatch(combined)) {
      debugPrint('[EmailParser] Discount promo email detected');
      return false;
    }

    // Check for billing keywords
    for (final keyword in _billingKeywords) {
      if (combined.contains(keyword.toLowerCase())) {
        return true;
      }
    }

    return false; // Default to not billing if unclear
  }

  bool _isCancelledSubscription(String text, String subject) {
    final combined = '$subject $text'.toLowerCase();

    for (final keyword in _cancellationKeywords) {
      if (combined.contains(keyword.toLowerCase())) {
        debugPrint('[EmailParser] Cancellation detected: "$keyword"');
        return true;
      }
    }
    return false;
  }

  /// Detects forwarded bank SMS transactions (e.g., Raiffeisen Serbia)
  /// Format: Koriscenje kartice ... Iznos: 819,00 RSD ... Mesto: GOOGLE *YouTubePremium
  bool _isBankSmsForward(EmailData email) {
    final text = '${email.subject ?? ''} ${email.snippet ?? ''} ${email.body ?? ''}'.toLowerCase();
    return text.contains('koriscenje kartice') ||
           (text.contains('iznos:') && text.contains('mesto:'));
  }

  /// Extracts text from bank SMS email, replacing HTML block elements with
  /// newlines to preserve field separation (Iznos, Raspolozivo, Mesto, etc.)
  String _extractBankSmsText(EmailData email) {
    final body = email.body ?? '';
    // Replace block-level HTML elements with newlines before stripping tags
    final withNewlines = body
        .replaceAll(RegExp(r'<br\s*/?>|</div>|</p>|</tr>|</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ');
    final parts = [
      email.subject ?? '',
      email.snippet ?? '',
      withNewlines,
    ];
    return parts.join('\n');
  }

  ParsedSubscription? _parseBankSms(EmailData email) {
    debugPrint('[EmailParser] Processing as Bank SMS forward...');
    final textContent = _extractBankSmsText(email);

    debugPrint('[EmailParser] Bank SMS text preview:');
    debugPrint('───────────────────────────────────────────────────────────');
    final preview = textContent.length > 500 ? '${textContent.substring(0, 500)}...' : textContent;
    debugPrint(preview);
    debugPrint('───────────────────────────────────────────────────────────');

    // Extract amount from "Iznos: 1.099,00 RSD" or "Iznos: 819,00 RSD"
    // Serbian number format: . = thousands separator, , = decimal separator
    final amountMatch = RegExp(
      r'iznos:\s*([\d.]+,\d{2})\s*([A-Za-z]{3})\b',
      caseSensitive: false,
    ).firstMatch(textContent);

    double? amount;
    String currency = 'RSD';

    if (amountMatch != null) {
      final amountStr = amountMatch.group(1)!
          .replaceAll('.', '')   // Remove thousands separator
          .replaceAll(',', '.'); // Replace decimal comma with dot
      amount = double.tryParse(amountStr);
      currency = amountMatch.group(2)!.toUpperCase();
      debugPrint('[EmailParser] Bank SMS amount: $amount $currency');
    }

    // Extract date from "Datum: 17.02.2026 15:45:39"
    DateTime? billingDate;
    final dateMatch = RegExp(
      r'datum:\s*(\d{1,2})\.(\d{1,2})\.(\d{4})',
      caseSensitive: false,
    ).firstMatch(textContent);
    if (dateMatch != null) {
      final day = int.tryParse(dateMatch.group(1)!);
      final month = int.tryParse(dateMatch.group(2)!);
      final year = int.tryParse(dateMatch.group(3)!);
      if (day != null && month != null && year != null) {
        try {
          billingDate = DateTime(year, month, day);
        } catch (_) {}
      }
      debugPrint('[EmailParser] Bank SMS date: $billingDate');
    }

    // Extract merchant from "Mesto: GOOGLE *YouTubePremium g.co/HelpPay#US"
    // Use lazy match with boundaries to avoid capturing text from subsequent SMS messages
    final merchantMatch = RegExp(
      r'mesto:\s*(.+?)(?=\s+(?:koriscenje|datum:|iznos:|mesto:)|\s*$)',
      caseSensitive: false,
    ).firstMatch(textContent);
    final merchantRaw = merchantMatch?.group(1)?.trim();

    if (merchantRaw == null) {
      debugPrint('[EmailParser] ❌ No merchant name found in bank SMS');
      debugPrint('═══════════════════════════════════════════════════════════');
      return null;
    }

    debugPrint('[EmailParser] Bank SMS merchant: $merchantRaw');

    // Map merchant to known service
    // Merchant examples: "GOOGLE *YouTubePremium g.co/HelpPay#US", "NETFLIX.COM g.co/HelpPay#NL"
    final merchantNormalized = merchantRaw.toLowerCase().replaceAll(RegExp(r'[\s*._]+'), '');
    KnownService? matchedService;

    for (final service in knownServices) {
      final nameNormalized = service.name.toLowerCase().replaceAll(' ', '');
      if (merchantNormalized.contains(nameNormalized)) {
        matchedService = service;
        break;
      }
      for (final pattern in service.subjectPatterns) {
        final patternNormalized = pattern.toLowerCase().replaceAll(' ', '');
        if (merchantNormalized.contains(patternNormalized)) {
          matchedService = service;
          break;
        }
      }
      if (matchedService != null) break;
    }

    // Use merchant name as fallback if no known service matched
    final serviceName = matchedService?.name ?? _cleanMerchantName(merchantRaw);
    final category = matchedService?.category ?? SubscriptionCategory.other;

    debugPrint('[EmailParser] Bank SMS service: $serviceName (matched: ${matchedService != null})');

    // Detect cancellation from merchant name (e.g., "CANCEL SUBSCRIPTIONS NEW YORK US")
    final isCancelled = merchantRaw.toLowerCase().contains('cancel');

    // Build excerpt from the SMS text
    final excerpt = 'Iznos: ${amountMatch?.group(1) ?? '?'} ${currency}, Mesto: $merchantRaw';

    debugPrint('[EmailParser] RESULT (Bank SMS): $serviceName');
    debugPrint('[EmailParser]   Amount: ${amount ?? "NOT FOUND"} $currency');
    debugPrint('[EmailParser]   Billing date: $billingDate');
    debugPrint('[EmailParser]   Cancelled: $isCancelled');
    debugPrint('[EmailParser]   Excerpt: $excerpt');
    debugPrint('═══════════════════════════════════════════════════════════');

    return ParsedSubscription(
      serviceName: serviceName,
      amount: amount,
      currency: currency,
      billingDate: billingDate,
      lastPaymentDate: billingDate,
      billingPeriod: BillingPeriod.monthly,
      category: category,
      isCancelled: isCancelled,
      emailId: email.id,
      emailSubject: email.subject,
      emailExcerpt: excerpt,
    );
  }

  /// Cleans up raw merchant name for display (e.g., "NETFLIX.COM g.co/HelpPay#NL" → "Netflix")
  String _cleanMerchantName(String raw) {
    // Remove URLs (anything like x.xx/xxx)
    var cleaned = raw.replaceAll(RegExp(r'\s+\S+\.\S+/\S+'), '').trim();
    // Remove trailing domain suffixes
    cleaned = cleaned.replaceAll(RegExp(r'\.(com|net|org|io|tv|ru)$', caseSensitive: false), '').trim();
    // Remove GOOGLE * prefix for Google services
    cleaned = cleaned.replaceAll(RegExp(r'^google\s*\*\s*', caseSensitive: false), '').trim();
    // Title case
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1).toLowerCase();
    }
    return cleaned.isEmpty ? raw : cleaned;
  }

  DateTime? _extractLastPaymentDate(DateTime? emailDate) {
    // Use the email date as the payment date
    // (payment receipts are sent on the payment day)
    return emailDate;
  }

  ParsedSubscription? parseEmail(EmailData email) {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[EmailParser] PARSING EMAIL');
    debugPrint('───────────────────────────────────────────────────────────');
    debugPrint('[EmailParser] Subject: ${email.subject}');
    debugPrint('[EmailParser] From: ${email.from}');
    debugPrint('[EmailParser] Snippet: ${email.snippet}');

    // Check for forwarded bank SMS first (these don't have standard billing keywords)
    if (_isBankSmsForward(email)) {
      debugPrint('[EmailParser] ✓ Bank SMS forward detected');
      return _parseBankSms(email);
    }

    // First check if this is a billing email
    if (!_isBillingEmail(email)) {
      debugPrint('[EmailParser] ❌ Not a billing email - skipping');
      debugPrint('═══════════════════════════════════════════════════════════');
      return null;
    }
    debugPrint('[EmailParser] ✓ Billing email detected');

    // Special handling for Apple receipts - they can be for any app
    if (_isAppleReceipt(email)) {
      return _parseAppleReceipt(email);
    }

    final knownService = _identifyService(email);
    if (knownService == null) {
      debugPrint('[EmailParser] ❌ Unknown service - skipping');
      debugPrint('═══════════════════════════════════════════════════════════');
      return null;
    }

    debugPrint('[EmailParser] ✓ Identified service: ${knownService.name}');
    debugPrint('[EmailParser] Typical prices: ${knownService.typicalPrices}');

    final textContent = _extractTextContent(email);

    // Log first 500 chars of text content for debugging
    final contentPreview = textContent.length > 500
        ? '${textContent.substring(0, 500)}...'
        : textContent;
    debugPrint('[EmailParser] Text content preview:');
    debugPrint('───────────────────────────────────────────────────────────');
    debugPrint(contentPreview);
    debugPrint('───────────────────────────────────────────────────────────');

    final amountResult = _extractAmountSmart(textContent, knownService);
    final billingDate = _extractBillingDate(textContent);
    final billingPeriod = _extractBillingPeriod(textContent);
    final emailExcerpt = _extractPaymentExcerpt(textContent, amountResult);
    final isCancelled = _isCancelledSubscription(textContent, email.subject ?? '');
    final lastPaymentDate = _extractLastPaymentDate(email.date);

    debugPrint('[EmailParser] RESULT: ${knownService.name}');
    debugPrint('[EmailParser]   Amount: ${amountResult?.amount ?? "NOT FOUND"} ${amountResult?.currency ?? ""}');
    debugPrint('[EmailParser]   Billing date: $billingDate');
    debugPrint('[EmailParser]   Last payment: $lastPaymentDate');
    debugPrint('[EmailParser]   Billing period: $billingPeriod');
    debugPrint('[EmailParser]   Cancelled: $isCancelled');
    debugPrint('[EmailParser]   Excerpt: ${emailExcerpt ?? "NOT FOUND"}');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');

    return ParsedSubscription(
      serviceName: knownService.name,
      amount: amountResult?.amount,
      currency: amountResult?.currency,
      billingDate: billingDate,
      lastPaymentDate: lastPaymentDate,
      billingPeriod: billingPeriod,
      category: knownService.category,
      isCancelled: isCancelled,
      emailId: email.id,
      emailSubject: email.subject,
      emailExcerpt: emailExcerpt,
    );
  }

  bool _isAppleReceipt(EmailData email) {
    final from = (email.from ?? '').toLowerCase();
    final subject = (email.subject ?? '').toLowerCase();
    // Include receipts, invoices, and subscription confirmation/expiring emails
    return from.contains('apple.com') &&
           (subject.contains('receipt') ||
            subject.contains('invoice') ||
            subject.contains('subscription is confirmed') ||
            subject.contains('subscription is expiring'));
  }

  ParsedSubscription? _parseAppleReceipt(EmailData email) {
    debugPrint('[EmailParser] Processing as Apple Receipt...');
    final textContent = _extractTextContent(email);

    String serviceName = 'Apple Purchase';
    SubscriptionCategory category = SubscriptionCategory.software;

    // Check for known services in Apple receipts
    final textLower = textContent.toLowerCase();

    if (textLower.contains('chatgpt')) {
      serviceName = 'ChatGPT Plus';
      category = SubscriptionCategory.software;
      debugPrint('[EmailParser] Found ChatGPT in Apple receipt');
    } else if (textLower.contains('icloud')) {
      serviceName = 'iCloud+';
      category = SubscriptionCategory.cloud;
      debugPrint('[EmailParser] Found iCloud in Apple receipt');
    } else if (textLower.contains('apple music')) {
      serviceName = 'Apple Music';
      category = SubscriptionCategory.streaming;
      debugPrint('[EmailParser] Found Apple Music in Apple receipt');
    } else if (textLower.contains('apple one')) {
      serviceName = 'Apple One';
      category = SubscriptionCategory.streaming;
      debugPrint('[EmailParser] Found Apple One in Apple receipt');
    } else if (textLower.contains('apple tv')) {
      serviceName = 'Apple TV+';
      category = SubscriptionCategory.streaming;
      debugPrint('[EmailParser] Found Apple TV+ in Apple receipt');
    } else if (textLower.contains('bevel')) {
      serviceName = 'Bevel';
      category = SubscriptionCategory.fitness;
      debugPrint('[EmailParser] Found Bevel in Apple receipt');
    } else if (textLower.contains('duolingo')) {
      serviceName = 'Duolingo';
      category = SubscriptionCategory.education;
      debugPrint('[EmailParser] Found Duolingo in Apple receipt');
    } else if (textLower.contains('spotify')) {
      serviceName = 'Spotify';
      category = SubscriptionCategory.streaming;
      debugPrint('[EmailParser] Found Spotify in Apple receipt');
    } else {
      // Try to extract app name from the receipt
      // Look for pattern: "AppName\nSomething (Monthly)"
      final appNameMatch = RegExp(r'Account:[^\n]+\n+([A-Za-zА-Яа-я0-9\s\-:]+?)[\n\s]+[A-Za-zА-Яа-я0-9\s\-]+\s*\(', caseSensitive: false).firstMatch(textContent);
      if (appNameMatch != null) {
        final extracted = appNameMatch.group(1)?.trim();
        if (extracted != null && extracted.isNotEmpty && extracted.length < 50) {
          serviceName = extracted;
          debugPrint('[EmailParser] Extracted app name: $serviceName');
        }
      }
    }

    // Extract amount - look for the main price line
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
    final lastPaymentDate = _extractLastPaymentDate(email.date);

    // Create excerpt
    final excerptMatch = RegExp(r'([A-Za-zА-Яа-я0-9\s\-:]+(?:Monthly|Yearly|месяц|год)[^\n]*\d+[.,]\d{2}\s*[€$₽£])', caseSensitive: false).firstMatch(textContent);
    final excerpt = excerptMatch?.group(0)?.trim();

    debugPrint('[EmailParser] RESULT (Apple): $serviceName');
    debugPrint('[EmailParser]   Amount: ${amount ?? "NOT FOUND"} $currency');
    debugPrint('[EmailParser]   Billing date: $billingDate');
    debugPrint('[EmailParser]   Last payment: $lastPaymentDate');
    debugPrint('[EmailParser]   Billing period: $billingPeriod');
    debugPrint('[EmailParser]   Cancelled: $isCancelled');
    debugPrint('═══════════════════════════════════════════════════════════');

    return ParsedSubscription(
      serviceName: serviceName,
      amount: amount,
      currency: currency,
      billingDate: billingDate,
      lastPaymentDate: lastPaymentDate,
      billingPeriod: billingPeriod,
      category: category,
      isCancelled: isCancelled,
      emailId: email.id,
      emailSubject: email.subject,
      emailExcerpt: excerpt,
    );
  }

  KnownService? _identifyService(EmailData email) {
    final fromLower = (email.from ?? '').toLowerCase();
    final subjectLower = (email.subject ?? '').toLowerCase();
    final snippetLower = (email.snippet ?? '').toLowerCase();

    // Exclude specific non-subscription services
    // Yandex Market is NOT a subscription
    if (fromLower.contains('market.yandex') ||
        fromLower.contains('яндекс маркет') ||
        subjectLower.contains('маркет') ||
        subjectLower.contains('market')) {
      debugPrint('[EmailParser] Excluded: Yandex Market email detected');
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

  String _extractTextContent(EmailData email) {
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

  AmountCandidate? _extractAmountSmart(String text, KnownService service) {
    final candidates = <AmountCandidate>[];
    final rejectedCandidates = <String>[]; // Track why candidates were rejected
    final textLower = text.toLowerCase();

    debugPrint('[AmountParser] Starting amount extraction for ${service.name}');
    debugPrint('[AmountParser] Context patterns: ${service.amountContextPatterns}');

    // Pattern 0: Amount near service-specific context patterns (highest priority)
    for (final contextPattern in service.amountContextPatterns) {
      // Find all occurrences of context pattern
      final contextRegex = RegExp(
        RegExp.escape(contextPattern) + r'[^₽$€\d]{0,50}(\d+[.,]?\d*)\s*([₽$€]|руб|usd|eur|rub)',
        caseSensitive: false,
      );
      for (final match in contextRegex.allMatches(textLower)) {
        final parsed = _parseMatchedAmount(match);
        if (parsed != null) {
          final isReasonable = _isReasonableAmount(parsed.amount);
          final isTypical = service.isTypicalAmount(parsed.amount, parsed.currency);
          if (isReasonable && isTypical) {
            candidates.add(AmountCandidate(
              amount: parsed.amount,
              currency: parsed.currency,
              priority: 0, // Highest priority
            ));
            debugPrint('[AmountParser] ✓ Context match P0: ${parsed.amount} ${parsed.currency} near "$contextPattern"');
          } else {
            rejectedCandidates.add('${parsed.amount} ${parsed.currency} (context "$contextPattern", reasonable=$isReasonable, typical=$isTypical)');
          }
        }
      }

      // Also try currency before amount
      final contextRegex2 = RegExp(
        RegExp.escape(contextPattern) + r'[^₽$€\d]{0,50}([₽$€])\s*(\d+[.,]?\d*)',
        caseSensitive: false,
      );
      for (final match in contextRegex2.allMatches(textLower)) {
        final currencySymbol = match.group(1)!;
        final amountStr = match.group(2)!.replaceAll(',', '.');
        final amount = double.tryParse(amountStr);
        final currency = _symbolToCurrency(currencySymbol);
        if (amount != null) {
          final isReasonable = _isReasonableAmount(amount);
          final isTypical = service.isTypicalAmount(amount, currency);
          if (isReasonable && isTypical) {
            candidates.add(AmountCandidate(
              amount: amount,
              currency: currency,
              priority: 0,
            ));
            debugPrint('[AmountParser] ✓ Context match P0: $amount $currency near "$contextPattern"');
          } else {
            rejectedCandidates.add('$amount $currency (context2 "$contextPattern", reasonable=$isReasonable, typical=$isTypical)');
          }
        }
      }
    }

    // Pattern 1: Amount near "total", "итого", "к оплате" (high priority)
    final totalPatterns = [
      RegExp(r'(?:total|итого|к оплате|сумма|amount)[:\s]*[^\d]*?(\d+[.,]?\d*)\s*([₽$€]|руб|usd|eur|rub)', caseSensitive: false),
      RegExp(r'([₽$€])\s*(\d+[.,]?\d*)\s*(?:total|итого)', caseSensitive: false),
    ];

    for (final pattern in totalPatterns) {
      for (final match in pattern.allMatches(text)) {
        final parsed = _parseMatchedAmount(match);
        if (parsed != null) {
          final isReasonable = _isReasonableAmount(parsed.amount);
          if (isReasonable) {
            final isTypical = service.isTypicalAmount(parsed.amount, parsed.currency);
            final priority = isTypical ? 1 : 4;
            candidates.add(AmountCandidate(
              amount: parsed.amount,
              currency: parsed.currency,
              priority: priority,
            ));
            debugPrint('[AmountParser] ✓ Total pattern P$priority: ${parsed.amount} ${parsed.currency} (typical=$isTypical)');
          } else {
            rejectedCandidates.add('${parsed.amount} ${parsed.currency} (total pattern, not reasonable)');
          }
        }
      }
    }

    // Pattern 2: Currency symbol followed by amount
    final currencyFirstPatterns = [
      RegExp(r'₽\s*(\d+[.,]?\d*)'),
      RegExp(r'\$\s*(\d+[.,]?\d*)'),
      RegExp(r'€\s*(\d+[.,]?\d*)'),
    ];

    for (int i = 0; i < currencyFirstPatterns.length; i++) {
      final pattern = currencyFirstPatterns[i];
      final currency = ['RUB', 'USD', 'EUR'][i];
      for (final match in pattern.allMatches(text)) {
        final amountStr = match.group(1)!.replaceAll(',', '.');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          final isReasonable = _isReasonableAmount(amount);
          if (isReasonable) {
            final isTypical = service.isTypicalAmount(amount, currency);
            final priority = isTypical ? 2 : 5;
            candidates.add(AmountCandidate(
              amount: amount,
              currency: currency,
              priority: priority,
            ));
            debugPrint('[AmountParser] ✓ Currency-first P$priority: $amount $currency (typical=$isTypical)');
          } else {
            rejectedCandidates.add('$amount $currency (currency-first, not reasonable)');
          }
        }
      }
    }

    // Pattern 3: Amount followed by currency
    final amountFirstPatterns = [
      RegExp(r'(\d+[.,]?\d*)\s*(?:₽|руб\.?|rub)', caseSensitive: false),
      RegExp(r'(\d+[.,]?\d*)\s*(?:\$|usd)', caseSensitive: false),
      RegExp(r'(\d+[.,]?\d*)\s*(?:€|eur)', caseSensitive: false),
    ];

    for (int i = 0; i < amountFirstPatterns.length; i++) {
      final pattern = amountFirstPatterns[i];
      final currency = ['RUB', 'USD', 'EUR'][i];
      for (final match in pattern.allMatches(text)) {
        final amountStr = match.group(1)!.replaceAll(',', '.');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          final isReasonable = _isReasonableAmount(amount);
          if (isReasonable) {
            final isTypical = service.isTypicalAmount(amount, currency);
            final priority = isTypical ? 3 : 6;
            candidates.add(AmountCandidate(
              amount: amount,
              currency: currency,
              priority: priority,
            ));
            debugPrint('[AmountParser] ✓ Amount-first P$priority: $amount $currency (typical=$isTypical)');
          } else {
            rejectedCandidates.add('$amount $currency (amount-first, not reasonable)');
          }
        }
      }
    }

    // Log rejected candidates
    if (rejectedCandidates.isNotEmpty) {
      debugPrint('[AmountParser] Rejected candidates:');
      for (final r in rejectedCandidates.take(5)) {
        debugPrint('[AmountParser]   ✗ $r');
      }
      if (rejectedCandidates.length > 5) {
        debugPrint('[AmountParser]   ... and ${rejectedCandidates.length - 5} more');
      }
    }

    if (candidates.isEmpty) {
      debugPrint('[AmountParser] ❌ No valid amount found for ${service.name}');
      debugPrint('[AmountParser] Tip: Check if amount exists in text with currency symbol');
      return null;
    }

    // Filter out amounts that are way too far from typical (likely not subscription amounts)
    // E.g., API invoices, one-time purchases, marketing numbers
    final filteredCandidates = candidates.where((c) {
      final range = service.typicalPrices[c.currency];
      if (range == null) return true; // No range defined, keep it
      // Allow up to 3x the max typical price (for yearly subscriptions etc)
      final maxAllowed = range.max * 3;
      if (c.amount > maxAllowed) {
        debugPrint('[AmountParser] Filtered out ${c.amount} ${c.currency} - exceeds 3x max typical (${range.max})');
        return false;
      }
      return true;
    }).toList();

    if (filteredCandidates.isEmpty) {
      debugPrint('[AmountParser] ❌ All amounts filtered out as too high for ${service.name}');
      return null;
    }

    // Sort by priority (lower is better), then by typical amount match
    filteredCandidates.sort((a, b) {
      if (a.priority != b.priority) {
        return a.priority.compareTo(b.priority);
      }
      // Secondary sort: prefer amounts in service's typical range
      final aTypical = service.isTypicalAmount(a.amount, a.currency) ? 1 : 0;
      final bTypical = service.isTypicalAmount(b.amount, b.currency) ? 1 : 0;
      if (aTypical != bTypical) {
        return bTypical.compareTo(aTypical);
      }
      // Tertiary sort: prefer amounts in general subscription range
      final aScore = _subscriptionLikelyScore(a.amount, a.currency);
      final bScore = _subscriptionLikelyScore(b.amount, b.currency);
      return bScore.compareTo(aScore);
    });

    debugPrint('[AmountParser] ═══ SUMMARY ═══');
    debugPrint('[AmountParser] Total candidates: ${filteredCandidates.length} (filtered from ${candidates.length})');
    debugPrint('[AmountParser] Selected: ${filteredCandidates.first.amount} ${filteredCandidates.first.currency} (priority=${filteredCandidates.first.priority})');

    // Log top 5 candidates for debugging
    debugPrint('[AmountParser] Top candidates:');
    for (int i = 0; i < filteredCandidates.length && i < 5; i++) {
      final c = filteredCandidates[i];
      final isTypical = service.isTypicalAmount(c.amount, c.currency);
      debugPrint('[AmountParser]   ${i == 0 ? "→" : " "} #${i + 1}: ${c.amount} ${c.currency}, P${c.priority}, typical=$isTypical');
    }

    return filteredCandidates.first;
  }

  String _symbolToCurrency(String symbol) {
    switch (symbol) {
      case '₽':
        return 'RUB';
      case '\$':
        return 'USD';
      case '€':
        return 'EUR';
      default:
        return 'RUB';
    }
  }

  ({double amount, String currency})? _parseMatchedAmount(RegExpMatch match) {
    try {
      final groups = <String>[];
      for (int i = 1; i <= match.groupCount; i++) {
        final g = match.group(i);
        if (g != null) groups.add(g);
      }

      double? amount;
      String currency = 'RUB';

      for (final g in groups) {
        // Check if it's a number
        final cleanNum = g.replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
        final parsed = double.tryParse(cleanNum);
        if (parsed != null && parsed > 0) {
          amount = parsed;
          continue;
        }

        // Check if it's a currency
        final lower = g.toLowerCase();
        if (lower.contains('₽') || lower.contains('руб') || lower.contains('rub')) {
          currency = 'RUB';
        } else if (lower.contains('\$') || lower.contains('usd')) {
          currency = 'USD';
        } else if (lower.contains('€') || lower.contains('eur')) {
          currency = 'EUR';
        }
      }

      if (amount != null) {
        return (amount: amount, currency: currency);
      }
    } catch (e) {
      debugPrint('[EmailParser] Error parsing amount: $e');
    }
    return null;
  }

  bool _isReasonableAmount(double amount) {
    // Filter out unrealistic amounts
    return amount > 0 && amount < 50000;
  }

  double _subscriptionLikelyScore(double amount, String currency) {
    // Typical subscription ranges
    if (currency == 'RUB') {
      if (amount >= 99 && amount <= 2000) return 100;
      if (amount >= 50 && amount <= 5000) return 50;
      return 10;
    } else if (currency == 'USD' || currency == 'EUR') {
      if (amount >= 0.99 && amount <= 30) return 100;
      if (amount >= 0.5 && amount <= 100) return 50;
      return 10;
    }
    return 10;
  }

  DateTime? _extractBillingDate(String text) {
    final patterns = [
      // ISO format
      RegExp(r'(\d{4}-\d{2}-\d{2})'),
      // Russian format DD.MM.YYYY
      RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})'),
      // Russian format DD.MM.YY
      RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{2})'),
      // Format with month name
      RegExp(r'(\d{1,2})\s+(января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря)\s+(\d{4})', caseSensitive: false),
    ];

    // Try ISO format
    var match = patterns[0].firstMatch(text);
    if (match != null) {
      final date = DateTime.tryParse(match.group(1)!);
      if (date != null && _isReasonableDate(date)) {
        return date;
      }
    }

    // Try DD.MM.YYYY
    match = patterns[1].firstMatch(text);
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

    // Try DD.MM.YY
    match = patterns[2].firstMatch(text);
    if (match != null) {
      final day = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      var year = int.tryParse(match.group(3)!);
      if (day != null && month != null && year != null) {
        year += 2000;
        try {
          final date = DateTime(year, month, day);
          if (_isReasonableDate(date)) {
            return date;
          }
        } catch (_) {}
      }
    }

    // Try Russian month names
    match = patterns[3].firstMatch(text);
    if (match != null) {
      final day = int.tryParse(match.group(1)!);
      final monthName = match.group(2)!.toLowerCase();
      final year = int.tryParse(match.group(3)!);

      final months = {
        'января': 1, 'февраля': 2, 'марта': 3, 'апреля': 4,
        'мая': 5, 'июня': 6, 'июля': 7, 'августа': 8,
        'сентября': 9, 'октября': 10, 'ноября': 11, 'декабря': 12,
      };

      final month = months[monthName];
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

    final yearlyPatterns = [
      'ежегодн', 'yearly', 'annual', '/год', '/year', 'per year', 'в год',
    ];
    for (final pattern in yearlyPatterns) {
      if (textLower.contains(pattern)) {
        return BillingPeriod.yearly;
      }
    }

    final weeklyPatterns = [
      'еженедельн', 'weekly', '/неделю', '/week', 'per week', 'в неделю',
    ];
    for (final pattern in weeklyPatterns) {
      if (textLower.contains(pattern)) {
        return BillingPeriod.weekly;
      }
    }

    final monthlyPatterns = [
      'ежемесячн', 'monthly', '/месяц', '/month', 'per month', 'в месяц',
    ];
    for (final pattern in monthlyPatterns) {
      if (textLower.contains(pattern)) {
        return BillingPeriod.monthly;
      }
    }

    return BillingPeriod.monthly; // Default to monthly for subscriptions
  }

  String? _extractPaymentExcerpt(String text, AmountCandidate? amount) {
    if (amount == null) return null;

    // Find the amount in text and extract surrounding context
    final amountStr = amount.amount.toString();
    final amountInt = amount.amount.toInt().toString();

    // Keywords that indicate payment-related content
    final paymentKeywords = [
      'оплата', 'списан', 'charge', 'payment', 'подписка', 'subscription',
      'итого', 'total', 'сумма', 'amount', 'тариф', 'план', 'plan',
      'продлен', 'renew', 'автоплатеж', 'recurring',
    ];

    // Try to find a sentence containing the amount
    final sentences = text.split(RegExp(r'[.!?\n]+'));

    for (final sentence in sentences) {
      final sentenceLower = sentence.toLowerCase();
      // Check if sentence contains the amount (with some flexibility)
      final containsAmount = sentence.contains(amountStr) ||
                             sentence.contains(amountInt) ||
                             sentence.contains('₽') ||
                             sentence.contains('\$') ||
                             sentence.contains('€');

      if (containsAmount) {
        // Check if it also contains a payment keyword
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

    // Fallback: find text around the amount
    final amountPattern = RegExp(
      r'.{0,100}(\d+[.,]?\d*)\s*([₽$€]|руб|usd|eur).{0,100}',
      caseSensitive: false,
    );

    final match = amountPattern.firstMatch(text);
    if (match != null) {
      final excerpt = match.group(0)?.trim();
      if (excerpt != null && excerpt.length > 10) {
        // Clean up and limit length
        final cleaned = excerpt
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        return cleaned.length > 200 ? '${cleaned.substring(0, 200)}...' : cleaned;
      }
    }

    return null;
  }

  Subscription createSubscription(ParsedSubscription parsed) {
    final now = DateTime.now();
    return Subscription(
      serviceName: parsed.serviceName,
      amount: parsed.amount ?? 0,
      currency: parsed.currency ?? 'RUB',
      nextBillingDate: parsed.billingDate,
      lastPaymentDate: parsed.lastPaymentDate,
      billingPeriod: parsed.billingPeriod,
      status: parsed.isCancelled ? SubscriptionStatus.cancelled : SubscriptionStatus.active,
      category: parsed.category,
      emailId: parsed.emailId,
      emailSubject: parsed.emailSubject,
      emailExcerpt: parsed.emailExcerpt,
      createdAt: now,
      updatedAt: now,
    );
  }
}
