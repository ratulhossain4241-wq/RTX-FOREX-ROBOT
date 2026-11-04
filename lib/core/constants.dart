import 'package:flutter/material.dart';

/// ───────────────── THEME ─────────────────
class T {
  static const bg = Color(0xFF0A0A0A);
  static const card = Color(0xFF0D1117);
  static const panel = Color(0xFF11161C);
  static const green = Color(0xFF00FF41);
  static const red = Color(0xFFFF0040);
  static const gold = Color(0xFFFFCC00);
  static const cyan = Color(0xFF00FFFF);
  static const dim = Color(0xFF0A6E0A);
  static const muted = Color(0xFF333333);
  static const ghostUpFill = Color(0x73FFFFFF);
  static const ghostUpBorder = Color(0xFFFFFFFF);
  static const ghostDownFill = Color(0x73F3BA2F);
  static const ghostDownBorder = Color(0xFFF3BA2F);
}

/// ───────────────── MARKET ─────────────────
class MarketDef {
  final String name, td, cat;
  const MarketDef(this.name, this.td, this.cat);
}

const List<MarketDef> kMarkets = <MarketDef>[
  MarketDef('EUR/USD', 'EUR/USD', 'Major'),
  MarketDef('GBP/USD', 'GBP/USD', 'Major'),
  MarketDef('USD/JPY', 'USD/JPY', 'Major'),
  MarketDef('USD/CHF', 'USD/CHF', 'Major'),
  MarketDef('USD/CAD', 'USD/CAD', 'Major'),
  MarketDef('AUD/USD', 'AUD/USD', 'Major'),
  MarketDef('NZD/USD', 'NZD/USD', 'Major'),
  MarketDef('EUR/GBP', 'EUR/GBP', 'Cross'),
  MarketDef('EUR/JPY', 'EUR/JPY', 'Cross'),
  MarketDef('EUR/CHF', 'EUR/CHF', 'Cross'),
  MarketDef('EUR/AUD', 'EUR/AUD', 'Cross'),
  MarketDef('EUR/CAD', 'EUR/CAD', 'Cross'),
  MarketDef('EUR/NZD', 'EUR/NZD', 'Cross'),
  MarketDef('GBP/JPY', 'GBP/JPY', 'Cross'),
  MarketDef('GBP/CHF', 'GBP/CHF', 'Cross'),
  MarketDef('GBP/AUD', 'GBP/AUD', 'Cross'),
  MarketDef('GBP/CAD', 'GBP/CAD', 'Cross'),
  MarketDef('GBP/NZD', 'GBP/NZD', 'Cross'),
  MarketDef('AUD/JPY', 'AUD/JPY', 'Cross'),
  MarketDef('AUD/CHF', 'AUD/CHF', 'Cross'),
  MarketDef('AUD/CAD', 'AUD/CAD', 'Cross'),
  MarketDef('AUD/NZD', 'AUD/NZD', 'Cross'),
  MarketDef('CAD/JPY', 'CAD/JPY', 'Cross'),
  MarketDef('CAD/CHF', 'CAD/CHF', 'Cross'),
  MarketDef('CHF/JPY', 'CHF/JPY', 'Cross'),
  MarketDef('NZD/JPY', 'NZD/JPY', 'Cross'),
  MarketDef('NZD/CHF', 'NZD/CHF', 'Cross'),
  MarketDef('NZD/CAD', 'NZD/CAD', 'Cross'),
  MarketDef('USD/INR', 'USD/INR', 'Exotic'),
  MarketDef('USD/SGD', 'USD/SGD', 'Exotic'),
];

/// ───────────────── RISK DEFAULTS ─────────────────
/// এই মানগুলো ব্যবহারকারী সেটিংসে বদলাতে পারবে, কিন্তু সবসময় একটা
/// সর্বোচ্চ সীমার (hard cap) মধ্যে আটকানো থাকবে — যাতে ভুল ইনপুট
/// দিয়েও কেউ পুরো অ্যাকাউন্ট ঝুঁকিতে ফেলতে না পারে।
class RiskDefaults {
  static const double defaultRiskPercent = 0.01; // 1%
  static const double maxRiskPercent = 0.03; // hard cap 3%
  static const int defaultMaxDailyLosses = 3;
  static const int maxAllowedDailyLosses = 10; // hard cap
  static const int defaultMaxConcurrentTrades = 1;
  static const int maxAllowedConcurrentTrades = 3; // hard cap
}

/// ───────────────── API ─────────────────
class ApiConfig {
  static const String twelveDataBase = 'https://api.twelvedata.com/time_series';
  static const String geminiBase =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const String geminiModel = 'gemini-1.5-flash'; // ব্যবহারের আগে AI Studio-তে নাম যাচাই করুন
}

/// ───────────────── STORAGE KEYS ─────────────────
/// সব SharedPreferences key এক জায়গায় রাখা হলো যাতে টাইপো থেকে বাগ না হয়।
class PrefKeys {
  static const String twelveDataKey = 'td_key';
  static const String geminiKey = 'gemini_key';
  static const String selectedMarket = 'selected_market';
  static const String accountBalance = 'account_balance';
  static const String riskPercent = 'risk_percent';
  static const String maxDailyLosses = 'max_daily_losses';
  static const String maxConcurrentTrades = 'max_concurrent_trades';
  static const String dailyLossDate = 'daily_loss_date';
  static const String dailyLossCount = 'daily_loss_count';
  static const String autoModeOn = 'auto_mode_on';

  // ===== নতুন Keys (Hybrid Auto Trade এর জন্য) =====
  static const String accessibilityEnabled = 'accessibility_enabled';
  static const String autoTradeEnabled = 'auto_trade_enabled';
  static const String lastExecutedSignalId = 'last_executed_signal_id';
  static const String executionCooldownSec = 'execution_cooldown_sec';
}

/// ───────────────── MT5 & ACCESSIBILITY ─────────────────
/// MetaTrader 5 প্যাকেজ নাম এবং Accessibility সার্ভিস সংক্রান্ত কনস্ট্যান্ট।
/// শুধু এই প্যাকেজটাকেই স্ক্যান করা হবে — অন্য কোনো অ্যাপ ছোঁয়া যাবে না।
class Mt5Config {
  /// অফিসিয়াল MetaTrader 5 প্যাকেজ নাম
  static const String packageName = 'net.metaquotes.metatrader5';

  /// Accessibility Service এর অনন্য ID (Manifest এর সাথে মিল রাখতে হবে)
  static const String accessibilityServiceId =
      'com.rtxauto.rtx_auto_trader/com.rtxauto.rtx_auto_trader.RtxAccessibilityService';

  /// দুইটা ট্রেডের মধ্যে ন্যূনতম অপেক্ষা (সেকেন্ড) — ভুল করে বারবার ক্লিক এড়াতে
  static const int defaultCooldownSeconds = 45;

  /// স্ক্যান করার সময় ইন্টারভাল (মিলিসেকেন্ড)
  static const int scanIntervalMs = 1200;
}
