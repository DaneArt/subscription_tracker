import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/subscription/subscription.dart';
import '../models/subscription.dart';

class AddSubscriptionScreen extends StatefulWidget {
  const AddSubscriptionScreen({super.key});

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  String _currency = 'RUB';
  BillingPeriod _billingPeriod = BillingPeriod.monthly;
  SubscriptionCategory _category = SubscriptionCategory.other;
  DateTime? _nextBillingDate;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить подписку'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название сервиса',
                hintText: 'Например: Netflix',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите название';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Сумма',
                      hintText: '199',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите сумму';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Некорректная сумма';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: const InputDecoration(
                      labelText: 'Валюта',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'RUB', child: Text('\u20BD')),
                      DropdownMenuItem(value: 'USD', child: Text('\$')),
                      DropdownMenuItem(value: 'EUR', child: Text('\u20AC')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _currency = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BillingPeriod>(
              value: _billingPeriod,
              decoration: const InputDecoration(
                labelText: 'Период списания',
                border: OutlineInputBorder(),
              ),
              items: BillingPeriod.values
                  .where((p) => p != BillingPeriod.unknown)
                  .map((period) => DropdownMenuItem(
                        value: period,
                        child: Text(period.displayName),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _billingPeriod = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SubscriptionCategory>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Категория',
                border: OutlineInputBorder(),
              ),
              items: SubscriptionCategory.values
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.displayName),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _category = value);
                }
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Дата следующего списания'),
              subtitle: Text(
                _nextBillingDate != null
                    ? '${_nextBillingDate!.day}.${_nextBillingDate!.month}.${_nextBillingDate!.year}'
                    : 'Не указана',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saveSubscription,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _nextBillingDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) {
      setState(() => _nextBillingDate = date);
    }
  }

  void _saveSubscription() {
    if (_formKey.currentState!.validate()) {
      final now = DateTime.now();
      final subscription = Subscription(
        serviceName: _nameController.text,
        amount: double.parse(_amountController.text),
        currency: _currency,
        billingPeriod: _billingPeriod,
        category: _category,
        nextBillingDate: _nextBillingDate,
        status: SubscriptionStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      context.read<SubscriptionBloc>().add(SubscriptionAdded(subscription));
      Navigator.of(context).pop();
    }
  }
}
