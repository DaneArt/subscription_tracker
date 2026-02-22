import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/email_data.dart';

/// Service for exporting raw email data to JSON files.
/// Used to create test fixtures from real email data.
class EmailExportService {
  /// Exports a list of EmailData objects to a JSON file.
  /// Returns the path to the exported file.
  ///
  /// [emails] - List of email data to export.
  /// [directory] - Directory to save the file in. If null, uses app documents dir.
  /// [filename] - Name of the JSON file (default: 'email_dump_{timestamp}.json').
  static Future<String> exportToJson({
    required List<EmailData> emails,
    required String directory,
    String? filename,
  }) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final name = filename ?? 'email_dump_$timestamp.json';
    final filePath = path.join(directory, name);

    final jsonList = emails.map((e) => emailDataToJson(e)).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

    final file = File(filePath);
    await file.writeAsString(jsonString);

    debugPrint('[EmailExport] Exported ${emails.length} emails to $filePath');
    return filePath;
  }

  /// Converts EmailData to a JSON-serializable map.
  static Map<String, dynamic> emailDataToJson(EmailData email) {
    return {
      'id': email.id,
      'from': email.from,
      'subject': email.subject,
      'body': email.body,
      'date': email.date?.toIso8601String(),
      'snippet': email.snippet,
    };
  }

  /// Loads EmailData list from a JSON file.
  static Future<List<EmailData>> loadFromJson(String filePath) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    return parseEmailListFromJson(jsonString);
  }

  /// Parses a JSON string into a list of EmailData objects.
  static List<EmailData> parseEmailListFromJson(String jsonString) {
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
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
}
