import '../core/models.dart';
import '../core/pip_utils.dart';
import 'smart_money.dart';
import 'strategy_result.dart';
import 'signal_risk_gate.dart';
import 'strategies/sweep_reclaim.dart';
import 'strategies/crt_tbs.dart';
import 'strategies/qm_smc.dart';
import 'strategies/price_action_fib.dart';
import 'strategies/wyckoff_ict.dart';

typedef StrategyRunner = StrategyResult Function({
  required Map<String, List<Candle>> timeframes,
  required String htfBias4h,
  required String htfBias1h,
});

/// এখন ৫টা মোডই যুক্ত। প্রতিটা মোড আইডি mode_meta.dart-এর kSignalModes
/// এর id-এর সাথে হুবহু মিলতে হবে, নাহলে UI-তে সেই মোড কখনো স্ক্যানই
/// হবে না।
final Map<String, StrategyRunner> kModeRunners = {
  'sweep': runSweepReclaim,
  'crt_tbs': runCrtTbs,
  'wyckoff_ict': runWyckoffIct,
  'qm_smc': runQmSmc,
  'price_action_fib': runPriceActionFib,
};

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

/// ✅ নতুন: SL/TP দূরত্ব বাস্তবসম্মত সীমার মধ্যে আছে কি না যাচাই করে —
/// কোনো হিসাবের বাগে যদি অস্বাভাবিক বড় বা ছোট দূরত্ব চলে আসে, সিগন্যাল
/// UI-তে পৌঁছানোর আগেই আটকে দেওয়া হয়। এই সীমাগুলো সাধারণ ইন্ট্রাডে
/// ফরেক্স ট্রেডিং-এর বাস্তবসম্মত রেঞ্জ অনুযায়ী সেট করা (খুব সংকীর্ণ
/// SL বা কয়েক শ' pip-এর অস্বাভাবিক বড় SL — দুটোই সন্দেহজনক)।
class _SanityLimits {
  static const double minSlPips = 1.0;
  static const double maxSlPips = 300.0;
}

String? _sanityCheckReason(double slPips, double tp1Pips, double tp2Pips, double tp3Pips) {
  if (slPips < _SanityLimits.minSlPips) {
    return 'SL দূরত্ব অস্বাভাবিক কম (${slPips.toStringAsFixed(1)} pips) — গণনায় সমস্যা মনে হচ্ছে, সিগন্যাল বাতিল।';
  }
  if (slPips > _SanityLimits.maxSlPips) {
    return 'SL দূরত্ব অস্বাভাবিক বেশি (${slPips.toStringAsFixed(1)} pips) — গণনায় সমস্যা মনে হচ্ছে, সিগন্যাল বাতিল।';
  }
  if (tp1Pips <= 0 || tp2Pips <= 0 || tp3Pips <= 0) {
    return 'TP দূরত্ব শূন্য বা ঋণাত্মক এসেছে — সিগন্যাল বাতিল।';
  }
  if (!(tp1Pips < tp2Pips && tp2Pips < tp3Pips)) {
    return 'TP1/TP2/TP3 ক্রম ভুল এসেছে — সিগন্যাল বাতিল।';
  }
  return null;
}

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
  if (!has4h && has1h) htfBias4h = htfBias1h;

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

  // ✅ নতুন sanity layer — কাঠামোগতভাবে "valid" হলেও বাস্তবসম্মত না
  // হলে এখানেই আটকে দেওয়া হয়
  final sanityIssue = _sanityCheckReason(slPips, tp1Pips, tp2Pips, tp3Pips);
  if (sanityIssue != null) {
    return RouterSignal.blocked(sanityIssue);
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
