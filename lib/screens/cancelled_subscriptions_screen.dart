import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../widgets/widgets.dart';

class CancelledSubscriptionsScreen extends StatelessWidget {
  const CancelledSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отменённые подписки'),
      ),
      body: BlocBuilder<SubscriptionBloc, SubscriptionState>(
        builder: (context, state) {
          final cancelled = state.cancelledSubscriptions;

          if (cancelled.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Нет отменённых подписок',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildSavingsCard(context, state.totalMonthlySavings),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final subscription = cancelled[index];
                    return Dismissible(
                      key: Key('cancelled_${subscription.id}'),
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
                  childCount: cancelled.length,
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSavingsCard(BuildContext context, double totalMonthlySavings) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade600,
            Colors.green.shade400,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha((0.3 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Экономия в месяц',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${totalMonthlySavings.toStringAsFixed(0)} \u20BD',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStat(
                context,
                'В год',
                '${(totalMonthlySavings * 12).toStringAsFixed(0)} \u20BD',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white60,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
