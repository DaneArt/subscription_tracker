import 'package:equatable/equatable.dart';
import '../../models/subscription.dart';
import '../../services/gmail_service.dart';

enum SubscriptionLoadStatus { initial, loading, success, failure }

class SubscriptionState extends Equatable {
  final SubscriptionLoadStatus status;
  final List<Subscription> subscriptions;
  final double totalMonthlySpending;
  final double totalMonthlySavings;
  final String? error;
  final bool isSyncing;
  final SyncProgress? syncProgress;

  const SubscriptionState({
    this.status = SubscriptionLoadStatus.initial,
    this.subscriptions = const [],
    this.totalMonthlySpending = 0,
    this.totalMonthlySavings = 0,
    this.error,
    this.isSyncing = false,
    this.syncProgress,
  });

  SubscriptionState copyWith({
    SubscriptionLoadStatus? status,
    List<Subscription>? subscriptions,
    double? totalMonthlySpending,
    double? totalMonthlySavings,
    String? error,
    bool? isSyncing,
    SyncProgress? syncProgress,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      subscriptions: subscriptions ?? this.subscriptions,
      totalMonthlySpending: totalMonthlySpending ?? this.totalMonthlySpending,
      totalMonthlySavings: totalMonthlySavings ?? this.totalMonthlySavings,
      error: error ?? this.error,
      isSyncing: isSyncing ?? this.isSyncing,
      syncProgress: syncProgress ?? this.syncProgress,
    );
  }

  List<Subscription> get activeSubscriptions =>
      subscriptions.where((s) => s.status == SubscriptionStatus.active).toList();

  List<Subscription> get cancelledSubscriptions =>
      subscriptions.where((s) => s.status == SubscriptionStatus.cancelled).toList();

  @override
  List<Object?> get props => [status, subscriptions, totalMonthlySpending, totalMonthlySavings, error, isSyncing, syncProgress];
}
