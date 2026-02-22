import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../blocs/blocs.dart';
import '../models/subscription.dart';

class SubscriptionCalendarScreen extends StatefulWidget {
  const SubscriptionCalendarScreen({super.key});

  @override
  State<SubscriptionCalendarScreen> createState() =>
      _SubscriptionCalendarScreenState();
}

class _SubscriptionCalendarScreenState
    extends State<SubscriptionCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// Рассчитывает даты списаний для подписки в заданном диапазоне.
  List<DateTime> _getBillingDatesInRange(
    Subscription sub,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    if (sub.status != SubscriptionStatus.active) return [];

    final baseDate = sub.nextBillingDate ?? sub.lastPaymentDate;
    if (baseDate == null) return [];

    final dates = <DateTime>[];

    switch (sub.billingPeriod) {
      case BillingPeriod.weekly:
        // Находим первое вхождение в диапазон
        var current = baseDate;
        // Идём назад, если базовая дата после начала диапазона
        while (current.isAfter(rangeStart)) {
          current = current.subtract(const Duration(days: 7));
        }
        // Идём вперёд от найденной точки
        while (current.isBefore(rangeEnd)) {
          current = current.add(const Duration(days: 7));
          if (!current.isBefore(rangeStart) && !current.isAfter(rangeEnd)) {
            dates.add(DateTime(current.year, current.month, current.day));
          }
        }
        break;

      case BillingPeriod.monthly:
        // Для каждого месяца в диапазоне ставим ту же дату
        var month = DateTime(rangeStart.year, rangeStart.month);
        while (!month.isAfter(DateTime(rangeEnd.year, rangeEnd.month))) {
          final day = baseDate.day;
          final daysInMonth =
              DateTime(month.year, month.month + 1, 0).day;
          final billingDay = day > daysInMonth ? daysInMonth : day;
          final billingDate =
              DateTime(month.year, month.month, billingDay);
          if (!billingDate.isBefore(rangeStart) &&
              !billingDate.isAfter(rangeEnd)) {
            dates.add(billingDate);
          }
          month = DateTime(month.year, month.month + 1);
        }
        break;

      case BillingPeriod.yearly:
        for (var year = rangeStart.year; year <= rangeEnd.year; year++) {
          final day = baseDate.day;
          final daysInMonth =
              DateTime(year, baseDate.month + 1, 0).day;
          final billingDay = day > daysInMonth ? daysInMonth : day;
          final billingDate =
              DateTime(year, baseDate.month, billingDay);
          if (!billingDate.isBefore(rangeStart) &&
              !billingDate.isAfter(rangeEnd)) {
            dates.add(billingDate);
          }
        }
        break;

      case BillingPeriod.unknown:
        // Если период неизвестен, но есть nextBillingDate — показываем только её
        if (sub.nextBillingDate != null) {
          final d = DateTime(
            sub.nextBillingDate!.year,
            sub.nextBillingDate!.month,
            sub.nextBillingDate!.day,
          );
          if (!d.isBefore(rangeStart) && !d.isAfter(rangeEnd)) {
            dates.add(d);
          }
        }
        break;
    }

    return dates;
  }

  /// Строит карту: дата → список подписок, которые спишутся в этот день.
  Map<DateTime, List<Subscription>> _buildChargeMap(
    List<Subscription> subscriptions,
  ) {
    final now = DateTime.now();
    final rangeStart = DateTime(now.year - 1, now.month, 1);
    final rangeEnd = DateTime(now.year + 2, now.month, 0);

    final map = <DateTime, List<Subscription>>{};

    for (final sub in subscriptions) {
      final dates = _getBillingDatesInRange(sub, rangeStart, rangeEnd);
      for (final date in dates) {
        final key = DateTime(date.year, date.month, date.day);
        map.putIfAbsent(key, () => []).add(sub);
      }
    }

    return map;
  }

  List<Subscription> _getSubscriptionsForDay(
    DateTime day,
    Map<DateTime, List<Subscription>> chargeMap,
  ) {
    final key = DateTime(day.year, day.month, day.day);
    return chargeMap[key] ?? [];
  }

  double _getTotalForDay(List<Subscription> subs) {
    return subs.fold(0.0, (sum, s) => sum + s.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Календарь списаний'),
      ),
      body: BlocBuilder<SubscriptionBloc, SubscriptionState>(
        builder: (context, state) {
          final chargeMap = _buildChargeMap(state.activeSubscriptions);
          final selectedSubs = _selectedDay != null
              ? _getSubscriptionsForDay(_selectedDay!, chargeMap)
              : <Subscription>[];

          return Column(
            children: [
              TableCalendar<Subscription>(
                locale: 'ru_RU',
                firstDay: DateTime(DateTime.now().year - 1, 1, 1),
                lastDay: DateTime(DateTime.now().year + 2, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                startingDayOfWeek: StartingDayOfWeek.monday,
                selectedDayPredicate: (day) =>
                    _selectedDay != null && isSameDay(_selectedDay!, day),
                onDaySelected: (selectedDay, focusedDay) {
                  final subs =
                      _getSubscriptionsForDay(selectedDay, chargeMap);
                  if (subs.isNotEmpty) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  } else {
                    setState(() {
                      _selectedDay = null;
                      _focusedDay = focusedDay;
                    });
                  }
                },
                onFormatChanged: (format) {
                  setState(() => _calendarFormat = format);
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                eventLoader: (day) =>
                    _getSubscriptionsForDay(day, chargeMap),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withAlpha((0.3 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  markerDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  markerSize: 6,
                  markersMaxCount: 3,
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonDecoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  formatButtonTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                calendarBuilders: CalendarBuilders<Subscription>(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return null;
                    final total = _getTotalForDay(events);
                    return Positioned(
                      bottom: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${total.toStringAsFixed(0)}\u20BD',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedDay != null && selectedSubs.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('d MMMM yyyy', 'ru').format(_selectedDay!),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '-${_getTotalForDay(selectedSubs).toStringAsFixed(0)} \u20BD',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: selectedSubs.length,
                    itemBuilder: (context, index) {
                      final sub = selectedSubs[index];
                      return _buildChargeItem(context, sub);
                    },
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Нажмите на дату со списанием',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildChargeItem(BuildContext context, Subscription sub) {
    final iconData = switch (sub.category) {
      SubscriptionCategory.streaming => Icons.play_circle_outline,
      SubscriptionCategory.cloud => Icons.cloud_outlined,
      SubscriptionCategory.software => Icons.code,
      SubscriptionCategory.vpn => Icons.vpn_key_outlined,
      SubscriptionCategory.fitness => Icons.fitness_center,
      SubscriptionCategory.education => Icons.school_outlined,
      SubscriptionCategory.other => Icons.subscriptions_outlined,
    };

    final color = switch (sub.category) {
      SubscriptionCategory.streaming => Colors.red,
      SubscriptionCategory.cloud => Colors.blue,
      SubscriptionCategory.software => Colors.purple,
      SubscriptionCategory.vpn => Colors.green,
      SubscriptionCategory.fitness => Colors.orange,
      SubscriptionCategory.education => Colors.teal,
      SubscriptionCategory.other => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.serviceName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    sub.billingPeriod.displayName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            Text(
              sub.formattedAmount,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
