import '../core/models.dart';
import 'smart_money.dart';

/// ⚠️ এই সংখ্যাগুলো মূল JS প্রজেক্টের constants.js থেকে আসার কথা ছিল,
/// যেটা এখনো পাওয়া যায়নি — তাই যুক্তিসঙ্গত ডিফল্ট বসানো হলো।
/// প্রয়োজনে এখানে বদলে নাও।
class SignalRiskConfig {
  static const Map<String, double> minSlPips = {
    'Major': 5.0,
    'Cross': 8.0,
    'Exotic': 15.0,
  };
  static const double minRrRatio = 1.5;
  static const double maxVolatilityMultiplier = 3.0;
  static const double epsilon = 1e-6;
}

class SignalGateResult {
  final bool blocked;
  final String? reasonBn;
  const SignalGateResult({required this.blocked, this.reasonBn});
}

/// এটা RiskEngine (money-management) থেকে আলাদা — এটা "সিগন্যালটা আসলেই
/// ট্রেড করার যোগ্য কি না" যাচাই করে (spread/volatility/SL/RR), lot size
/// নিয়ে কিছু বলে না।
class SignalRiskGate {
  /// শেষ ৩টা ক্যান্ডেলের গড় রেঞ্জ দেখে — একটা মাত্র স্পাইক ক্যান্ডেলের
  /// কারণে ভুলভাবে সিগন্যাল ব্লক না হয়ে যায়, তাই average নেওয়া হয়েছে।
  static SignalGateResult checkVolatility(List<Candle> candles) {
    if (candles.length < 20) return const SignalGateResult(blocked: false);

    final atr = calcATR(candles, 14);
    if (atr == null || atr <= 0) return const SignalGateResult(blocked: false);

    final last3 = candles.sublist(candles.length - 3);
    final avgRecentRange = last3.fold<double>(0, (sum, c) => sum + (c.h - c.l)) / last3.length;

    if (avgRecentRange > atr * SignalRiskConfig.maxVolatilityMultiplier) {
      return const SignalGateResult(
        blocked: true,
        reasonBn: '⚠️ এই মুহূর্তে স্প্রেড/ভোলাটিলিটি অস্বাভাবিক বেশি — সিগন্যাল নিরাপদ নয়।',
      );
    }
    return const SignalGateResult(blocked: false);
  }

  static bool meetsMinSlDistance(double slPips, String category) {
    final floor = SignalRiskConfig.minSlPips[category] ?? SignalRiskConfig.minSlPips['Major']!;
    return slPips >= floor - SignalRiskConfig.epsilon;
  }

  static bool meetsMinRR(double rr, [double? minRR]) {
    final threshold = minRR ?? SignalRiskConfig.minRrRatio;
    return rr.isFinite && rr >= threshold - SignalRiskConfig.epsilon;
  }

  /// এক্সিকিউটরের কাছে সিগন্যাল যাওয়ার আগে সবশেষ কোয়ালিটি চেক।
  static SignalGateResult check({
    required List<Candle> candles,
    required double slPips,
    required String category,
    required double rr,
  }) {
    final volatility = checkVolatility(candles);
    if (volatility.blocked) return volatility;

    if (!meetsMinSlDistance(slPips, category)) {
      final floor = SignalRiskConfig.minSlPips[category] ?? SignalRiskConfig.minSlPips['Major']!;
      return SignalGateResult(
        blocked: true,
        reasonBn: '⚠️ $category পেয়ারের জন্য SL অনেক কাছাকাছি (সর্বনিম্ন $floor pips) — বাতিল করা হলো।',
      );
    }

    if (!meetsMinRR(rr)) {
      return SignalGateResult(
        blocked: true,
        reasonBn: '⚠️ R:R অনুপাত 1:${SignalRiskConfig.minRrRatio} এর কম — সিগন্যাল বাতিল করা হলো।',
      );
    }

    return const SignalGateResult(blocked: false);
  }
}
