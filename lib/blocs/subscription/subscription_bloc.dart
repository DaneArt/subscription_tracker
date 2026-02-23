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
      final totalSavings = await _databaseService.getTotalMonthlySavings();
      debugPrint('[SubscriptionBloc] Loaded ${subscriptions.length} subscriptions');
      emit(state.copyWith(
        status: SubscriptionLoadStatus.success,
        subscriptions: subscriptions,
        totalMonthlySpending: totalSpending,
        totalMonthlySavings: totalSavings,
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

      // Export raw emails for integration testing if exportPath is provided
      if (event.exportPath != null) {
        debugPrint('[SubscriptionBloc] Exporting emails to ${event.exportPath}...');
        await EmailExportService.exportToJson(
          emails: emails,
          directory: event.exportPath!,
        );
      }

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

      // Deduplicate parsed results into distinct subscriptions.
      // Two payments for the same service in the same month on different
      // dates = two separate subscriptions (e.g. personal + family plan).
      // Payments in different months = recurring charges for one subscription.
      final deduped = _deduplicateSubscriptions(allParsed);

      debugPrint('[SubscriptionBloc] Unique subscriptions: ${deduped.length}');

      // Update subscriptions in database
      emit(state.copyWith(
        syncProgress: const SyncProgress(status: 'Сохранение подписок...'),
      ));

      await _databaseService.deleteAllSubscriptions();

      for (final parsed in deduped) {
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
      final totalSavings = await _databaseService.getTotalMonthlySavings();

      debugPrint('[SubscriptionBloc] Sync complete. Subscriptions: ${subscriptions.length}');
      emit(state.copyWith(
        isSyncing: false,
        syncProgress: null,
        subscriptions: subscriptions,
        totalMonthlySpending: totalSpending,
        totalMonthlySavings: totalSavings,
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

  /// Detects distinct subscriptions from a flat list of parsed emails.
  ///
  /// Logic: group by normalized service name, then check how many payments
  /// fall on different dates within the same calendar month. If a single
  /// month has N distinct payment dates for one service, that means the
  /// user has N concurrent subscriptions (e.g. personal + family plan).
  /// Payments across different months are recurring charges for the same
  /// subscription and get merged (keep the newest).
  static List<ParsedEmailResult> _deduplicateSubscriptions(
    List<ParsedEmailResult> allParsed,
  ) {
    // 1. Group by normalized service name
    final groups = <String, List<ParsedEmailResult>>{};
    for (final p in allParsed) {
      final key = p.serviceName.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');
      groups.putIfAbsent(key, () => []).add(p);
    }

    final result = <ParsedEmailResult>[];

    for (final entries in groups.values) {
      // Prefer the canonical name (from known services, usually has spaces)
      final canonicalName = entries
          .map((e) => e.serviceName)
          .firstWhere((n) => n.contains(' '), orElse: () => entries.first.serviceName);

      // 2. Group by calendar month
      final byMonth = <String, List<ParsedEmailResult>>{};
      for (final e in entries) {
        final d = e.lastPaymentDateIso != null
            ? DateTime.tryParse(e.lastPaymentDateIso!)
            : null;
        final mk = d != null
            ? '${d.year}-${d.month.toString().padLeft(2, '0')}'
            : 'unknown';
        byMonth.putIfAbsent(mk, () => []).add(e);
      }

      // 3. Count distinct payment dates per month → max = subscription count
      int subscriptionCount = 1;
      String? anchorMonth;
      for (final me in byMonth.entries) {
        final uniqueDates = me.value.map((e) {
          final d = e.lastPaymentDateIso != null
              ? DateTime.tryParse(e.lastPaymentDateIso!)
              : null;
          return d != null ? '${d.year}-${d.month}-${d.day}' : null;
        }).whereType<String>().toSet();
        if (uniqueDates.length > subscriptionCount) {
          subscriptionCount = uniqueDates.length;
          anchorMonth = me.key;
        }
      }

      // Sort all entries newest-first
      entries.sort((a, b) =>
          (b.lastPaymentDateIso ?? '').compareTo(a.lastPaymentDateIso ?? ''));

      if (subscriptionCount <= 1) {
        // Single subscription — just keep the newest entry
        result.add(_withName(entries.first, canonicalName));
      } else {
        // Multiple concurrent subscriptions detected.
        // Use entries from the anchor month as subscription "slots",
        // then for each slot find the newest payment across all months
        // matching by similar amount (±30 %).
        final anchors = <ParsedEmailResult>[];
        final seenDates = <String>{};
        for (final e in byMonth[anchorMonth]!) {
          final d = e.lastPaymentDateIso != null
              ? DateTime.tryParse(e.lastPaymentDateIso!)
              : null;
          final dk = d != null ? '${d.year}-${d.month}-${d.day}' : 'u${anchors.length}';
          if (!seenDates.contains(dk)) {
            seenDates.add(dk);
            anchors.add(e);
          }
        }

        final usedIds = <String>{};
        for (final anchor in anchors) {
          final anchorAmount = anchor.amount ?? 0;
          ParsedEmailResult best = anchor;

          for (final e in entries) {
            if (usedIds.contains(e.emailId)) continue;
            final cmp = (e.lastPaymentDateIso ?? '').compareTo(best.lastPaymentDateIso ?? '');
            if (cmp <= 0) continue; // not newer
            final eAmount = e.amount ?? 0;
            if (anchorAmount > 0 && eAmount > 0) {
              final ratio = eAmount / anchorAmount;
              if (ratio < 0.7 || ratio > 1.3) continue; // amount mismatch
            }
            best = e;
          }

          usedIds.add(best.emailId);
          result.add(_withName(best, canonicalName));
        }
      }
    }

    return result;
  }

  /// Returns a copy of [entry] with the given [name].
  static ParsedEmailResult _withName(ParsedEmailResult entry, String name) {
    if (entry.serviceName == name) return entry;
    return ParsedEmailResult(
      serviceName: name,
      amount: entry.amount,
      currency: entry.currency,
      billingDateIso: entry.billingDateIso,
      lastPaymentDateIso: entry.lastPaymentDateIso,
      billingPeriod: entry.billingPeriod,
      category: entry.category,
      isCancelled: entry.isCancelled,
      emailId: entry.emailId,
      emailSubject: entry.emailSubject,
      emailExcerpt: entry.emailExcerpt,
    );
  }

}
