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

  SubscriptionBloc({
    required DatabaseService databaseService,
    required GmailService gmailService,
    required EmailParserService emailParserService,
    required AuthService authService,
  })  : _databaseService = databaseService,
        _gmailService = gmailService,
        _authService = authService,
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
      final cancelled = await _databaseService.cancelInactiveSubscriptions();
      if (cancelled > 0) {
        debugPrint('[SubscriptionBloc] Auto-cancelled $cancelled inactive subscriptions');
      }
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
    debugPrint('[SubscriptionBloc] Starting email sync...');
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

      // Search for subscription emails
      debugPrint('[SubscriptionBloc] Searching for subscription emails...');
      emit(state.copyWith(
        syncProgress: const SyncProgress(status: 'Поиск писем о подписках...'),
      ));

      final emails = await _gmailService.searchSubscriptionEmails(
        maxTotal: 200,
        onProgress: (progress) {
          add(SubscriptionSyncProgressUpdated(progress));
        },
      );

      debugPrint('[SubscriptionBloc] Found ${emails.length} emails');

      emit(state.copyWith(
        syncProgress: SyncProgress(
          totalFound: emails.length,
          processed: 0,
          status: 'Анализ ${emails.length} писем...',
        ),
      ));

      // Parse emails in isolate batches
      final simpleEmails = emails.map(GmailService.toSimple).toList();
      final allParsed = <ParsedEmailResult>[];
      const batchSize = 10;

      for (var i = 0; i < simpleEmails.length; i += batchSize) {
        final batch = simpleEmails.skip(i).take(batchSize).toList();
        final results = await compute(
          parseEmailBatch,
          EmailParseRequest(emails: batch, batchIndex: i ~/ batchSize),
        );
        allParsed.addAll(results);

        emit(state.copyWith(
          syncProgress: SyncProgress(
            totalFound: emails.length,
            processed: i + batch.length,
            currentEmail: results.isNotEmpty ? results.last.serviceName : 'Обработка...',
            status: 'Обработано: ${i + batch.length}/${emails.length}',
          ),
        ));
      }

      debugPrint('[SubscriptionBloc] Parsed ${allParsed.length} subscriptions from emails');

      // Deduplicate: keep the most recent email per service
      final serviceMap = <String, ParsedEmailResult>{};
      for (final parsed in allParsed) {
        final existing = serviceMap[parsed.serviceName];
        if (existing == null) {
          serviceMap[parsed.serviceName] = parsed;
        } else {
          // Keep the one with more info (amount, later date)
          final existingDate = existing.lastPaymentDateIso != null
              ? DateTime.tryParse(existing.lastPaymentDateIso!)
              : null;
          final newDate = parsed.lastPaymentDateIso != null
              ? DateTime.tryParse(parsed.lastPaymentDateIso!)
              : null;
          if (newDate != null && (existingDate == null || newDate.isAfter(existingDate))) {
            serviceMap[parsed.serviceName] = parsed;
          }
        }
      }

      debugPrint('[SubscriptionBloc] Unique services: ${serviceMap.length}');

      // Update subscriptions in database
      emit(state.copyWith(
        syncProgress: const SyncProgress(status: 'Сохранение подписок...'),
      ));

      await _databaseService.deleteAllSubscriptions();

      for (final parsed in serviceMap.values) {
        final subscription = parsed.toSubscription();
        await _databaseService.insertSubscription(subscription);
        debugPrint('[SubscriptionBloc] Added: ${parsed.serviceName} - ${parsed.amount ?? 0} ${parsed.currency ?? ""}');
      }

      final cancelledCount = await _databaseService.cancelInactiveSubscriptions();
      if (cancelledCount > 0) {
        debugPrint('[SubscriptionBloc] Auto-cancelled $cancelledCount inactive subscriptions after sync');
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

}
