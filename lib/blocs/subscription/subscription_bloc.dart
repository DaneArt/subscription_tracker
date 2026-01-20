import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/services.dart';
import '../../services/email_parser_isolate.dart';
import 'subscription_event.dart';
import 'subscription_state.dart';

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final DatabaseService _databaseService;
  final GmailService _gmailService;
  final EmailParserService _emailParserService;
  final AuthService _authService;

  SubscriptionBloc({
    required DatabaseService databaseService,
    required GmailService gmailService,
    required EmailParserService emailParserService,
    required AuthService authService,
  })  : _databaseService = databaseService,
        _gmailService = gmailService,
        _emailParserService = emailParserService,
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
    debugPrint('[SubscriptionBloc] Starting sync...');
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

      debugPrint('[SubscriptionBloc] Searching emails...');
      final emails = await _gmailService.searchSubscriptionEmails(
        batchSize: 10,
        maxTotal: 50,
        onProgress: (progress) {
          add(SubscriptionSyncProgressUpdated(progress));
        },
      );

      debugPrint('[SubscriptionBloc] Found ${emails.length} emails, parsing in isolates...');

      // Clear all existing subscriptions before sync
      await _databaseService.deleteAllSubscriptions();
      debugPrint('[SubscriptionBloc] Cleared existing subscriptions');

      emit(state.copyWith(
        syncProgress: SyncProgress(
          totalFound: emails.length,
          processed: 0,
          status: 'Анализ ${emails.length} писем...',
        ),
      ));

      // Convert emails to simple format for isolate
      final simpleEmails = emails.map(GmailService.toSimple).toList();

      // Process in batches using isolates
      const batchSize = 10;
      final allResults = <ParsedEmailResult>[];
      int processedCount = 0;

      for (var i = 0; i < simpleEmails.length; i += batchSize) {
        final batch = simpleEmails.skip(i).take(batchSize).toList();
        final batchIndex = i ~/ batchSize;

        // Parse batch in isolate
        final results = await compute(
          parseEmailBatch,
          EmailParseRequest(emails: batch, batchIndex: batchIndex),
        );

        allResults.addAll(results);
        processedCount += batch.length;

        emit(state.copyWith(
          syncProgress: SyncProgress(
            totalFound: emails.length,
            processed: processedCount,
            status: 'Анализ: $processedCount/${emails.length}',
          ),
        ));
      }

      debugPrint('[SubscriptionBloc] Parsed ${allResults.length} subscriptions from ${emails.length} emails');

      // Save unique subscriptions to database
      final addedServices = <String>{};
      int newCount = 0;

      for (final result in allResults) {
        // Skip subscriptions with no valid amount
        if (result.amount == null || result.amount! <= 0) {
          debugPrint('[SubscriptionBloc] Skipped ${result.serviceName} - no valid amount');
          continue;
        }

        // Skip if we already added this service (take first/most recent)
        if (addedServices.contains(result.serviceName)) {
          debugPrint('[SubscriptionBloc] Skipped ${result.serviceName} - already added');
          continue;
        }

        final subscription = result.toSubscription();
        await _databaseService.insertSubscription(subscription);
        addedServices.add(result.serviceName);
        newCount++;
        debugPrint('[SubscriptionBloc] Added: ${result.serviceName}');
      }

      final subscriptions = await _databaseService.getAllSubscriptions();
      final totalSpending = await _databaseService.getTotalMonthlySpending();

      debugPrint('[SubscriptionBloc] Sync complete. Added: $newCount subscriptions');
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
