# Subscription Tracker

Flutter-приложение для отслеживания подписок на сервисы. Анализирует письма из Gmail, автоматически находит подписки, извлекает суммы платежей и показывает сводку расходов.

## Возможности

- **Автоматический поиск подписок** -- сканирует Gmail на наличие писем о подписках (чеки, квитанции, уведомления об оплате)
- **Извлечение сумм** -- парсит суммы платежей из тела писем с поддержкой нескольких валют (RUB, USD, EUR, RSD)
- **30+ известных сервисов** -- Netflix, Spotify, YouTube Premium, Яндекс Плюс, iCloud, ChatGPT Plus, Claude, JetBrains, GitHub и др.
- **Распознавание банковских SMS** -- поддержка пересланных SMS от банков (формат Raiffeisen Serbia)
- **Apple-чеки** -- специальная обработка чеков из App Store (iCloud+, Apple Music, ChatGPT и др.)
- **Категории** -- Стриминг, Облако, Софт, VPN, Фитнес, Образование
- **Автоотмена неактивных** -- подписки без платежей более месяца автоматически помечаются как отменённые (годовые не затрагиваются)
- **Сводка расходов** -- общая сумма в месяц и в год с конвертацией в рубли
- **Экономия** -- отдельный экран с отменёнными подписками и суммой экономии
- **Ручное добавление** -- возможность добавить подписку вручную
- **Тёмная тема** -- поддержка светлой и тёмной тем (Material 3)
- **Web-поддержка** -- работает в браузере с in-memory хранилищем

## Экраны

| Экран | Описание |
|-------|----------|
| Авторизация | Google Sign-In с запросом доступа к Gmail |
| Главный экран | Список активных подписок, карточка расходов, прогресс синхронизации |
| Детали подписки | Bottom sheet с темой письма, цитатой об оплате, датами платежей |
| Отменённые | Список отменённых подписок с суммой экономии |
| Добавление | Форма ручного добавления подписки (название, сумма, валюта, период, категория, дата) |

## Требования

- Flutter SDK >= 3.5.4
- Dart SDK >= 3.5.4
- Google Cloud Console проект с включённым Gmail API
- Android: `google-services.json` в `android/app/`
- iOS: `GoogleService-Info.plist` в `ios/Runner/`
- Web: Client ID указан в `AuthService`

## Быстрый старт

```bash
# Клонировать репозиторий
git clone <repo-url>
cd subscription_tracker

# Установить зависимости
flutter pub get

# Запустить приложение
flutter run
```

## Команды

```bash
flutter pub get          # Установка зависимостей
flutter run              # Запуск приложения
flutter analyze          # Статический анализ (линтинг)
flutter test             # Запуск всех тестов
flutter build apk        # Сборка для Android
flutter build ios        # Сборка для iOS
flutter build web        # Сборка для Web
```

## Архитектура

### Паттерн: Clean Architecture + BLoC

```
lib/
├── main.dart                  # Точка входа, инициализация DI
├── app.dart                   # MaterialApp, тема, роутинг по AuthState
├── blocs/
│   ├── auth/
│   │   ├── auth_bloc.dart     # Авторизация: check, signIn, signOut
│   │   ├── auth_event.dart    # AuthCheckRequested, AuthSignInRequested, AuthSignOutRequested
│   │   └── auth_state.dart    # AuthStatus: unknown, loading, authenticated, unauthenticated
│   └── subscription/
│       ├── subscription_bloc.dart   # Синхронизация, CRUD, прогресс
│       ├── subscription_event.dart  # Load, Sync, Add, Update, Delete, DeleteAll, SyncProgress
│       └── subscription_state.dart  # subscriptions, totalMonthlySpending, isSyncing
├── models/
│   ├── subscription.dart      # Subscription + enums (BillingPeriod, Status, Category)
│   ├── email_data.dart        # EmailData (id, from, subject, body, date, snippet)
│   └── known_services.dart    # KnownService + knownServices (30+ сервисов с паттернами)
├── services/
│   ├── auth_service.dart      # Google Sign-In, получение AuthClient
│   ├── gmail_service.dart     # Gmail API: поиск писем, извлечение тела, SyncProgress
│   ├── email_parser_service.dart    # Парсинг писем: идентификация сервиса, извлечение суммы
│   ├── email_parser_isolate.dart    # Isolate-безопасная копия парсера для compute()
│   ├── email_export_service.dart    # Экспорт писем в JSON для тестов
│   └── database_service.dart        # SQLite CRUD, конвертация валют, автоотмена
├── screens/
│   ├── auth_screen.dart              # Экран входа через Google
│   ├── home_screen.dart              # Главный экран: список подписок, синхронизация
│   ├── add_subscription_screen.dart  # Форма ручного добавления подписки
│   └── cancelled_subscriptions_screen.dart  # Отменённые подписки + экономия
└── widgets/
    ├── subscription_card.dart        # Карточка подписки (иконка, категория, статус, сумма)
    ├── subscription_detail_sheet.dart # Bottom sheet с деталями подписки
    └── total_spending_card.dart      # Градиентная карточка общих расходов
```

