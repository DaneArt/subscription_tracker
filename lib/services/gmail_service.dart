import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/googleapis_auth.dart';
import '../models/email_data.dart';
import 'email_parser_isolate.dart';

typedef SyncProgressCallback = void Function(SyncProgress progress);

class SyncProgress {
  final int totalFound;
  final int processed;
  final String? currentEmail;
  final String status;

  const SyncProgress({
    this.totalFound = 0,
    this.processed = 0,
    this.currentEmail,
    this.status = '',
  });

  double get percentage => totalFound > 0 ? processed / totalFound : 0;
}

class GmailService {
  gmail.GmailApi? _gmailApi;

  Future<void> init(AuthClient authClient) async {
    debugPrint('[GmailService] Initializing Gmail API...');
    _gmailApi = gmail.GmailApi(authClient);
    debugPrint('[GmailService] Gmail API initialized');
  }

  bool get isInitialized => _gmailApi != null;

  Future<List<EmailData>> searchSubscriptionEmails({
    int batchSize = 20,
    int maxTotal = 100,
    SyncProgressCallback? onProgress,
  }) async {
    if (_gmailApi == null) {
      throw Exception('Gmail API not initialized. Call init() first.');
    }

    debugPrint('[GmailService] Starting email search...');
    onProgress?.call(const SyncProgress(status: 'Поиск писем...'));

    final query = _buildSubscriptionQuery();
    debugPrint('[GmailService] Search query: $query');

    final allEmails = <EmailData>[];
    String? pageToken;
    int totalProcessed = 0;

    do {
      debugPrint('[GmailService] Fetching page, token: $pageToken');

      final response = await _gmailApi!.users.messages.list(
        'me',
        q: query,
        maxResults: batchSize,
        pageToken: pageToken,
      );

      final messages = response.messages ?? [];
      final totalFound = response.resultSizeEstimate ?? messages.length;

      debugPrint('[GmailService] Found ${messages.length} messages in this batch, estimated total: $totalFound');

      onProgress?.call(SyncProgress(
        totalFound: totalFound,
        processed: totalProcessed,
        status: 'Найдено ~$totalFound писем',
      ));

      // Fetch emails in parallel batches of 5
      final messagesToFetch = messages.where((_) => totalProcessed < maxTotal).toList();
      const parallelBatchSize = 5;

      for (var i = 0; i < messagesToFetch.length; i += parallelBatchSize) {
        if (totalProcessed >= maxTotal) {
          debugPrint('[GmailService] Reached max limit: $maxTotal');
          break;
        }

        final batch = messagesToFetch.skip(i).take(parallelBatchSize).toList();
        final futures = batch.map((m) => _getEmailDetails(m.id!));
        final results = await Future.wait(futures);

        for (final emailData in results) {
          if (emailData != null) {
            allEmails.add(emailData);
            debugPrint('[GmailService] Processed: ${emailData.subject}');
          }
          totalProcessed++;
        }

        onProgress?.call(SyncProgress(
          totalFound: totalFound,
          processed: totalProcessed,
          currentEmail: results.lastOrNull?.subject ?? 'Обработка...',
          status: 'Загружено $totalProcessed из ~$totalFound',
        ));
      }

      pageToken = response.nextPageToken;

      if (totalProcessed >= maxTotal) break;

    } while (pageToken != null);

    debugPrint('[GmailService] Search complete. Total emails: ${allEmails.length}');
    onProgress?.call(SyncProgress(
      totalFound: allEmails.length,
      processed: allEmails.length,
      status: 'Завершено! Обработано ${allEmails.length} писем',
    ));

    return allEmails;
  }

  String _buildSubscriptionQuery() {
    final keywords = [
      'subscription',
      'подписка',
      'renewal',
      'продление',
      'автоплатеж',
      'recurring payment',
      'monthly payment',
      'ежемесячный платеж',
      'оплата подписки',
      'your subscription',
      'billing',
      'invoice',
      'receipt',
      'чек',
    ];

    return keywords.map((k) => '("$k")').join(' OR ');
  }

  Future<EmailData?> _getEmailDetails(String messageId) async {
    try {
      final message = await _gmailApi!.users.messages.get(
        'me',
        messageId,
        format: 'full',
      );

      final headers = message.payload?.headers ?? [];

      String? from;
      String? subject;
      DateTime? date;

      for (final header in headers) {
        switch (header.name?.toLowerCase()) {
          case 'from':
            from = header.value;
            break;
          case 'subject':
            subject = header.value;
            break;
          case 'date':
            date = _parseDate(header.value);
            break;
        }
      }

      final body = _extractBody(message.payload);

      return EmailData(
        id: messageId,
        from: from,
        subject: subject,
        body: body,
        date: date,
        snippet: message.snippet,
      );
    } catch (e) {
      debugPrint('[GmailService] Error getting email $messageId: $e');
      return null;
    }
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;
    try {
      // Try ISO format first
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
        // Remove timezone info in parentheses like "(MSK)" or "(UTC)"
        var cleanDate = dateStr.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), '').trim();

        // Try parsing cleaned string
        final parsed = DateTime.tryParse(cleanDate);
        if (parsed != null) return parsed;

        // Parse RFC 2822 format: "Mon, 15 Jan 2026 12:00:00 +0000"
        final rfc2822Pattern = RegExp(
          r'(?:\w+,\s*)?(\d{1,2})\s+(\w+)\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4})?',
          caseSensitive: false,
        );
        final match = rfc2822Pattern.firstMatch(cleanDate);
        if (match != null) {
          final day = int.parse(match.group(1)!);
          final monthStr = match.group(2)!.toLowerCase();
          final year = int.parse(match.group(3)!);
          final hour = int.parse(match.group(4)!);
          final minute = int.parse(match.group(5)!);
          final second = int.tryParse(match.group(6) ?? '0') ?? 0;

          const months = {
            'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
            'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
          };
          final month = months[monthStr] ?? 1;

          return DateTime(year, month, day, hour, minute, second);
        }

        return null;
      } catch (_) {
        return null;
      }
    }
  }

  String? _extractBody(gmail.MessagePart? payload) {
    if (payload == null) return null;

    if (payload.body?.data != null) {
      try {
        return utf8.decode(base64Url.decode(payload.body!.data!));
      } catch (_) {
        return null;
      }
    }

    if (payload.parts != null) {
      for (final part in payload.parts!) {
        if (part.mimeType == 'text/plain' || part.mimeType == 'text/html') {
          if (part.body?.data != null) {
            try {
              return utf8.decode(base64Url.decode(part.body!.data!));
            } catch (_) {
              continue;
            }
          }
        }

        final nestedBody = _extractBody(part);
        if (nestedBody != null) return nestedBody;
      }
    }

    return null;
  }

  Future<List<String>> getLabels() async {
    if (_gmailApi == null) return [];

    final response = await _gmailApi!.users.labels.list('me');
    return response.labels?.map((l) => l.name ?? '').toList() ?? [];
  }

  /// Convert EmailData to EmailDataSimple for isolate processing
  static EmailDataSimple toSimple(EmailData email) {
    return EmailDataSimple(
      id: email.id,
      from: email.from,
      subject: email.subject,
      body: email.body,
      dateIso: email.date?.toIso8601String(),
      snippet: email.snippet,
    );
  }
}
