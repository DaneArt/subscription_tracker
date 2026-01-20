import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/subscription.dart';

class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.serviceName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildCategoryChip(context),
                        const SizedBox(width: 8),
                        _buildStatusChip(context),
                      ],
                    ),
                    if (subscription.status == SubscriptionStatus.cancelled && subscription.lastPaymentDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Последний платёж: ${_formatDate(subscription.lastPaymentDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ] else if (subscription.nextBillingDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Следующее списание: ${_formatDate(subscription.nextBillingDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ] else if (subscription.lastPaymentDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Последний платёж: ${_formatDate(subscription.lastPaymentDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    subscription.formattedAmount,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: subscription.status == SubscriptionStatus.cancelled
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                          decoration: subscription.status == SubscriptionStatus.cancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                  ),
                  Text(
                    subscription.billingPeriod.displayName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final iconData = switch (subscription.category) {
      SubscriptionCategory.streaming => Icons.play_circle_outline,
      SubscriptionCategory.cloud => Icons.cloud_outlined,
      SubscriptionCategory.software => Icons.code,
      SubscriptionCategory.vpn => Icons.vpn_key_outlined,
      SubscriptionCategory.fitness => Icons.fitness_center,
      SubscriptionCategory.education => Icons.school_outlined,
      SubscriptionCategory.other => Icons.subscriptions_outlined,
    };

    final color = switch (subscription.category) {
      SubscriptionCategory.streaming => Colors.red,
      SubscriptionCategory.cloud => Colors.blue,
      SubscriptionCategory.software => Colors.purple,
      SubscriptionCategory.vpn => Colors.green,
      SubscriptionCategory.fitness => Colors.orange,
      SubscriptionCategory.education => Colors.teal,
      SubscriptionCategory.other => Colors.grey,
    };

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: color),
    );
  }

  Widget _buildCategoryChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        subscription.category.displayName,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final color = switch (subscription.status) {
      SubscriptionStatus.active => Colors.green,
      SubscriptionStatus.cancelled => Colors.red,
      SubscriptionStatus.paused => Colors.orange,
      SubscriptionStatus.unknown => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        subscription.status.displayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
            ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('d MMMM yyyy', 'ru').format(date);
  }
}