### Поток данных

```
UI Event → BLoC Event → Service → Database → New State → UI Rebuild
```

Пример синхронизации:
1. Пользователь нажимает "Синхронизировать"
2. `SubscriptionSyncRequested` отправляется в `SubscriptionBloc`
3. `AuthService.getAuthClient()` -- получение OAuth-токена
4. `GmailService.searchSubscriptionEmails()` -- поиск писем по ключевым словам и адресам отправителей
5. `compute(parseEmailBatch, ...)` -- парсинг батчами по 10 в изолятах
6. Дедупликация по имени сервиса (сохраняется самое свежее письмо)
7. `DatabaseService` -- сохранение в SQLite
8. `cancelInactiveSubscriptions()` -- автоотмена неактивных
9. UI обновляется через новый `SubscriptionState`

### Dependency Injection

Сервисы создаются в `main.dart` и передаются через `MultiRepositoryProvider` + `MultiBlocProvider`:

```dart
AuthService → AuthBloc
AuthService + GmailService + EmailParserService + DatabaseService → SubscriptionBloc
```

## Модели данных

### Subscription

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | `int?` | Автоинкрементный ID в SQLite |
| `serviceName` | `String` | Название сервиса (Netflix, Spotify и т.д.) |
| `serviceIcon` | `String?` | URL иконки |
| `amount` | `double` | Сумма платежа |
| `currency` | `String` | Валюта: RUB, USD, EUR, RSD (по умолчанию RUB) |
| `nextBillingDate` | `DateTime?` | Дата следующего списания (вычисляется из lastPaymentDate) |
| `lastPaymentDate` | `DateTime?` | Дата последнего платежа (из даты письма) |
| `billingPeriod` | `BillingPeriod` | monthly, yearly, weekly, unknown |
| `status` | `SubscriptionStatus` | active, cancelled, paused, unknown |
| `category` | `SubscriptionCategory` | streaming, cloud, software, vpn, fitness, education, other |
| `emailId` | `String?` | ID письма в Gmail |
| `emailSubject` | `String?` | Тема письма |
| `emailExcerpt` | `String?` | Цитата из письма с информацией об оплате |
| `notes` | `String?` | Заметки пользователя |

### KnownService

Каждый известный сервис определяется в `known_services.dart`:

```dart
KnownService(
  name: 'Netflix',
  emailPatterns: ['@netflix.com'],           // Паттерны адреса отправителя
  subjectPatterns: ['netflix membership'],    // Паттерны темы письма
  category: SubscriptionCategory.streaming,
  typicalPrices: {                           // Типичные диапазоны цен по валютам
    'RUB': PriceRange(399, 2500),
    'USD': PriceRange(6.99, 25),
  },
  amountContextPatterns: ['membership', 'подписка'],  // Контекст рядом с суммой
)
```

## Поддерживаемые сервисы

### Стриминг
Netflix, Spotify, YouTube Premium, Apple Music, Яндекс Плюс, Алиса Плюс, Кинопоиск, Okko

### Облако
iCloud, Google One, Dropbox

### Софт
Adobe Creative Cloud, JetBrains, Microsoft 365, Obsidian Sync, n8n, GitHub, Notion, Figma

### AI-сервисы
ChatGPT Plus, Claude, ElevenLabs

### VPN
NordVPN, ExpressVPN, Surfshark

### Фитнес и здоровье
BitePal, Strava, MyFitnessPal, Oura

### Образование
Duolingo, Coursera

### Утилиты
Chargeback

## База данных

SQLite (пакет `sqflite`), таблица `subscriptions`. Текущая версия схемы: **4**.

Миграции:
- v2: добавлены `emailSubject`, `emailExcerpt`
- v3: добавлено `lastPaymentDate`

Индексы: `status`, `serviceName`.

На Web используется in-memory хранилище (`List<Subscription>`).

### Конвертация валют

Для сводки расходов все суммы конвертируются в рубли по приблизительным курсам:
- 1 USD = 90 RUB
- 1 EUR = 98 RUB
- 1 GBP = 115 RUB

## Парсинг писем

### Поиск писем

Gmail API запрос включает:
- **Ключевые слова**: subscription, подписка, renewal, продление, автоплатеж, receipt, чек, billing, invoice и др.
- **Адреса отправителей**: netflix.com, spotify.com, apple.com, anthropic.com, openai.com и др.

