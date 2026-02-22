import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/subscription.dart';

class DatabaseService {
  static Database? _database;
  static const String _tableName = 'subscriptions';

  // In-memory storage for web
  static final List<Subscription> _webSubscriptions = [];
  static int _webIdCounter = 1;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'subscription_tracker.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        serviceName TEXT NOT NULL,
        serviceIcon TEXT,
        amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'RUB',
        nextBillingDate TEXT,
        lastPaymentDate TEXT,
        billingPeriod TEXT NOT NULL DEFAULT 'monthly',
        status TEXT NOT NULL DEFAULT 'active',
        category TEXT NOT NULL DEFAULT 'other',
        emailId TEXT,
        emailSubject TEXT,
        emailExcerpt TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_subscriptions_status ON $_tableName(status)
    ''');

    await db.execute('''
      CREATE INDEX idx_subscriptions_serviceName ON $_tableName(serviceName)
    ''');
  }

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN emailSubject TEXT');
      await db.execute('ALTER TABLE $_tableName ADD COLUMN emailExcerpt TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN lastPaymentDate TEXT');
    }
  }

  Future<int> insertSubscription(Subscription subscription) async {
    if (kIsWeb) {
      final id = _webIdCounter++;
      _webSubscriptions.add(subscription.copyWith(id: id));
      return id;
    }
    final db = await database;
    final map = subscription.toMap();
    map.remove('id');
    return await db.insert(_tableName, map);
  }

  Future<List<Subscription>> getAllSubscriptions() async {
    if (kIsWeb) {
      final sorted = List<Subscription>.from(_webSubscriptions);
      sorted.sort((a, b) {
        final dateCompare = (a.nextBillingDate ?? DateTime(2100))
            .compareTo(b.nextBillingDate ?? DateTime(2100));
        if (dateCompare != 0) return dateCompare;
        return a.serviceName.compareTo(b.serviceName);
      });
      return sorted;
    }
    final db = await database;
    final maps = await db.query(
      _tableName,
      orderBy: 'nextBillingDate ASC, serviceName ASC',
    );
    return maps.map((map) => Subscription.fromMap(map)).toList();
  }

  Future<List<Subscription>> getActiveSubscriptions() async {
    if (kIsWeb) {
      return _webSubscriptions
          .where((s) => s.status == SubscriptionStatus.active)
          .toList();
    }
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'nextBillingDate ASC, serviceName ASC',
    );
    return maps.map((map) => Subscription.fromMap(map)).toList();
  }

  Future<Subscription?> getSubscriptionById(int id) async {
    if (kIsWeb) {
      try {
        return _webSubscriptions.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    }
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Subscription.fromMap(maps.first);
  }

  Future<Subscription?> getSubscriptionByServiceName(String serviceName) async {
    if (kIsWeb) {
      try {
        return _webSubscriptions.firstWhere((s) => s.serviceName == serviceName);
      } catch (_) {
        return null;
      }
    }
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'serviceName = ?',
      whereArgs: [serviceName],
    );
    if (maps.isEmpty) return null;
    return Subscription.fromMap(maps.first);
  }

  Future<int> updateSubscription(Subscription subscription) async {
    if (kIsWeb) {
      final index = _webSubscriptions.indexWhere((s) => s.id == subscription.id);
      if (index != -1) {
        _webSubscriptions[index] = subscription;
        return 1;
      }
      return 0;
    }
    final db = await database;
    return await db.update(
      _tableName,
      subscription.toMap(),
      where: 'id = ?',
      whereArgs: [subscription.id],
    );
  }

  Future<int> deleteSubscription(int id) async {
    if (kIsWeb) {
      final lengthBefore = _webSubscriptions.length;
      _webSubscriptions.removeWhere((s) => s.id == id);
      return lengthBefore - _webSubscriptions.length;
    }
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllSubscriptions() async {
    if (kIsWeb) {
      final count = _webSubscriptions.length;
      _webSubscriptions.clear();
      return count;
    }
    final db = await database;
    return await db.delete(_tableName);
  }

  // Approximate exchange rates to RUB (can be updated)
  static const Map<String, double> _exchangeRates = {
    'RUB': 1.0,
    'USD': 90.0,  // 1 USD ≈ 90 RUB
    'EUR': 98.0,  // 1 EUR ≈ 98 RUB
    'GBP': 115.0, // 1 GBP ≈ 115 RUB
  };

  double _convertToRub(double amount, String currency) {
    final rate = _exchangeRates[currency] ?? 1.0;
    return amount * rate;
  }

  /// Отменяет подписки, у которых последний платёж был больше месяца назад.
  /// Годовые подписки не затрагиваются.
  Future<int> cancelInactiveSubscriptions() async {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month - 1, now.day);
    final cutoffIso = cutoff.toIso8601String();
    final nowIso = now.toIso8601String();

    if (kIsWeb) {
      var count = 0;
      for (var i = 0; i < _webSubscriptions.length; i++) {
        final s = _webSubscriptions[i];
        if (s.status == SubscriptionStatus.active &&
            s.billingPeriod != BillingPeriod.yearly &&
            s.lastPaymentDate != null &&
            s.lastPaymentDate!.isBefore(cutoff)) {
          _webSubscriptions[i] = s.copyWith(
            status: SubscriptionStatus.cancelled,
            updatedAt: now,
          );
          count++;
        }
      }
      return count;
    }

    final db = await database;
    return await db.rawUpdate(
      '''UPDATE $_tableName
         SET status = 'cancelled', updatedAt = ?
         WHERE status = 'active'
           AND billingPeriod != 'yearly'
           AND lastPaymentDate IS NOT NULL
           AND lastPaymentDate < ?''',
      [nowIso, cutoffIso],
    );
  }

  Future<List<Subscription>> getCancelledSubscriptions() async {
    if (kIsWeb) {
      return _webSubscriptions
          .where((s) => s.status == SubscriptionStatus.cancelled)
          .toList();
    }
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'status = ?',
      whereArgs: ['cancelled'],
      orderBy: 'lastPaymentDate DESC, serviceName ASC',
    );
    return maps.map((map) => Subscription.fromMap(map)).toList();
  }

  double _monthlyAmount(Subscription sub) {
    switch (sub.billingPeriod) {
      case BillingPeriod.monthly:
        return sub.amount;
      case BillingPeriod.yearly:
        return sub.amount / 12;
      case BillingPeriod.weekly:
        return sub.amount * 4.33;
      case BillingPeriod.unknown:
        return sub.amount;
    }
  }

  Future<double> getTotalMonthlySpending() async {
    final subscriptions = await getActiveSubscriptions();
    double total = 0;
    for (final sub in subscriptions) {
      total += _convertToRub(_monthlyAmount(sub), sub.currency);
    }
    return total;
  }

  Future<double> getTotalMonthlySavings() async {
    final subscriptions = await getCancelledSubscriptions();
    double total = 0;
    for (final sub in subscriptions) {
      total += _convertToRub(_monthlyAmount(sub), sub.currency);
    }
    return total;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
