import 'package:equatable/equatable.dart';
import '../../models/subscription.dart';
import '../../services/gmail_service.dart';

abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

class SubscriptionLoadRequested extends SubscriptionEvent {
  const SubscriptionLoadRequested();
}

class SubscriptionSyncRequested extends SubscriptionEvent {
  const SubscriptionSyncRequested();
}

class SubscriptionAdded extends SubscriptionEvent {
  final Subscription subscription;

  const SubscriptionAdded(this.subscription);

  @override
  List<Object?> get props => [subscription];
}

class SubscriptionUpdated extends SubscriptionEvent {
  final Subscription subscription;

  const SubscriptionUpdated(this.subscription);

  @override
  List<Object?> get props => [subscription];
}

class SubscriptionDeleted extends SubscriptionEvent {
  final int id;

  const SubscriptionDeleted(this.id);

  @override
  List<Object?> get props => [id];
}

class SubscriptionDeleteAllRequested extends SubscriptionEvent {
  const SubscriptionDeleteAllRequested();
}

class SubscriptionSyncProgressUpdated extends SubscriptionEvent {
  final SyncProgress progress;

  const SubscriptionSyncProgressUpdated(this.progress);

  @override
  List<Object?> get props => [progress];
}
