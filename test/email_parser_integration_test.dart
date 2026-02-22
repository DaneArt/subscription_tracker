import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_tracker/models/models.dart';
import 'package:subscription_tracker/services/email_parser_service.dart';

/// Integration tests for email parsing pipeline.
///
/// These tests load email fixtures from JSON files and verify
/// that the parser extracts correct subscription data.
///
/// ## How to add your own email data:
///
/// 1. Export emails during sync (set exportPath in SubscriptionSyncRequested)
///    OR manually create a JSON file matching the format in test/fixtures/sample_emails.json
///
/// 2. Create a corresponding *_expected.json file with expected parse results
///    OR run the test with `--update-snapshots` to auto-generate baseline
///
/// 3. Run: flutter test test/email_parser_integration_test.dart
void main() {
  late EmailParserService parser;

  setUp(() {
    parser = EmailParserService();
  });

  group('Email Parser Integration Tests', () {
    group('Sample fixture parsing', () {
      late List<EmailData> emails;
      late List<Map<String, dynamic>> expected;

      setUp(() {
        final emailsJson = File('test/fixtures/sample_emails.json').readAsStringSync();
        emails = (json.decode(emailsJson) as List).map((item) {
          final map = item as Map<String, dynamic>;
          return EmailData(
            id: map['id'] as String,
            from: map['from'] as String?,
            subject: map['subject'] as String?,
            body: map['body'] as String?,
            date: map['date'] != null ? DateTime.tryParse(map['date'] as String) : null,
            snippet: map['snippet'] as String?,
          );
        }).toList();

        final expectedJson = File('test/fixtures/sample_emails_expected.json').readAsStringSync();
        expected = (json.decode(expectedJson) as List).cast<Map<String, dynamic>>();
      });

      test('parses all fixture emails and matches expected results', () {
        for (final exp in expected) {
          final emailId = exp['emailId'] as String;
          final shouldSkip = exp['shouldSkip'] == true;
          final email = emails.firstWhere((e) => e.id == emailId);

          final result = parser.parseEmail(email);

          if (shouldSkip) {
            expect(result, isNull,
                reason: 'Email $emailId should be skipped: ${exp['_comment'] ?? ''}');
            continue;
          }

          expect(result, isNotNull,
              reason: 'Email $emailId should parse successfully');

          if (exp['serviceName'] != null) {
            expect(result!.serviceName, equals(exp['serviceName']),
                reason: 'Service name mismatch for $emailId');
          }

          if (exp['amount'] != null) {
            expect(result!.amount, closeTo((exp['amount'] as num).toDouble(), 0.01),
                reason: 'Amount mismatch for $emailId');
          }

          if (exp['currency'] != null) {
            expect(result!.currency, equals(exp['currency']),
                reason: 'Currency mismatch for $emailId');
          }

          if (exp['billingPeriod'] != null) {
            expect(result!.billingPeriod.name, equals(exp['billingPeriod']),
                reason: 'Billing period mismatch for $emailId');
          }

          if (exp['category'] != null) {
            expect(result!.category.name, equals(exp['category']),
                reason: 'Category mismatch for $emailId');
          }

          if (exp['isCancelled'] != null) {
            expect(result!.isCancelled, equals(exp['isCancelled']),
                reason: 'Cancelled status mismatch for $emailId');
          }
        }
      });

      test('Netflix receipt is parsed correctly', () {
        final email = emails.firstWhere((e) => e.id == 'test_netflix_001');
        final result = parser.parseEmail(email);

        expect(result, isNotNull);
        expect(result!.serviceName, 'Netflix');
        expect(result.amount, 399.0);
        expect(result.currency, 'RUB');
        expect(result.category, SubscriptionCategory.streaming);
        expect(result.isCancelled, isFalse);
      });

      test('Spotify receipt is parsed correctly', () {
        final email = emails.firstWhere((e) => e.id == 'test_spotify_001');
        final result = parser.parseEmail(email);

        expect(result, isNotNull);
        expect(result!.serviceName, 'Spotify');
        expect(result.amount, closeTo(9.99, 0.01));
        expect(result.currency, 'USD');
        expect(result.category, SubscriptionCategory.streaming);
      });

      test('Apple receipt (ChatGPT) is parsed correctly', () {
        final email = emails.firstWhere((e) => e.id == 'test_apple_receipt_001');
        final result = parser.parseEmail(email);

        expect(result, isNotNull);
        expect(result!.serviceName, 'ChatGPT Plus');
        expect(result.amount, closeTo(19.99, 0.01));
        expect(result.currency, 'EUR');
      });

      test('Bank SMS forward (YouTube Premium) is parsed correctly', () {
        final email = emails.firstWhere((e) => e.id == 'test_bank_sms_001');
        final result = parser.parseEmail(email);

        expect(result, isNotNull);
        expect(result!.serviceName, 'YouTube Premium');
        expect(result.amount, 819.0);
        expect(result.currency, 'RSD');
      });

      test('Cancelled subscription is detected', () {
        final email = emails.firstWhere((e) => e.id == 'test_cancelled_001');
        final result = parser.parseEmail(email);

        expect(result, isNotNull);
        expect(result!.serviceName, 'Netflix');
        expect(result.isCancelled, isTrue);
      });

      test('Promo email is skipped', () {
        final email = emails.firstWhere((e) => e.id == 'test_promo_skip_001');
        final result = parser.parseEmail(email);

        expect(result, isNull);
      });

      test('GitHub CI notification is skipped', () {
        final email = emails.firstWhere((e) => e.id == 'test_github_actions_skip_001');
        final result = parser.parseEmail(email);

        expect(result, isNull);
      });

      test('Яндекс Плюс receipt is parsed correctly', () {
        final email = emails.firstWhere((e) => e.id == 'test_yandex_plus_001');
        final result = parser.parseEmail(email);

        expect(result, isNotNull);
        expect(result!.serviceName, 'Яндекс Плюс');
        expect(result.amount, 299.0);
        expect(result.currency, 'RUB');
      });

      test('NordVPN receipt is parsed correctly', () {
        final email = emails.firstWhere((e) => e.id == 'test_nordvpn_001');
        final result = parser.parseEmail(email);

        expect(result, isNotNull);
        expect(result!.serviceName, 'NordVPN');
        expect(result.amount, closeTo(11.99, 0.01));
        expect(result.currency, 'USD');
        expect(result.category, SubscriptionCategory.vpn);
      });
    });
  });

  group('Snapshot-based regression tests', () {
    test('parse all fixture emails and compare against snapshot', () {
      final fixturesDir = Directory('test/fixtures');
      if (!fixturesDir.existsSync()) return;

      // Find all email fixture files (exclude *_expected.json and *_snapshot.json)
      final fixtureFiles = fixturesDir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.json') &&
              !f.path.endsWith('_expected.json') &&
              !f.path.endsWith('_snapshot.json'))
          .toList();

      for (final fixtureFile in fixtureFiles) {
        final baseName = fixtureFile.path.replaceAll('.json', '');
        final snapshotFile = File('${baseName}_snapshot.json');

        final emailsJson = fixtureFile.readAsStringSync();
        final emails = (json.decode(emailsJson) as List).map((item) {
          final map = item as Map<String, dynamic>;
          return EmailData(
            id: map['id'] as String,
            from: map['from'] as String?,
            subject: map['subject'] as String?,
            body: map['body'] as String?,
            date: map['date'] != null ? DateTime.tryParse(map['date'] as String) : null,
            snippet: map['snippet'] as String?,
          );
        }).toList();

        final parser = EmailParserService();
        final results = <Map<String, dynamic>>[];

        for (final email in emails) {
          final parsed = parser.parseEmail(email);
          if (parsed != null) {
            results.add({
              'emailId': parsed.emailId,
              'serviceName': parsed.serviceName,
              'amount': parsed.amount,
              'currency': parsed.currency,
              'billingPeriod': parsed.billingPeriod.name,
              'category': parsed.category.name,
              'isCancelled': parsed.isCancelled,
            });
          } else {
            results.add({
              'emailId': email.id,
              'shouldSkip': true,
            });
          }
        }

        if (!snapshotFile.existsSync()) {
          // Generate snapshot baseline on first run
          final snapshotJson = const JsonEncoder.withIndent('  ').convert(results);
          snapshotFile.writeAsStringSync(snapshotJson);
          // ignore: avoid_print
          print('Generated snapshot: ${snapshotFile.path}');
          continue;
        }

        // Compare against existing snapshot
        final snapshotJson = snapshotFile.readAsStringSync();
        final snapshot = (json.decode(snapshotJson) as List).cast<Map<String, dynamic>>();

        expect(results.length, equals(snapshot.length),
            reason: 'Number of results changed for ${fixtureFile.path}');

        for (var i = 0; i < results.length; i++) {
          final result = results[i];
          final snap = snapshot[i];
          final emailId = result['emailId'] ?? 'unknown';

          expect(result['shouldSkip'], equals(snap['shouldSkip']),
              reason: 'Skip status changed for $emailId');

          if (result['shouldSkip'] == true) continue;

          expect(result['serviceName'], equals(snap['serviceName']),
              reason: 'Service name regression for $emailId');
          expect(result['currency'], equals(snap['currency']),
              reason: 'Currency regression for $emailId');
          expect(result['billingPeriod'], equals(snap['billingPeriod']),
              reason: 'Billing period regression for $emailId');
          expect(result['category'], equals(snap['category']),
              reason: 'Category regression for $emailId');
          expect(result['isCancelled'], equals(snap['isCancelled']),
              reason: 'Cancelled status regression for $emailId');

          if (result['amount'] != null && snap['amount'] != null) {
            expect(
              (result['amount'] as double),
              closeTo((snap['amount'] as num).toDouble(), 0.01),
              reason: 'Amount regression for $emailId',
            );
          }
        }
      }
    });
  });

  group('Custom fixture tests', () {
    test('loads and parses user email dump if present', () {
      // Place your exported email dump in test/fixtures/my_emails.json
      final userFixture = File('test/fixtures/my_emails.json');
      if (!userFixture.existsSync()) {
        // ignore: avoid_print
        print('No user fixture found at test/fixtures/my_emails.json - skipping');
        return;
      }

      final emailsJson = userFixture.readAsStringSync();
      final emails = (json.decode(emailsJson) as List).map((item) {
        final map = item as Map<String, dynamic>;
        return EmailData(
          id: map['id'] as String,
          from: map['from'] as String?,
          subject: map['subject'] as String?,
          body: map['body'] as String?,
          date: map['date'] != null ? DateTime.tryParse(map['date'] as String) : null,
          snippet: map['snippet'] as String?,
        );
      }).toList();

      final parser = EmailParserService();
      var parsed = 0;
      var skipped = 0;

      for (final email in emails) {
        final result = parser.parseEmail(email);
        if (result != null) {
          parsed++;
          // Basic sanity checks
          expect(result.serviceName, isNotEmpty,
              reason: 'Empty service name for ${email.id}');
          if (result.amount != null) {
            expect(result.amount, greaterThan(0),
                reason: 'Non-positive amount for ${email.id}');
          }
        } else {
          skipped++;
        }
      }

      // ignore: avoid_print
      print('User fixture: ${emails.length} emails, $parsed parsed, $skipped skipped');

      // Generate snapshot for user fixture
      final snapshotFile = File('test/fixtures/my_emails_snapshot.json');
      final results = <Map<String, dynamic>>[];
      for (final email in emails) {
        final result = parser.parseEmail(email);
        if (result != null) {
          results.add({
            'emailId': result.emailId,
            'serviceName': result.serviceName,
            'amount': result.amount,
            'currency': result.currency,
            'billingPeriod': result.billingPeriod.name,
            'category': result.category.name,
            'isCancelled': result.isCancelled,
            'emailSubject': result.emailSubject,
          });
        } else {
          results.add({
            'emailId': email.id,
            'shouldSkip': true,
            'emailSubject': email.subject,
          });
        }
      }

      if (!snapshotFile.existsSync()) {
        final snapshotJson = const JsonEncoder.withIndent('  ').convert(results);
        snapshotFile.writeAsStringSync(snapshotJson);
        // ignore: avoid_print
        print('Generated user snapshot: ${snapshotFile.path}');
      }
    });
  });
}
