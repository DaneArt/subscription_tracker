import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Parser for Raiffeisen Serbia SMS notifications
///
/// Example SMS format:
/// ```
/// Koriscenje kartice 4054**3134
/// Datum: 14.01.2026 18:13:24
/// Iznos: 70,00 USD
/// Raspolozivo: 671.714,59 RSD
/// Mesto: CANCEL SUBSCRIPTIONS NEW YORK US
/// ```
class SmsParserService {
  /// Parse a Raiffeisen SMS message into a BankTransaction
  BankTransaction? parseSms(String smsText, {DateTime? receivedAt}) {
    try {
      debugPrint('[SmsParser] Parsing SMS...');

      // Extract card number
      final cardMatch = RegExp(r'kartice\s+(\d+\*+\d+)').firstMatch(smsText);
      final cardNumber = cardMatch?.group(1) ?? 'unknown';

      // Extract date and time
      // Format: DD.MM.YYYY HH:MM:SS
      final dateMatch = RegExp(r'Datum:\s*(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2}):(\d{2})').firstMatch(smsText);
      DateTime? transactionDate;
      if (dateMatch != null) {
        final day = int.parse(dateMatch.group(1)!);
        final month = int.parse(dateMatch.group(2)!);
        final year = int.parse(dateMatch.group(3)!);
        final hour = int.parse(dateMatch.group(4)!);
        final minute = int.parse(dateMatch.group(5)!);
        final second = int.parse(dateMatch.group(6)!);
        transactionDate = DateTime(year, month, day, hour, minute, second);
      }

      if (transactionDate == null) {
        debugPrint('[SmsParser] Could not parse date');
        return null;
      }

      // Extract amount and currency
      // Format: 70,00 USD or 1.234,56 RSD
      final amountMatch = RegExp(r'Iznos:\s*([\d.,]+)\s*([A-Z]{3})').firstMatch(smsText);
      double? amount;
      String currency = 'RSD';
      if (amountMatch != null) {
        // Handle European number format (1.234,56)
        String amountStr = amountMatch.group(1)!;
        amountStr = amountStr.replaceAll('.', '').replaceAll(',', '.');
        amount = double.tryParse(amountStr);
        currency = amountMatch.group(2)!;
      }

      if (amount == null) {
        debugPrint('[SmsParser] Could not parse amount');
        return null;
      }

      // Extract balance after transaction
      // Format: 671.714,59 RSD
      final balanceMatch = RegExp(r'Raspolozivo:\s*([\d.,]+)\s*([A-Z]{3})').firstMatch(smsText);
      double? balanceAfter;
      String? balanceCurrency;
      if (balanceMatch != null) {
        String balanceStr = balanceMatch.group(1)!;
        balanceStr = balanceStr.replaceAll('.', '').replaceAll(',', '.');
        balanceAfter = double.tryParse(balanceStr);
        balanceCurrency = balanceMatch.group(2);
      }

      // Extract merchant/location
      final merchantMatch = RegExp(r'Mesto:\s*(.+)$', multiLine: true).firstMatch(smsText);
      final merchant = merchantMatch?.group(1)?.trim() ?? 'Unknown';

      debugPrint('[SmsParser] Parsed: $amount $currency at $merchant on $transactionDate');

      return BankTransaction(
        cardNumber: cardNumber,
        date: transactionDate,
        amount: amount,
        currency: currency,
        balanceAfter: balanceAfter,
        balanceCurrency: balanceCurrency,
        merchant: merchant,
        rawSms: smsText,
        createdAt: receivedAt ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('[SmsParser] Error parsing SMS: $e');
      return null;
    }
  }

  /// Parse SMS from forwarded email body
  /// The email might have the SMS text in the body with some extra text
  BankTransaction? parseFromEmail(String emailBody, {DateTime? emailDate}) {
    // Try to extract SMS text from email
    // iOS Shortcut might add some prefix/suffix

    // Look for the SMS pattern
    if (emailBody.contains('Koriscenje kartice') || emailBody.contains('kartice')) {
      return parseSms(emailBody, receivedAt: emailDate);
    }

    return null;
  }

  /// Detect subscriptions from a list of transactions
  /// Groups transactions by merchant and finds recurring payments
  List<DetectedSubscription> detectSubscriptions(
    List<BankTransaction> transactions, {
    int minOccurrences = 2,
    double amountTolerance = 0.01, // Allow 1% variance in amount
  }) {
    debugPrint('[SmsParser] Detecting subscriptions from ${transactions.length} transactions...');

    // Group transactions by normalized merchant name
    final merchantGroups = <String, List<BankTransaction>>{};
    for (final tx in transactions) {
      final key = tx.normalizedMerchant;
      merchantGroups.putIfAbsent(key, () => []).add(tx);
    }

    final subscriptions = <DetectedSubscription>[];

    for (final entry in merchantGroups.entries) {
      final merchant = entry.key;
      final txList = entry.value;

      // Skip if not enough occurrences
      if (txList.length < minOccurrences) continue;

      // Group by similar amounts (within tolerance)
      final amountGroups = <double, List<BankTransaction>>{};
      for (final tx in txList) {
        // Find existing group with similar amount
        double? matchingAmount;
        for (final existingAmount in amountGroups.keys) {
          final diff = (tx.amount - existingAmount).abs();
          final tolerance = existingAmount * amountTolerance;
          if (diff <= tolerance) {
            matchingAmount = existingAmount;
            break;
          }
        }

        if (matchingAmount != null) {
          amountGroups[matchingAmount]!.add(tx);
        } else {
          amountGroups[tx.amount] = [tx];
        }
      }

      // Find recurring payments (same amount, multiple times)
      for (final amountEntry in amountGroups.entries) {
        final amount = amountEntry.key;
        final amountTxList = amountEntry.value;

        if (amountTxList.length < minOccurrences) continue;

        // Sort by date
        amountTxList.sort((a, b) => a.date.compareTo(b.date));

        // Calculate average interval
        Duration? avgInterval;
        if (amountTxList.length >= 2) {
          int totalDays = 0;
          for (int i = 1; i < amountTxList.length; i++) {
            totalDays += amountTxList[i].date.difference(amountTxList[i - 1].date).inDays;
          }
          avgInterval = Duration(days: totalDays ~/ (amountTxList.length - 1));
        }

        // Get currency from most recent transaction
        final currency = amountTxList.last.currency;

        subscriptions.add(DetectedSubscription(
          merchant: merchant,
          amount: amount,
          currency: currency,
          occurrences: amountTxList.length,
          lastDate: amountTxList.last.date,
          firstDate: amountTxList.first.date,
          averageInterval: avgInterval,
        ));

        debugPrint('[SmsParser] Detected subscription: $merchant - $amount $currency (${amountTxList.length}x)');
      }
    }

    // Sort by occurrences (most frequent first)
    subscriptions.sort((a, b) => b.occurrences.compareTo(a.occurrences));

    debugPrint('[SmsParser] Found ${subscriptions.length} potential subscriptions');
    return subscriptions;
  }

  /// Known subscription services to help identify subscriptions
  static const knownSubscriptionMerchants = [
    'NETFLIX',
    'SPOTIFY',
    'YOUTUBE',
    'APPLE.COM',
    'APPLE COM',
    'GOOGLE',
    'AMAZON',
    'ANTHROPIC',
    'CLAUDE',
    'OPENAI',
    'CHATGPT',
    'ELEVENLABS',
    'CURSOR',
    'OBSIDIAN',
    'NOTION',
    'FIGMA',
    'GITHUB',
    'JETBRAINS',
    'ADOBE',
    'MICROSOFT',
    'DROPBOX',
    'ICLOUD',
    'NORDVPN',
    'EXPRESSVPN',
    'DUOLINGO',
    'STRAVA',
    'STEAM',
    'PLAYSTATION',
    'XBOX',
    'NINTENDO',
    'PADDLE',
    'N8N',
    'DEVIANTART',
    'PATREON',
    'SUBSTACK',
    'MEDIUM',
  ];

  /// Check if a merchant name looks like a subscription service
  bool isLikelySubscription(String merchant) {
    final upper = merchant.toUpperCase();
    return knownSubscriptionMerchants.any((known) => upper.contains(known));
  }
}
