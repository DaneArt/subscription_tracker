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
