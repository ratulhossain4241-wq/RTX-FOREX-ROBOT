import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'models.dart';

/// Main app আর Overlay দুইটা আলাদা Flutter engine-এ চলে, তাই
/// SharedPreferences.getInstance() প্রতিবার reload() করে ডিস্ক থেকে
/// টাটকা ডেটা পড়া হয় — নাহলে overlay-তে পুরনো ক্যাশড মান দেখাবে।
class Store {
  static Future<SharedPreferences> _fresh() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return p;
  }

  // ── API KEYS ──
  static Future<void> saveKeys({required String td, required String gemini}) async {
    final p = await _fresh();
    await p.setString(PrefKeys.twelveDataKey, td);
    await p.setString(PrefKeys.geminiKey, gemini);
  }

  static Future<String> twelveDataKey() async =>
      (await _fresh()).getString(PrefKeys.twelveDataKey) ?? '';

  static Future<String> geminiKey() async =>
      (await _fresh()).getString(PrefKeys.geminiKey) ?? '';

  // ── MARKET ──
  static Future<void> saveMarket(String td) async =>
      (await _fresh()).setString(PrefKeys.selectedMarket, td);

  static Future<String> market() async =>
      (await _fresh()).getString(PrefKeys.selectedMarket) ?? 'EUR/USD';

  // ── RISK SETTINGS ──
  static Future<void> saveRiskSettings(RiskSettings s) async {
    final p = await _fresh();
    await p.setDouble(PrefKeys.accountBalance, s.accountBalance);
    await p.setDouble(PrefKeys.riskPercent, s.riskPercent);
    await p.setInt(PrefKeys.maxDailyLosses, s.maxDailyLosses);
    await p.setInt(PrefKeys.maxConcurrentTrades, s.maxConcurrentTrades);
  }

  static Future<RiskSettings> riskSettings() async {
    final p = await _fresh();
    return RiskSettings(
      accountBalance: p.getDouble(PrefKeys.accountBalance) ?? 0,
      riskPercent: p.getDouble(PrefKeys.riskPercent) ?? RiskDefaults.defaultRiskPercent,
      maxDailyLosses: p.getInt(PrefKeys.maxDailyLosses) ?? RiskDefaults.defaultMaxDailyLosses,
      maxConcurrentTrades:
          p.getInt(PrefKeys.maxConcurrentTrades) ?? RiskDefaults.defaultMaxConcurrentTrades,
    );
  }

  // ── DAILY LOSS COUNTER ──
  /// আজকের তারিখ না মিললে কাউন্টার স্বয়ংক্রিয়ভাবে ০-তে রিসেট হয়ে যায়।
  static Future<int> todaysLossCount() async {
    final p = await _fresh();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = p.getString(PrefKeys.dailyLossDate);
    if (storedDate != today) return 0;
    return p.getInt(PrefKeys.dailyLossCount) ?? 0;
  }

  static Future<void> incrementTodaysLoss() async {
    final p = await _fresh();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = p.getString(PrefKeys.dailyLossDate);
    final current = storedDate == today ? (p.getInt(PrefKeys.dailyLossCount) ?? 0) : 0;
    await p.setString(PrefKeys.dailyLossDate, today);
    await p.setInt(PrefKeys.dailyLossCount, current + 1);
  }

  // ── AUTO MODE TOGGLE ──
  static Future<void> setAutoMode(bool on) async =>
      (await _fresh()).setBool(PrefKeys.autoModeOn, on);

  static Future<bool> autoMode() async =>
      (await _fresh()).getBool(PrefKeys.autoModeOn) ?? false;
}
