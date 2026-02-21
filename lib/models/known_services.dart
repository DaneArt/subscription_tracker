import 'subscription.dart';

class PriceRange {
  final double min;
  final double max;

  const PriceRange(this.min, this.max);

  bool contains(double amount) => amount >= min && amount <= max;
}

class KnownService {
  final String name;
  final List<String> emailPatterns;
  final List<String> subjectPatterns;
  final SubscriptionCategory category;
  final String? iconUrl;
  // Typical monthly price ranges per currency
  final Map<String, PriceRange> typicalPrices;
  // Keywords that appear near the subscription amount in emails
  final List<String> amountContextPatterns;

  const KnownService({
    required this.name,
    required this.emailPatterns,
    this.subjectPatterns = const [],
    required this.category,
    this.iconUrl,
    this.typicalPrices = const {},
    this.amountContextPatterns = const [],
  });

  bool isTypicalAmount(double amount, String currency) {
    final range = typicalPrices[currency];
    if (range == null) return true; // No range defined, accept any
    return range.contains(amount);
  }
}

const knownServices = [
  // Streaming
  KnownService(
    name: 'Netflix',
    emailPatterns: ['@netflix.com'],
    subjectPatterns: ['netflix membership', 'netflix subscription', 'netflix payment', 'оплата netflix', 'ваша подписка netflix'],
    category: SubscriptionCategory.streaming,
    typicalPrices: {
      'RUB': PriceRange(399, 2500),
      'USD': PriceRange(6.99, 25),
      'EUR': PriceRange(5.99, 20),
      'RSD': PriceRange(500, 3000),
    },
    amountContextPatterns: ['membership', 'подписка', 'план', 'plan', 'ежемесячн', 'payment', 'charged'],
  ),
  KnownService(
    name: 'Spotify',
    emailPatterns: ['spotify.com', 'spotify'],
    subjectPatterns: ['spotify', 'spotify premium'],
    category: SubscriptionCategory.streaming,
    typicalPrices: {
      'RUB': PriceRange(99, 500),
      'USD': PriceRange(4.99, 20),
      'EUR': PriceRange(4.99, 18),
      'RSD': PriceRange(300, 1500),
    },
    amountContextPatterns: ['premium', 'подписка', 'subscription'],
  ),
  KnownService(
    name: 'YouTube Premium',
    emailPatterns: ['youtube.com', 'payments-noreply@google.com', 'googleplay-noreply@google.com'],
    subjectPatterns: ['youtube premium', 'youtube music', 'youtube membership', 'подписка youtube', 'your google play order'],
    category: SubscriptionCategory.streaming,
    typicalPrices: {
      'RUB': PriceRange(199, 600),
      'USD': PriceRange(9.99, 25),
      'EUR': PriceRange(9.99, 22),
      'RSD': PriceRange(400, 2000),
    },
    amountContextPatterns: ['youtube', 'premium', 'membership', 'подписка'],
  ),
  KnownService(
    name: 'Apple Music',
    emailPatterns: ['apple.com', 'itunes'],
    subjectPatterns: ['apple music', 'apple one'],
    category: SubscriptionCategory.streaming,
    typicalPrices: {
      'RUB': PriceRange(99, 400),
      'USD': PriceRange(5.99, 17),
      'EUR': PriceRange(5.99, 17),
    },
    amountContextPatterns: ['apple music', 'подписка', 'subscription', 'ежемесячн'],
  ),
  KnownService(
    name: 'Яндекс Плюс',
    emailPatterns: ['plus.yandex', 'passport.yandex'],
    subjectPatterns: ['яндекс плюс', 'яндекс.плюс', 'yandex plus', 'подписка плюс'],
    category: SubscriptionCategory.streaming,
    typicalPrices: {
      'RUB': PriceRange(99, 500),
    },
    amountContextPatterns: ['плюс', 'подписка', 'списан'],
  ),
  KnownService(
    name: 'Алиса Плюс',
    emailPatterns: ['alice.yandex', 'plus.yandex'],
    subjectPatterns: ['алиса плюс', 'alice plus', 'алиса'],
    category: SubscriptionCategory.streaming,
    typicalPrices: {
      'RUB': PriceRange(99, 400),
    },
    amountContextPatterns: ['алиса', 'подписка', 'списан'],
  ),
  KnownService(
    name: 'Кинопоиск',
    emailPatterns: ['kinopoisk.ru', 'kinopoisk'],
    subjectPatterns: ['кинопоиск', 'kinopoisk'],
    category: SubscriptionCategory.streaming,
    typicalPrices: {
      'RUB': PriceRange(99, 600),
    },
    amountContextPatterns: ['кинопоиск', 'подписка'],
  ),
  KnownService(
    name: 'Okko',
    emailPatterns: ['okko.tv', 'okko'],
    subjectPatterns: ['okko', 'окко'],
    category: SubscriptionCategory.streaming,
    typicalPrices: {
      'RUB': PriceRange(99, 500),
    },
    amountContextPatterns: ['okko', 'подписка'],
  ),

  // Cloud & Software
  KnownService(
    name: 'iCloud',
    emailPatterns: ['apple.com', 'icloud.com'],
    subjectPatterns: ['icloud', 'icloud+', 'хранилище icloud'],
    category: SubscriptionCategory.cloud,
    typicalPrices: {
      'RUB': PriceRange(29, 600),
      'USD': PriceRange(0.99, 10),
      'EUR': PriceRange(0.99, 10),
    },
    amountContextPatterns: ['icloud', 'storage', 'хранилище'],
  ),
  KnownService(
    name: 'Google One',
    emailPatterns: ['google.com', 'googleone'],
    subjectPatterns: ['google one', 'google хранилище'],
    category: SubscriptionCategory.cloud,
    typicalPrices: {
      'RUB': PriceRange(99, 700),
      'USD': PriceRange(1.99, 10),
      'EUR': PriceRange(1.99, 10),
    },
    amountContextPatterns: ['google one', 'storage', 'хранилище'],
  ),
  KnownService(
    name: 'Dropbox',
    emailPatterns: ['dropbox.com', 'dropboxmail'],
    subjectPatterns: ['dropbox', 'dropbox plus', 'dropbox professional'],
    category: SubscriptionCategory.cloud,
    typicalPrices: {
      'USD': PriceRange(9.99, 25),
      'EUR': PriceRange(9.99, 22),
    },
    amountContextPatterns: ['dropbox', 'plus', 'professional'],
  ),
  KnownService(
    name: 'Adobe Creative Cloud',
    emailPatterns: ['adobe.com', 'adobe'],
    subjectPatterns: ['adobe', 'creative cloud', 'photoshop', 'lightroom'],
    category: SubscriptionCategory.software,
    typicalPrices: {
      'RUB': PriceRange(500, 5000),
      'USD': PriceRange(9.99, 80),
      'EUR': PriceRange(9.99, 70),
    },
    amountContextPatterns: ['creative cloud', 'подписка', 'membership'],
  ),
  KnownService(
    name: 'JetBrains',
    emailPatterns: ['jetbrains.com', 'jetbrains'],
    subjectPatterns: ['jetbrains', 'intellij', 'webstorm', 'pycharm', 'phpstorm'],
    category: SubscriptionCategory.software,
    typicalPrices: {
      'USD': PriceRange(10, 300),
      'EUR': PriceRange(10, 280),
    },
    amountContextPatterns: ['subscription', 'license', 'подписка'],
  ),
  KnownService(
    name: 'Microsoft 365',
    emailPatterns: ['microsoft.com', 'office.com'],
    subjectPatterns: ['microsoft 365', 'office 365', 'microsoft office'],
    category: SubscriptionCategory.software,
    typicalPrices: {
      'RUB': PriceRange(300, 1500),
      'USD': PriceRange(6.99, 15),
      'EUR': PriceRange(6.99, 15),
    },
    amountContextPatterns: ['microsoft 365', 'office', 'подписка'],
  ),

  // VPN
  KnownService(
    name: 'NordVPN',
    emailPatterns: ['nordvpn.com', 'nordaccount'],
    subjectPatterns: ['nordvpn', 'nord vpn'],
    category: SubscriptionCategory.vpn,
    typicalPrices: {
      'USD': PriceRange(3, 15),
      'EUR': PriceRange(3, 15),
    },
    amountContextPatterns: ['nordvpn', 'subscription', 'plan'],
  ),
  KnownService(
    name: 'ExpressVPN',
    emailPatterns: ['expressvpn.com', 'expressvpn'],
    subjectPatterns: ['expressvpn', 'express vpn'],
    category: SubscriptionCategory.vpn,
    typicalPrices: {
      'USD': PriceRange(6, 15),
      'EUR': PriceRange(6, 15),
    },
    amountContextPatterns: ['expressvpn', 'subscription'],
  ),
  KnownService(
    name: 'Surfshark',
    emailPatterns: ['surfshark.com', 'surfshark'],
    subjectPatterns: ['surfshark'],
    category: SubscriptionCategory.vpn,
    typicalPrices: {
      'USD': PriceRange(2, 15),
      'EUR': PriceRange(2, 15),
    },
    amountContextPatterns: ['surfshark', 'subscription'],
  ),

  // Fitness
  KnownService(
    name: 'BitePal',
    emailPatterns: ['bitepal', 'bite-pal'],
    subjectPatterns: ['bitepal', 'bite pal'],
    category: SubscriptionCategory.fitness,
    typicalPrices: {
      'USD': PriceRange(5, 30),
      'EUR': PriceRange(5, 30),
      'RUB': PriceRange(300, 2000),
    },
    amountContextPatterns: ['bitepal', 'subscription', 'premium', 'подписка'],
  ),
  KnownService(
    name: 'Strava',
    emailPatterns: ['strava.com', 'strava'],
    subjectPatterns: ['strava', 'strava summit'],
    category: SubscriptionCategory.fitness,
    typicalPrices: {
      'USD': PriceRange(5, 15),
      'EUR': PriceRange(5, 15),
    },
    amountContextPatterns: ['strava', 'subscription', 'summit'],
  ),
  KnownService(
    name: 'MyFitnessPal',
    emailPatterns: ['myfitnesspal.com', 'myfitnesspal'],
    subjectPatterns: ['myfitnesspal', 'myfitnesspal premium'],
    category: SubscriptionCategory.fitness,
    typicalPrices: {
      'USD': PriceRange(9, 25),
      'EUR': PriceRange(9, 25),
    },
    amountContextPatterns: ['myfitnesspal', 'premium'],
  ),

  // Education
  KnownService(
    name: 'Duolingo',
    emailPatterns: ['duolingo.com', 'duolingo'],
    subjectPatterns: ['duolingo', 'duolingo plus', 'super duolingo'],
    category: SubscriptionCategory.education,
    typicalPrices: {
      'RUB': PriceRange(300, 900),
      'USD': PriceRange(6, 15),
      'EUR': PriceRange(6, 15),
    },
    amountContextPatterns: ['duolingo', 'super', 'plus'],
  ),
  KnownService(
    name: 'Coursera',
    emailPatterns: ['coursera.org', 'coursera'],
    subjectPatterns: ['coursera', 'coursera plus'],
    category: SubscriptionCategory.education,
    typicalPrices: {
      'USD': PriceRange(30, 70),
      'EUR': PriceRange(30, 70),
    },
    amountContextPatterns: ['coursera', 'plus', 'subscription'],
  ),

  // AI Services
  KnownService(
    name: 'ChatGPT Plus',
    emailPatterns: ['openai.com', 'noreply@tm.openai.com'],
    subjectPatterns: ['chatgpt', 'openai', 'gpt plus'],
    category: SubscriptionCategory.software,
    typicalPrices: {
      'USD': PriceRange(18, 25),
      'EUR': PriceRange(18, 25),
    },
    amountContextPatterns: ['chatgpt', 'plus', 'subscription', 'openai'],
  ),
  KnownService(
    name: 'Claude',
    emailPatterns: ['anthropic.com', 'noreply@anthropic.com'],
    subjectPatterns: ['claude', 'anthropic', 'claude pro', 'claude max'],
    category: SubscriptionCategory.software,
    typicalPrices: {
      'USD': PriceRange(18, 200),  // Pro $20, Max $100, Team $25-30/user
      'EUR': PriceRange(18, 200),
    },
    amountContextPatterns: ['claude', 'pro', 'max', 'subscription', 'anthropic'],
  ),
  KnownService(
    name: 'ElevenLabs',
    emailPatterns: ['elevenlabs.io', 'elevenlabs'],
    subjectPatterns: ['elevenlabs', 'eleven labs', 'voice ai'],
    category: SubscriptionCategory.software,
    typicalPrices: {
      'USD': PriceRange(5, 100),
      'EUR': PriceRange(5, 100),
    },
    amountContextPatterns: ['elevenlabs', 'subscription', 'plan', 'starter', 'creator'],
  ),

  // Developer Tools
  KnownService(
    name: 'Obsidian Sync',
    emailPatterns: ['obsidian.md', 'noreply@obsidian.md'],
    subjectPatterns: ['obsidian', 'obsidian sync', 'obsidian publish'],
    category: SubscriptionCategory.software,
    typicalPrices: {
      'USD': PriceRange(4, 20),
      'EUR': PriceRange(4, 20),
    },
    amountContextPatterns: ['obsidian', 'sync', 'publish', 'subscription'],
  ),
  KnownService(
    name: 'n8n',
    emailPatterns: ['n8n.io', 'n8n.cloud'],
    subjectPatterns: ['n8n', 'n8n cloud', 'workflow automation'],
    category: SubscriptionCategory.software,
    typicalPrices: {
      'USD': PriceRange(20, 100),
      'EUR': PriceRange(20, 100),
    },
    amountContextPatterns: ['n8n', 'cloud', 'subscription', 'workflow'],
  ),
  KnownService(
    name: 'GitHub',
    emailPatterns: ['billing@github.com'],
    subjectPatterns: ['github pro', 'github copilot', 'github subscription', 'github payment'],
    category: SubscriptionCategory.software,
    typicalPrices: {
      'USD': PriceRange(4, 25),
      'EUR': PriceRange(4, 25),
    },
    amountContextPatterns: ['github', 'pro', 'copilot', 'subscription'],
  ),
  KnownService(
    name: 'Notion',
    emailPatterns: ['notion.so', 'noreply@notion.so'],
    subjectPatterns: ['notion', 'notion plus', 'notion team'],
    category: SubscriptionCategory.software,
    typicalPrices: {
      'USD': PriceRange(8, 20),
      'EUR': PriceRange(8, 20),
    },
    amountContextPatterns: ['notion', 'plus', 'team', 'subscription'],
  ),
  KnownService(
    name: 'Figma',
    emailPatterns: ['figma.com', 'noreply@figma.com'],
    subjectPatterns: ['figma', 'figma professional'],
    category: SubscriptionCategory.software,
    typicalPrices: {
      'USD': PriceRange(12, 50),
      'EUR': PriceRange(12, 50),
    },
    amountContextPatterns: ['figma', 'professional', 'subscription', 'plan'],
  ),

  // Utility Services
  KnownService(
    name: 'Chargeback',
    emailPatterns: ['joinchargeback.com', 'chargeback.com'],
    subjectPatterns: ['chargeback'],
    category: SubscriptionCategory.software,
    typicalPrices: {
      'USD': PriceRange(3, 15),
      'EUR': PriceRange(3, 15),
    },
    amountContextPatterns: ['chargeback', 'subscription', 'plan'],
  ),

  // Health & Wearables
  KnownService(
    name: 'Oura',
    emailPatterns: ['ouraring.com', 'oura.com'],
    subjectPatterns: ['oura', 'oura ring', 'oura membership'],
    category: SubscriptionCategory.fitness,
    typicalPrices: {
      'USD': PriceRange(5, 10),
      'EUR': PriceRange(5, 10),
    },
    amountContextPatterns: ['oura', 'membership', 'subscription'],
  ),
];