Максимум 200 писем за синхронизацию, загрузка параллельными батчами по 5.

### Пайплайн парсинга

1. **Фильтрация промо** -- отсеиваются рекомендации, рассылки, CI-уведомления, скидки ("watch now", "% off", "run failed" и т.д.)
2. **Bank SMS** -- пересланные SMS от банков обрабатываются отдельно (поля: `Iznos`, `Mesto`, `Datum`)
3. **Apple-чеки** -- распознавание приложений внутри чеков App Store
4. **Идентификация сервиса** -- сопоставление `from`/`subject` с паттернами из `knownServices`
5. **Извлечение суммы** -- многоуровневый приоритетный поиск:
   - P0: сумма рядом с контекстными паттернами сервиса
   - P1: сумма рядом с "total" / "итого"
   - P2: символ валюты перед числом (`$19.99`)
   - P3: число перед символом валюты (`199 ₽`)
   - Фильтрация: отсев сумм > 3x от типичного максимума
6. **Период списания** -- поиск ключевых слов (monthly, ежемесячно, yearly, ежегодно)
7. **Определение отмены** -- ключевые слова: cancelled, отменена, expired, истекла
8. **Цитата** -- извлечение фрагмента письма с информацией о платеже

### Isolate-обработка

Парсинг выполняется в изолятах через `compute()` батчами по 10 писем. Логика парсинга дублируется в `email_parser_isolate.dart` как top-level функции без зависимостей от Flutter, т.к. изоляты не имеют доступа к основному потоку.

## Тестирование

### Юнит-тесты

```bash
flutter test test/widget_test.dart
```

### Интеграционные тесты парсера

```bash
flutter test test/email_parser_integration_test.dart
```

Тесты используют JSON-фикстуры из `test/fixtures/` и систему снэпшот-тестирования для обнаружения регрессий.

### Формат фикстур

Файлы `test/fixtures/*.json` -- массив объектов:

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

### Экспорт писем для тестов

Для создания фикстур из реальных данных, передайте `exportPath` при синхронизации:

```dart
add(SubscriptionSyncRequested(exportPath: '/path/to/save/'));
```

### Снэпшот-тестирование

Снэпшоты генерируются автоматически при первом запуске тестов. Для пересоздания после изменений парсера:

```bash
rm test/fixtures/*_snapshot.json
flutter test test/email_parser_integration_test.dart
# Или через standalone-скрипт
dart test/generate_snapshot.dart
```

## Зависимости

| Пакет | Назначение |
|-------|-----------|
| `google_sign_in` | Google Sign-In для авторизации |
| `googleapis` | Gmail API для чтения писем |
| `googleapis_auth` | OAuth2 аутентификация |
| `extension_google_sign_in_as_googleapis_auth` | Мост между google_sign_in и googleapis_auth |
| `flutter_bloc` | BLoC-паттерн для управления состоянием |
| `equatable` | Сравнение объектов по значению (модели, состояния) |
| `sqflite` | SQLite для локального хранения |
| `intl` | Форматирование дат на русском языке |
| `cached_network_image` | Кэширование сетевых изображений |
| `html` | Парсинг HTML-тела писем |

## Конфигурация OAuth

### Настройка Google Cloud

1. Создайте проект в [Google Cloud Console](https://console.cloud.google.com/)
2. Включите Gmail API
3. Настройте OAuth consent screen
4. Создайте OAuth 2.0 Client ID

### Android

Создайте OAuth Client ID для Android, добавьте SHA-1 fingerprint. Скачайте `google-services.json` и поместите в `android/app/`.

### iOS

Создайте OAuth Client ID для iOS. Скачайте `GoogleService-Info.plist` и поместите в `ios/Runner/`.

### Web

Client ID задан в `lib/services/auth_service.dart`. При необходимости замените на свой.

Необходимые OAuth scopes:
- `email`
- `https://www.googleapis.com/auth/gmail.readonly`

## Соглашения по коду

- **Именование файлов**: `snake_case.dart`
- **Именование классов**: `CamelCase`
- **Barrel-экспорты**: `blocs.dart`, `models.dart`, `services.dart`, `screens.dart`, `widgets.dart`
- **Equatable**: для моделей и BLoC-состояний
- **copyWith**: для иммутабельных обновлений состояния
- **toMap/fromMap**: для сериализации моделей в SQLite
- **Локализация**: весь интерфейс на русском языке
- **Material 3**: тема на основе `ColorScheme.fromSeed(seedColor: Colors.deepPurple)`

## Автор

Daniil

## Лицензия

MIT License
