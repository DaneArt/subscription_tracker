# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter mobile app that tracks subscription services by analyzing Gmail receipts. Uses Google Sign-In with Gmail read-only scope to scan emails for subscription patterns, extract payment amounts, and display spending summaries.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Analyze code (linting)
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Build for platforms
flutter build apk       # Android
flutter build ios       # iOS
flutter build web       # Web
```

## Architecture

**Pattern:** Clean Architecture with BLoC state management

```
lib/
├── blocs/           # AuthBloc, SubscriptionBloc - state management
├── models/          # Data models (Subscription, EmailData, KnownServices)
├── services/        # AuthService, GmailService, EmailParserService, DatabaseService
├── screens/         # UI pages (auth, home, add_subscription)
└── widgets/         # Reusable components (subscription_card, detail_sheet)
```

**Data Flow:**
UI Event → BLoC Event → Service → Database → New State → UI Rebuild

**Key Services:**
- `AuthService` - Google Sign-In wrapper
- `GmailService` - Gmail API email retrieval
- `EmailParserService` - Extracts subscription data from emails using pattern matching and heuristics
- `DatabaseService` - SQLite singleton for local storage

**Email Processing:**
- Emails parsed in isolates via `compute()` in batches of 10 to prevent UI blocking
- `email_parser_isolate.dart` contains isolate-safe parsing logic
- `known_services.dart` defines 30+ services with email patterns, subject patterns, and price ranges

## Conventions

- Barrel exports in each layer (e.g., `blocs.dart`, `services.dart`)
- Equatable for value comparison in models and states
- `copyWith` pattern for immutable state updates
- `.toMap()` / `.fromMap()` for model serialization
- Russian localization for UI strings and enum display names
- File naming: snake_case; Class naming: CamelCase

## Database

SQLite with `subscriptions` table. Schema migrations handled in `DatabaseService._upgradeDb()`. Currently at version 3.

## Authentication

Gmail read-only scope required. Credentials configured via:
- Android: `google-services.json`
- iOS: `GoogleService-Info.plist`

## Integration Tests (Email Parser)

Tests that verify the email parsing pipeline against real email data.

### Running integration tests

```bash
# Run all integration tests
flutter test test/email_parser_integration_test.dart

# Run all tests (unit + integration)
flutter test
```

### Email fixture format

Place JSON files in `test/fixtures/`. Each file is an array of email objects:

```json
[
  {
    "id": "unique_email_id",
    "from": "sender@example.com",
    "subject": "Email subject",
    "body": "<html>...</html>",
    "date": "2026-02-15T10:30:00Z",
    "snippet": "Preview text"
  }
]
```

### Adding your own email data

**Option 1: Export during sync** — pass `exportPath` to `SubscriptionSyncRequested`:
```dart
add(SubscriptionSyncRequested(exportPath: '/path/to/save/'));
```
This saves all fetched emails as `email_dump_{timestamp}.json`.

**Option 2: Manual** — copy emails into a JSON file following the format above. Place it at `test/fixtures/my_emails.json`.

### Snapshot testing (regression detection)

On first run, tests auto-generate `*_snapshot.json` files with parser results. Subsequent runs compare against these baselines.

To regenerate snapshots after intentional parser changes:
```bash
# Delete old snapshots
rm test/fixtures/*_snapshot.json

# Re-run tests (regenerates snapshots)
flutter test test/email_parser_integration_test.dart

# Or use the standalone script
dart test/generate_snapshot.dart
```

### Files

- `test/fixtures/sample_emails.json` — example fixture with 10 test emails
- `test/fixtures/sample_emails_expected.json` — expected results for sample emails
- `test/email_parser_integration_test.dart` — integration test suite
- `test/generate_snapshot.dart` — standalone snapshot generator
- `lib/services/email_export_service.dart` — email export utility
