import '../core/models.dart';
import '../core/pip_utils.dart';
import 'smart_money.dart';
import 'strategy_result.dart';
import 'signal_risk_gate.dart';
import 'strategies/sweep_reclaim.dart';
import 'strategies/crt_tbs.dart';
import 'strategies/qm_smc.dart';
import 'strategies/price_action_fib.dart';

typedef StrategyRunner = StrategyResult Function({
  required Map<String, List<Candle>> timeframes,
  required String htfBias4h,
  required String htfBias1h,
});

/// প্রতিটা মোড আইডি একটা স্ট্র্যাটেজি ফাংশনের সাথে ম্যাপ করা।
/// Wyckoff/ICT (mode: wyckoff_ict) এখনো যোগ করা হয়নি — সোর্স ফাইল
/// পাওয়া গেলে এখানে একটা লাইন যোগ করলেই চলবে।
final Map<String, StrategyRunner> kModeRunners = {
  'sweep': runSweepReclaim,
  'crt_tbs': runCrtTbs,
  'qm_smc': runQmSmc,
  'price_action_fib': runPriceActionFib,
};

/// রাউটারের চূড়ান্ত আউটপুট — StrategyResult + pip/risk হিসাব একসাথে।
class RouterSignal {
  final bool noSignal;
  final String? debugReasonBn;
  final StrategyResult? strategy;
  final double? slPips;
  final double? tp1Pips;
  final double? tp2Pips;
  final double? tp3Pips;
  final double? rr;
  final Map<String, String> mtfBias;

  const RouterSignal.blocked(this.debugReasonBn)
      : noSignal = true,
        strategy = null,
        slPips = null,
        tp1Pips = null,
        tp2Pips = null,
        tp3Pips = null,
        rr = null,
        mtfBias = const {};

  const RouterSignal.ok({
    required this.strategy,
    required this.slPips,
    required this.tp1Pips,
    required this.tp2Pips,
    required this.tp3Pips,
    required this.rr,
    required this.mtfBias,
  })  : noSignal = false,
        debugReasonBn = null;
}

/// পুরো সিগন্যাল পাইপলাইন: HTF bias বের করা → স্ট্র্যাটেজি চালানো →
/// pip/RR হিসাব → SignalRiskGate দিয়ে কোয়ালিটি চেক। এই ফাংশনের বাইরে
/// কোথাও সরাসরি স্ট্র্যাটেজি ফাংশন কল করা উচিত না।
RouterSignal generateRouterSignal({
  required String modeId,
  required Map<String, List<Candle>> timeframes,
  required String marketTd,
  required String marketCategory,
}) {
  final runner = kModeRunners[modeId];
  if (runner == null) {
    return const RouterSignal.blocked('অজানা সিগন্যাল মোড।');
  }

  final ltf = timeframes['15m'];
  final has15m = ltf != null && ltf.length >= 30;
  if (!has15m) {
    return const RouterSignal.blocked(
      '15m ক্যান্ডেল ডেটা পাওয়া যায়নি — API rate limit বা কানেকশন সমস্যা।',
    );
  }

  final h4 = timeframes['4h'];
  final h1 = timeframes['1h'];
  final has4h = h4 != null && h4.length >= 30;
  final has1h = h1 != null && h1.length >= 30;

  String htfBias4h = 'Neutral';
  String htfBias1h = 'Neutral';
  if (has4h) htfBias4h = getHtfBias(h4);
  if (has1h) htfBias1h = getHtfBias(h1);
  if (!has4h && has1h) htfBias4h = htfBias1h; // 4h না থাকলে 1h fallback হিসেবে ব্যবহার

  final raw = runner(timeframes: timeframes, htfBias4h: htfBias4h, htfBias1h: htfBias1h);
  if (raw.noSignal || !raw.isStructurallyValid) {
    return RouterSignal.blocked('"$modeId" মোডের প্যাটার্ন এই মুহূর্তে মেলেনি। অন্য mode চেষ্টা করুন।');
  }

  final slPips = priceDeltaToPips((raw.entry! - raw.sl!).abs(), marketTd);
  final tp1Pips = priceDeltaToPips((raw.tp1! - raw.entry!).abs(), marketTd);
  final tp2Pips = priceDeltaToPips((raw.tp2! - raw.entry!).abs(), marketTd);
  final tp3Pips = priceDeltaToPips((raw.tp3! - raw.entry!).abs(), marketTd);

  if (slPips == 0) {
    return const RouterSignal.blocked('SL দূরত্ব 0 pips — সিগন্যাল বাতিল করা হলো।');
  }

  final rr = tp1Pips / slPips;

  final gateCandles = timeframes['5m'] ?? timeframes['15m']!;
  final gate = SignalRiskGate.check(
    candles: gateCandles,
    slPips: slPips,
    category: marketCategory,
    rr: rr,
  );
  if (gate.blocked) {
    return RouterSignal.blocked(gate.reasonBn ?? 'রিস্ক গেট সিগন্যাল আটকে দিয়েছে।');
  }

  return RouterSignal.ok(
    strategy: raw,
    slPips: slPips,
    tp1Pips: tp1Pips,
    tp2Pips: tp2Pips,
    tp3Pips: tp3Pips,
    rr: rr,
    mtfBias: {
      '4h': htfBias4h,
      '1h': htfBias1h,
      '15m': raw.bias15m ?? 'Neutral',
      '5m': raw.bias5m ?? 'Neutral',
    },
  );
}
