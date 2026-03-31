import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../widgets/widgets.dart';
import 'cancelled_subscriptions_screen.dart';
import 'subscription_calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SubscriptionBloc>().add(const SubscriptionLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои подписки'),
        actions: [
          BlocBuilder<SubscriptionBloc, SubscriptionState>(
            builder: (context, state) {
              if (state.isSyncing) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.sync),
                tooltip: 'Синхронизировать с почтой',
                onPressed: () {
                  context
                      .read<SubscriptionBloc>()
                      .add(const SubscriptionSyncRequested());
                },
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                context.read<AuthBloc>().add(const AuthSignOutRequested());
              } else if (value == 'clear_all') {
                _showClearAllDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep),
                    SizedBox(width: 8),
                    Text('Очистить всё'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Выйти'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == SubscriptionLoadStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final active = state.activeSubscriptions;
          final cancelledCount = state.cancelledSubscriptions.length;

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<SubscriptionBloc>()
                  .add(const SubscriptionSyncRequested());
              await Future.delayed(const Duration(seconds: 2));
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: TotalSpendingCard(
                    totalMonthly: state.totalMonthlySpending,
                    subscriptionCount: active.length,
                  ),
                ),
                // Progress indicator
                if (state.isSyncing && state.syncProgress != null)
                  SliverToBoxAdapter(
                    child: _buildSyncProgressCard(context, state.syncProgress!),
                  ),
                if (cancelledCount > 0)
                  SliverToBoxAdapter(
                    child: _buildCancelledBanner(
                      context,
                      cancelledCount,
                      state.totalMonthlySavings,
                    ),
                  ),
                if (active.isEmpty && !state.isSyncing)
                  SliverFillRemaining(
                    child: _buildEmptyState(context),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final subscription = active[index];
                        return Dismissible(
                          key: Key('subscription_${subscription.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Удалить подписку?'),
                                content: Text(
                                  'Вы уверены, что хотите удалить ${subscription.serviceName}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Отмена'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Удалить'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) {
                            context
                                .read<SubscriptionBloc>()
                                .add(SubscriptionDeleted(subscription.id!));
                          },
                          child: SubscriptionCard(
                            subscription: subscription,
                            onTap: () {
                              SubscriptionDetailSheet.show(context, subscription);
                            },
                          ),
                        );
                      },
                      childCount: active.length,
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCalendar(context),
        icon: const Icon(Icons.calendar_month),
        label: const Text('Календарь'),
      ),
    );
  }

  Widget _buildCancelledBanner(
    BuildContext context,
    int count,
    double totalMonthlySavings,
  ) {
    final savingsText = '${totalMonthlySavings.toStringAsFixed(0)} \u20BD/мес';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.green.shade50,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CancelledSubscriptionsScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.savings_outlined, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Отменённые подписки: $count',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.green.shade900,
                          ),
                    ),
                    Text(
                      'Экономия: $savingsText',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade700,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.green.shade700),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncProgressCard(BuildContext context, dynamic progress) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    progress.status,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (progress.totalFound > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress.percentage,
                backgroundColor: Colors.grey[200],
              ),
              const SizedBox(height: 8),
              Text(
                '${progress.processed} / ${progress.totalFound}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
            if (progress.currentEmail != null) ...[
              const SizedBox(height: 4),
              Text(
                progress.currentEmail!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Нет подписок',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Нажмите кнопку синхронизации, чтобы\nнайти подписки в вашей почте',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                context
                    .read<SubscriptionBloc>()
                    .add(const SubscriptionSyncRequested());
              },
              icon: const Icon(Icons.sync),
              label: const Text('Синхронизировать'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCalendar(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubscriptionCalendarScreen(),
      ),
    );
  }

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить все подписки?'),
        content: const Text(
          'Все подписки будут удалены. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              context
                  .read<SubscriptionBloc>()
                  .add(const SubscriptionDeleteAllRequested());
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить всё'),
          ),
        ],
      ),
    );
  }
}
