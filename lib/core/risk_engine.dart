import 'dart:math';
import 'constants.dart';
import 'models.dart';
import 'store.dart';

/// রিস্ক-গেট চেকের ফলাফল — blocked=true হলে ট্রেড কোনোভাবেই যাবে না,
/// সিগন্যাল যতই শক্তিশালী হোক না কেন।
class RiskGateResult {
  final bool blocked;
  final String? reasonBn; // বাংলায় কারণ, UI-তে সরাসরি দেখানো যায়
  final double? approvedLotSize;
  const RiskGateResult({required this.blocked, this.reasonBn, this.approvedLotSize});
}

/// এই ক্লাসটাই বটের "সেফটি ব্রেক" — কোনো ট্রেড এক্সিকিউটরে (Accessibility
/// Service) পাঠানোর আগে বাধ্যতামূলকভাবে এখান দিয়ে পাস করতে হবে।
class RiskEngine {
  /// ইউজারের ইনপুট যত ভুলই হোক, RiskDefaults-এর সীমার বাইরে কখনো যাবে না।
  static double clampRiskPercent(double requested) {
    final v = requested.clamp(0.0, RiskDefaults.maxRiskPercent);
    return v <= 0 ? RiskDefaults.defaultRiskPercent : v;
  }

  static int clampMaxDailyLosses(int requested) =>
      requested.clamp(1, RiskDefaults.maxAllowedDailyLosses);

  static int clampMaxConcurrentTrades(int requested) =>
      requested.clamp(1, RiskDefaults.maxAllowedConcurrentTrades);

  /// নতুন ট্রেড খোলার আগে সব শর্ত যাচাই করে। কোনো একটা শর্ত fail করলে
  /// সাথে সাথে blocked=true রিটার্ন করে, বাকি চেক আর করা হয় না।
  static Future<RiskGateResult> canOpenNewTrade({
    required int currentOpenTradesCount,
    required double slPips,
    required double pipValueUsd,
  }) async {
    final settings = await Store.riskSettings();
    final lossCount = await Store.todaysLossCount();

    if (settings.accountBalance <= 0) {
      return const RiskGateResult(
        blocked: true,
        reasonBn: 'Account balance সেট করা নেই — সেটিংসে গিয়ে ব্যালেন্স দিন।',
      );
    }

    final maxDailyLosses = clampMaxDailyLosses(settings.maxDailyLosses);
    if (lossCount >= maxDailyLosses) {
      return RiskGateResult(
        blocked: true,
        reasonBn:
            'আজকের সর্বোচ্চ লস লিমিট ($maxDailyLosses) পূর্ণ হয়ে গেছে — বট আজকের মতো ট্রেড বন্ধ রাখছে।',
      );
    }

    final maxConcurrent = clampMaxConcurrentTrades(settings.maxConcurrentTrades);
    if (currentOpenTradesCount >= maxConcurrent) {
      return RiskGateResult(
        blocked: true,
        reasonBn: 'ইতিমধ্যে সর্বোচ্চ ($maxConcurrent) সংখ্যক ট্রেড ওপেন আছে।',
      );
    }

    if (slPips <= 0) {
      return const RiskGateResult(
        blocked: true,
        reasonBn: 'Stop Loss দূরত্ব হিসাব করা যায়নি (0 pips) — নিরাপত্তার জন্য ট্রেড আটকানো হলো।',
      );
    }

    if (pipValueUsd <= 0) {
      return const RiskGateResult(
        blocked: true,
        reasonBn: 'Pip value হিসাব করা যায়নি — ট্রেড আটকানো হলো।',
      );
    }

    final riskPercent = clampRiskPercent(settings.riskPercent);
    final riskAmountUsd = settings.accountBalance * riskPercent;
    final rawLot = riskAmountUsd / (slPips * pipValueUsd);

    // লট সাইজ কখনো ০.০১-এর নিচে বা অস্বাভাবিক বড় (২০ লট+) হবে না —
    // এক্সট্রা সেফটি নেট, ক্যালকুলেশন বাগ থাকলেও একাউন্ট বাঁচাবে।
    final safeLot = double.parse(rawLot.clamp(0.01, 20.0).toStringAsFixed(2));

    return RiskGateResult(blocked: false, approvedLotSize: safeLot);
  }

  /// একটা ট্রেড লস হলে এই ফাংশন কল করতে হবে — daily loss counter বাড়াবে।
  static Future<void> recordLoss() async {
    await Store.incrementTodaysLoss();
  }
}
