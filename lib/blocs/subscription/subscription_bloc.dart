import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'subscription_event.dart';
import 'subscription_state.dart';

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final DatabaseService _databaseService;
  final GmailService _gmailService;
  final AuthService _authService;
  final SmsParserService _smsParserService;

  SubscriptionBloc({
    required DatabaseService databaseService,
    required GmailService gmailService,
    required EmailParserService emailParserService, // kept for API compatibility
    required AuthService authService,
    SmsParserService? smsParserService,
  })  : _databaseService = databaseService,
        _gmailService = gmailService,
        _authService = authService,
        _smsParserService = smsParserService ?? SmsParserService(),
        super(const SubscriptionState()) {
    on<SubscriptionLoadRequested>(_onLoadRequested);
    on<SubscriptionSyncRequested>(_onSyncRequested);
    on<SubscriptionAdded>(_onAdded);
    on<SubscriptionUpdated>(_onUpdated);
    on<SubscriptionDeleted>(_onDeleted);
    on<SubscriptionDeleteAllRequested>(_onDeleteAllRequested);
    on<SubscriptionSyncProgressUpdated>(_onSyncProgressUpdated);
  }

  Future<void> _onLoadRequested(
    SubscriptionLoadRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    debugPrint('[SubscriptionBloc] Loading subscriptions...');
    emit(state.copyWith(status: SubscriptionLoadStatus.loading));
    try {
      final subscriptions = await _databaseService.getAllSubscriptions();
      final totalSpending = await _databaseService.getTotalMonthlySpending();
      debugPrint('[SubscriptionBloc] Loaded ${subscriptions.length} subscriptions');
      emit(state.copyWith(
        status: SubscriptionLoadStatus.success,
        subscriptions: subscriptions,
        totalMonthlySpending: totalSpending,
      ));
    } catch (e) {
      debugPrint('[SubscriptionBloc] Error loading: $e');
      emit(state.copyWith(
        status: SubscriptionLoadStatus.failure,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onSyncRequested(
    SubscriptionSyncRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    debugPrint('[SubscriptionBloc] Starting SMS sync...');
    emit(state.copyWith(
      isSyncing: true,
      syncProgress: const SyncProgress(status: 'Авторизация...'),
    ));

    try {
      final authClient = await _authService.getAuthClient();
      if (authClient == null) {
        debugPrint('[SubscriptionBloc] Auth failed');
        emit(state.copyWith(
          isSyncing: false,
          syncProgress: null,
          error: 'Не удалось авторизоваться',
        ));
        return;
      }

      debugPrint('[SubscriptionBloc] Auth successful, initializing Gmail...');
      await _gmailService.init(authClient);

      // Search for SMS emails forwarded from phone
      debugPrint('[SubscriptionBloc] Searching for SMS emails...');
      emit(state.copyWith(
        syncProgress: const SyncProgress(status: 'Поиск SMS писем...'),
      ));

      final smsEmails = await _gmailService.searchSmsEmails(
        subjectPrefix: 'RAIFEISEN',
        maxResults: 500,
        onProgress: (progress) {
          add(SubscriptionSyncProgressUpdated(progress));
        },
      );

      debugPrint('[SubscriptionBloc] Found ${smsEmails.length} SMS emails');

      emit(state.copyWith(
        syncProgress: SyncProgress(
          totalFound: smsEmails.length,
          processed: 0,
          status: 'Обработка ${smsEmails.length} SMS...',
        ),
      ));

      // Parse SMS emails and save transactions
      int newTransactions = 0;
      int processed = 0;

      for (final email in smsEmails) {
        processed++;
        final body = email.body ?? email.snippet ?? '';

        // Check if this SMS was already processed
        if (await _databaseService.transactionExists(body)) {
          continue;
        }

        // Parse the SMS
        final transaction = _smsParserService.parseFromEmail(
          body,
          emailDate: email.date,
        );

        if (transaction != null) {
          await _databaseService.insertTransaction(transaction);
          newTransactions++;
          debugPrint('[SubscriptionBloc] Saved: ${transaction.merchant} - ${transaction.amount} ${transaction.currency}');
        }

        emit(state.copyWith(
          syncProgress: SyncProgress(
            totalFound: smsEmails.length,
            processed: processed,
            currentEmail: transaction?.merchant ?? 'Обработка...',
            status: 'Обработано: $processed/${smsEmails.length}',
          ),
        ));
      }

      debugPrint('[SubscriptionBloc] Saved $newTransactions new transactions');

      // Detect subscriptions from all transactions
      emit(state.copyWith(
        syncProgress: const SyncProgress(status: 'Анализ подписок...'),
      ));

      final allTransactions = await _databaseService.getAllTransactions();
      final detectedSubscriptions = _smsParserService.detectSubscriptions(
        allTransactions,
        minOccurrences: 2,
      );

      debugPrint('[SubscriptionBloc] Detected ${detectedSubscriptions.length} subscriptions');

      // Update subscriptions in database
      await _databaseService.deleteAllSubscriptions();

      for (final detected in detectedSubscriptions) {
        final subscription = _convertDetectedToSubscription(detected);
        await _databaseService.insertSubscription(subscription);
        debugPrint('[SubscriptionBloc] Added subscription: ${detected.merchant}');
      }

      final subscriptions = await _databaseService.getAllSubscriptions();
      final totalSpending = await _databaseService.getTotalMonthlySpending();

      debugPrint('[SubscriptionBloc] Sync complete. Subscriptions: ${subscriptions.length}');
      emit(state.copyWith(
        isSyncing: false,
        syncProgress: null,
        subscriptions: subscriptions,
        totalMonthlySpending: totalSpending,
        status: SubscriptionLoadStatus.success,
      ));
    } catch (e) {
      debugPrint('[SubscriptionBloc] Sync error: $e');
      emit(state.copyWith(
        isSyncing: false,
        syncProgress: null,
        error: e.toString(),
      ));
    }
  }

  void _onSyncProgressUpdated(
    SubscriptionSyncProgressUpdated event,
    Emitter<SubscriptionState> emit,
  ) {
    emit(state.copyWith(syncProgress: event.progress));
  }

  Future<void> _onAdded(
    SubscriptionAdded event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      await _databaseService.insertSubscription(event.subscription);
      add(const SubscriptionLoadRequested());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUpdated(
    SubscriptionUpdated event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      await _databaseService.updateSubscription(event.subscription);
      add(const SubscriptionLoadRequested());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleted(
    SubscriptionDeleted event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      await _databaseService.deleteSubscription(event.id);
      add(const SubscriptionLoadRequested());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleteAllRequested(
    SubscriptionDeleteAllRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      await _databaseService.deleteAllSubscriptions();
      add(const SubscriptionLoadRequested());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Subscription _convertDetectedToSubscription(DetectedSubscription detected) {
    // Determine billing period from average interval
    BillingPeriod period = BillingPeriod.monthly;
    if (detected.averageInterval != null) {
      final days = detected.averageInterval!.inDays;
      if (days >= 355 && days <= 375) {
        period = BillingPeriod.yearly;
      } else if (days >= 6 && days <= 8) {
        period = BillingPeriod.weekly;
      }
    }

    // Calculate next billing date
    DateTime? nextBilling;
    if (detected.averageInterval != null) {
      nextBilling = detected.lastDate.add(detected.averageInterval!);
      // If next billing is in the past, calculate the next future date
      while (nextBilling!.isBefore(DateTime.now())) {
        nextBilling = nextBilling.add(detected.averageInterval!);
      }
    }

    return Subscription(
      serviceName: detected.merchant,
      amount: detected.amount,
      currency: detected.currency,
      billingPeriod: period,
      nextBillingDate: nextBilling,
      lastPaymentDate: detected.lastDate,
      status: SubscriptionStatus.active,
      category: _categorizeService(detected.merchant),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  SubscriptionCategory _categorizeService(String merchant) {
    final upper = merchant.toUpperCase();

    // Streaming/Entertainment
    if (upper.contains('NETFLIX') ||
        upper.contains('SPOTIFY') ||
        upper.contains('YOUTUBE') ||
        upper.contains('APPLE.COM') ||
        upper.contains('APPLE COM') ||
        upper.contains('STEAM') ||
        upper.contains('PLAYSTATION') ||
        upper.contains('XBOX') ||
        upper.contains('NINTENDO')) {
      return SubscriptionCategory.streaming;
    }

    // Software/Tools
    if (upper.contains('ANTHROPIC') ||
        upper.contains('CLAUDE') ||
        upper.contains('OPENAI') ||
        upper.contains('CHATGPT') ||
        upper.contains('CURSOR') ||
        upper.contains('GITHUB') ||
        upper.contains('JETBRAINS') ||
        upper.contains('ADOBE') ||
        upper.contains('FIGMA') ||
        upper.contains('NOTION') ||
        upper.contains('OBSIDIAN') ||
        upper.contains('N8N')) {
      return SubscriptionCategory.software;
    }

    // Cloud/Storage
    if (upper.contains('GOOGLE') ||
        upper.contains('MICROSOFT') ||
        upper.contains('DROPBOX') ||
        upper.contains('ICLOUD')) {
      return SubscriptionCategory.cloud;
    }

    // VPN/Security
    if (upper.contains('NORDVPN') ||
        upper.contains('EXPRESSVPN') ||
        upper.contains('VPN')) {
      return SubscriptionCategory.vpn;
    }

    // Fitness
    if (upper.contains('STRAVA') ||
        upper.contains('NIKE') ||
        upper.contains('FITBIT')) {
      return SubscriptionCategory.fitness;
    }

    // Education
    if (upper.contains('DUOLINGO') ||
        upper.contains('COURSERA') ||
        upper.contains('UDEMY')) {
      return SubscriptionCategory.education;
    }

    return SubscriptionCategory.other;
  }
}
