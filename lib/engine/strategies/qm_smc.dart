import '../../core/models.dart';
import '../smart_money.dart';
import '../strategy_result.dart';

const int _fvgLookback = 20;

/// Mode 4: Quasimodo (QM) Pattern + Smart Money Concepts — head-and-
/// shoulders ধরনের কাঠামো ভেঙে গেলে এন্ট্রি সিগন্যাল, Order Block/FVG
/// পাওয়া গেলে সেটা বোনাস কনফার্মেশন (আবশ্যক না)।
StrategyResult runQmSmc({
  required Map<String, List<Candle>> timeframes,
  required String htfBias4h,
  required String htfBias1h,
}) {
  final ltf = timeframes['15m'];
  final confirm = timeframes['5m'];
  if (ltf == null || ltf.length < 30) return const StrategyResult.none();

  final atr = calcATR(ltf, 14);
  if (atr == null) return const StrategyResult.none();

  final swings = findSwings(ltf, 2);
  if (swings.swingHighs.length < 3 || swings.swingLows.length < 3) {
    return const StrategyResult.none();
  }

  final lastClose = ltf.last.c;

  final lows = swings.swingLows.sublist(swings.swingLows.length - 3);
  final lowA = lows[0], lowB = lows[1], lowC = lows[2];
  final midHighs =
      swings.swingHighs.where((h) => h.index > lowA.index && h.index < lowC.index).toList();
  final neckline = midHighs.isNotEmpty ? midHighs.last : null;

  final bullishQM = lowB.price < lowA.price &&
      lowC.price > lowB.price &&
      neckline != null &&
      lastClose > neckline.price;

  final highs = swings.swingHighs.sublist(swings.swingHighs.length - 3);
  final highA = highs[0], highB = highs[1], highC = highs[2];
  final midLows =
      swings.swingLows.where((l) => l.index > highA.index && l.index < highC.index).toList();
  final necklineBear = midLows.isNotEmpty ? midLows.last : null;

  final bearishQM = highB.price > highA.price &&
      highC.price < highB.price &&
      necklineBear != null &&
      lastClose < necklineBear.price;

  final htfAgreesBullish = htfBias4h != 'Bearish';
  final htfAgreesBearish = htfBias4h != 'Bullish';

  String? direction;
  if (bullishQM && htfAgreesBullish) {
    direction = 'LONG';
  } else if (bearishQM && htfAgreesBearish) {
    direction = 'SHORT';
  } else {
    return const StrategyResult.none();
  }

  final orderBlock = detectOrderBlock(ltf, direction);
  final fvgSlice = ltf.length > _fvgLookback ? ltf.sublist(ltf.length - _fvgLookback) : ltf;
  final fvgs = detectFVG(fvgSlice);
  final wantedType = direction == 'LONG' ? 'bullish' : 'bearish';
  final relevantFvg = fvgs.where((g) => g.type == wantedType).isNotEmpty
      ? fvgs.firstWhere((g) => g.type == wantedType)
      : null;

  final entry = lastClose;
  final buffer = atr * 0.5;
  final headLevel = direction == 'LONG' ? lowB.price : highB.price;

  double sl, tp1, tp2, tp3;
  if (direction == 'LONG') {
    sl = headLevel - buffer;
    final risk = entry - sl;
    if (risk <= 0) return const StrategyResult.none();
    tp1 = entry + risk * 1.5;
    tp3 = entry + risk * 3;
    final swingTarget = swings.swingHighs.last.price;
    tp2 = (swingTarget > tp1 && swingTarget < tp3) ? swingTarget : entry + risk * 2.25;
  } else {
    sl = headLevel + buffer;
    final risk = sl - entry;
    if (risk <= 0) return const StrategyResult.none();
    tp1 = entry - risk * 1.5;
    tp3 = entry - risk * 3;
    final swingTarget = swings.swingLows.last.price;
    tp2 = (swingTarget < tp1 && swingTarget > tp3) ? swingTarget : entry - risk * 2.25;
  }

  String bias5m = 'Neutral';
  if (confirm != null && confirm.length >= 2) {
    final c = confirm.last;
    bias5m = c.c > c.o ? 'Bullish' : (c.c < c.o ? 'Bearish' : 'Neutral');
  }

  final necklineDisplay =
      direction == 'LONG' ? (neckline?.price.toStringAsFixed(5) ?? 'N/A') : (necklineBear?.price.toStringAsFixed(5) ?? 'N/A');

  final confluenceCount = (orderBlock != null ? 1 : 0) + (relevantFvg != null ? 1 : 0);
  final strength = confluenceCount == 2 ? 'Strong' : (confluenceCount == 1 ? 'Moderate' : 'Weak');

  final result = StrategyResult(
    direction: direction,
    strength: strength,
    entry: entry,
    sl: sl,
    tp1: tp1,
    tp2: tp2,
    tp3: tp3,
    bias15m: direction == 'LONG' ? 'Bullish' : 'Bearish',
    bias5m: bias5m,
    pattern: direction == 'LONG' ? 'Bullish Quasimodo Pattern' : 'Bearish Quasimodo Pattern',
    quickStats: {
      'Neckline': necklineDisplay,
      'Order Block': orderBlock != null ? 'Found' : 'None',
      'FVG': relevantFvg != null ? 'Found' : 'None',
    },
    structure: {
      'Head Level': headLevel.toStringAsFixed(5),
      'Confluence': '$confluenceCount/2',
    },
    detail: direction == 'LONG'
        ? 'Quasimodo pattern তৈরি হয়েছে — lower-low দিয়ে লিকুইডিটি গ্র্যাব করে neckline ভেঙে বাইরে চলে এসেছে।'
        : 'Quasimodo pattern তৈরি হয়েছে — higher-high দিয়ে লিকুইডিটি গ্র্যাব করে neckline ভেঙে নিচে চলে এসেছে।',
  );

  return result.isStructurallyValid ? result : const StrategyResult.none();
}
