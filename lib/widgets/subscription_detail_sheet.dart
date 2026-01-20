import 'package:flutter/material.dart';
import '../models/subscription.dart';

class SubscriptionDetailSheet extends StatelessWidget {
  final Subscription subscription;

  const SubscriptionDetailSheet({
    super.key,
    required this.subscription,
  });

  static Future<void> show(BuildContext context, Subscription subscription) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SubscriptionDetailSheet(subscription: subscription),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          subscription.serviceName.isNotEmpty
                              ? subscription.serviceName[0].toUpperCase()
                              : '?',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subscription.serviceName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            subscription.category.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          subscription.formattedAmount,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: subscription.status == SubscriptionStatus.cancelled
                                ? Colors.grey
                                : theme.colorScheme.primary,
                            decoration: subscription.status == SubscriptionStatus.cancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (subscription.status == SubscriptionStatus.cancelled)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Отменена',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subscription.billingPeriod.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),

                const Divider(height: 32),

                // Email Subject
                if (subscription.emailSubject != null) ...[
                  _buildSectionTitle(context, 'Тема письма'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      subscription.emailSubject!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Email Excerpt
                if (subscription.emailExcerpt != null) ...[
                  _buildSectionTitle(context, 'Информация об оплате'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withAlpha(50),
                      ),
                    ),
                    child: Text(
                      subscription.emailExcerpt!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // No email info
                if (subscription.emailSubject == null &&
                    subscription.emailExcerpt == null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[500]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Информация из письма недоступна.\nПодписка была добавлена вручную или до обновления приложения.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Payment Dates
                _buildSectionTitle(context, 'Даты платежей'),
                const SizedBox(height: 12),
                if (subscription.lastPaymentDate != null)
                  _buildInfoRow(
                    context,
                    'Последний платёж',
                    _formatDate(subscription.lastPaymentDate!),
                    Icons.history,
                  ),
                if (subscription.nextBillingDate != null)
                  _buildInfoRow(
                    context,
                    'Следующее списание',
                    _formatDate(subscription.nextBillingDate!),
                    Icons.calendar_today_outlined,
                  ),
                if (subscription.lastPaymentDate == null && subscription.nextBillingDate == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.grey[500]),
                        const SizedBox(width: 12),
                        Text(
                          'Даты не определены',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Additional Info
                _buildSectionTitle(context, 'Дополнительно'),
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  'Статус',
                  subscription.status.displayName,
                  subscription.status == SubscriptionStatus.cancelled
                      ? Icons.cancel_outlined
                      : Icons.check_circle_outline,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
