# Subscription Tracker

Flutter-приложение для автоматического отслеживания подписок через анализ писем из Gmail.

## Возможности

- Автоматическое обнаружение подписок из Gmail
- Поддержка 30+ популярных сервисов (Netflix, Spotify, Claude, ChatGPT, iCloud и др.)
- Конвертация валют (USD, EUR, RUB)
- Отслеживание отменённых подписок
- Отображение дат платежей
- Параллельная обработка писем через изоляты

## Скриншоты

*TODO: Добавить скриншоты*

## Установка

### Требования

- Flutter 3.0+
- Dart 3.0+
- Google Cloud Console проект с включённым Gmail API

### Настройка Google Cloud

1. Создайте проект в [Google Cloud Console](https://console.cloud.google.com/)
2. Включите Gmail API
3. Настройте OAuth consent screen
4. Создайте OAuth 2.0 Client ID для Android
5. Добавьте SHA-1 fingerprint приложения
6. Скачайте `google-services.json` и поместите в `android/app/`

### Запуск

```bash
# Клонировать репозиторий
git clone https://github.com/YOUR_USERNAME/subscription_tracker.git
cd subscription_tracker

# Установить зависимости
flutter pub get

# Запустить приложение
flutter run
```

## Архитектура

```
lib/
├── main.dart
├── app.dart
├── models/
│   ├── subscription.dart      # Модель подписки
│   ├── email_data.dart        # Модель письма
│   └── known_services.dart    # База известных сервисов
├── services/
│   ├── auth_service.dart      # Google Sign-In
│   ├── gmail_service.dart     # Gmail API
│   ├── email_parser_service.dart    # Парсинг писем
│   ├── email_parser_isolate.dart    # Изолят для парсинга
│   └── database_service.dart  # SQLite
├── blocs/
│   ├── auth/                  # Авторизация (BLoC)
│   └── subscription/          # Подписки (BLoC)
├── screens/
│   ├── auth_screen.dart
│   ├── home_screen.dart
│   └── add_subscription_screen.dart
└── widgets/
    ├── subscription_card.dart
    ├── subscription_detail_sheet.dart
    └── total_spending_card.dart
```

## Поддерживаемые сервисы

### Стриминг
Netflix, Spotify, YouTube Premium, Apple Music, Яндекс Плюс, Кинопоиск, Okko

### Облако и софт
iCloud, Google One, Dropbox, Adobe Creative Cloud, JetBrains, Microsoft 365

### AI-сервисы
Claude, ChatGPT Plus, ElevenLabs

### Другое
NordVPN, ExpressVPN, Duolingo, Strava, Obsidian, GitHub, Notion, Figma, Oura, Chargeback

## Технологии

- **Flutter** - UI framework
- **flutter_bloc** - State management
- **googleapis** - Gmail API
- **sqflite** - Локальная база данных
- **google_sign_in** - Авторизация

## Лицензия

MIT License

## Автор

Daniil
