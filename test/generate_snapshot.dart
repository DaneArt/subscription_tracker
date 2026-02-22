/// Standalone script to generate/update snapshot baselines from email fixtures.
///
/// Usage:
///   dart test/generate_snapshot.dart [fixture_file]
///
/// If no fixture_file is specified, processes all JSON files in test/fixtures/
/// (excluding *_expected.json and *_snapshot.json).
///
/// This is useful when you intentionally change the parser and want to update
/// the expected results to match the new behavior.
library;

import 'dart:convert';
import 'dart:io';

import 'package:subscription_tracker/models/models.dart';
import 'package:subscription_tracker/services/email_parser_service.dart';

List<EmailData> loadEmails(String filePath) {
  final jsonString = File(filePath).readAsStringSync();
  final jsonList = json.decode(jsonString) as List;
  return jsonList.map((item) {
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
}

void generateSnapshot(String fixturePath) {
  final emails = loadEmails(fixturePath);
  final parser = EmailParserService();

  final results = <Map<String, dynamic>>[];
  var parsed = 0;
  var skipped = 0;

  for (final email in emails) {
    final result = parser.parseEmail(email);
    if (result != null) {
      parsed++;
      results.add({
        'emailId': result.emailId,
        'serviceName': result.serviceName,
        'amount': result.amount,
        'currency': result.currency,
        'billingPeriod': result.billingPeriod.name,
        'category': result.category.name,
        'isCancelled': result.isCancelled,
        'emailSubject': result.emailSubject,
        'emailExcerpt': result.emailExcerpt,
      });
    } else {
      skipped++;
      results.add({
        'emailId': email.id,
        'shouldSkip': true,
        'emailSubject': email.subject,
        '_from': email.from,
      });
    }
  }

  final snapshotPath = fixturePath.replaceAll('.json', '_snapshot.json');
  final snapshotJson = const JsonEncoder.withIndent('  ').convert(results);
  File(snapshotPath).writeAsStringSync(snapshotJson);

  // ignore: avoid_print
  print('$fixturePath: ${emails.length} emails -> $parsed parsed, $skipped skipped');
  // ignore: avoid_print
  print('  Snapshot saved: $snapshotPath');
}

void main(List<String> args) {
  if (args.isNotEmpty) {
    for (final arg in args) {
      generateSnapshot(arg);
    }
    return;
  }

  final fixturesDir = Directory('test/fixtures');
  if (!fixturesDir.existsSync()) {
    // ignore: avoid_print
    print('No test/fixtures directory found.');
    return;
  }

  final fixtureFiles = fixturesDir
      .listSync()
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.json') &&
          !f.path.endsWith('_expected.json') &&
          !f.path.endsWith('_snapshot.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (fixtureFiles.isEmpty) {
    // ignore: avoid_print
    print('No fixture files found in test/fixtures/');
    return;
  }

  for (final file in fixtureFiles) {
    generateSnapshot(file.path);
  }
}
