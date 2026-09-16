import '../../core/models.dart';
import '../smart_money.dart';
import '../strategy_result.dart';

const int _rangeLookback = 20;
const int _triggerWindow = 6;

/// Mode 3: Wyckoff + ICT/SMC — একটা রেঞ্জের নিচে Spring (false
/// breakdown) বা ওপরে Upthrust (false breakout) তৈরি হয়ে আবার রেঞ্জে
/// ফিরে এলে এন্ট্রি সিগন্যাল। CHoCH (Change of Character) কনফার্মেশন
/// পেলে "Strong" ধরা হয়, না পেলেও সিগন্যাল চলে (শুধু বিপরীত CHoCH
/// থাকলে ব্লক হয়)।
StrategyResult runWyckoffIct({
  required Map<String, List<Candle>> timeframes,
  required String htfBias4h,
  required String htfBias1h,
}) {
  final ltf = timeframes['15m'];
  final confirm = timeframes['5m'];
  if (ltf == null || ltf.length < 30) return const StrategyResult.none();

  final atr = calcATR(ltf, 14);
  if (atr == null) return const StrategyResult.none();

  if (ltf.length < _rangeLookback + 3) return const StrategyResult.none();
  final rangeWindow = ltf.sublist(ltf.length - _rangeLookback, ltf.length - 3);
  if (rangeWindow.length < 10) return const StrategyResult.none();

  final rangeHigh = rangeWindow.map((c) => c.h).reduce((a, b) => a > b ? a : b);
  final rangeLow = rangeWindow.map((c) => c.l).reduce((a, b) => a < b ? a : b);

  final last = ltf.last;

  String? triggerDirection;

  final scanStart = ltf.length - 2;
  final scanEnd = (ltf.length - _triggerWindow).clamp(1, ltf.length);

  for (var i = scanStart; i >= scanEnd; i--) {
    final c = ltf[i];
    final bodyMin = c.o < c.c ? c.o : c.c;
    final bodyMax = c.o > c.c ? c.o : c.c;
    final isSpringCandle = c.l < rangeLow && bodyMin > rangeLow;
    final isUpthrustCandle = c.h > rangeHigh && bodyMax < rangeHigh;

    if (isSpringCandle) {
      triggerDirection = 'LONG';
      break;
    }
    if (isUpthrustCandle) {
      triggerDirection = 'SHORT';
      break;
    }
  }

  if (triggerDirection == null) return const StrategyResult.none();

  final stillValid =
      triggerDirection == 'LONG' ? last.c > rangeLow : last.c < rangeHigh;
  if (!stillValid) return const StrategyResult.none();

  final choch = detectBOSCHoCH(ltf);

  final htfAgreesBullish = htfBias4h != 'Bearish';
  final htfAgreesBearish = htfBias4h != 'Bullish';

  String? direction;
  if (triggerDirection == 'LONG' && htfAgreesBullish) {
    if (choch?.direction == 'bearish') return const StrategyResult.none();
    direction = 'LONG';
  } else if (triggerDirection == 'SHORT' && htfAgreesBearish) {
    if (choch?.direction == 'bullish') return const StrategyResult.none();
    direction = 'SHORT';
  } else {
    return const StrategyResult.none();
  }

  final chochAgrees = choch != null && choch.direction == (direction == 'LONG' ? 'bullish' : 'bearish');
  final orderBlock = detectOrderBlock(ltf, direction);

  final entry = last.c;
  final buffer = atr * 0.5;

  double sl, tp1, tp2, tp3;
  if (direction == 'LONG') {
    final baseLow = orderBlock != null ? (orderBlock.low < rangeLow ? orderBlock.low : rangeLow) : rangeLow;
    sl = baseLow - buffer;
    final risk = entry - sl;
    if (risk <= 0) return const StrategyResult.none();
    tp1 = entry + risk * 1.5;
    tp3 = entry + risk * 3;
    tp2 = (rangeHigh > tp1 && rangeHigh < tp3) ? rangeHigh : entry + risk * 2.25;
  } else {
    final baseHigh = orderBlock != null ? (orderBlock.high > rangeHigh ? orderBlock.high : rangeHigh) : rangeHigh;
    sl = baseHigh + buffer;
    final risk = sl - entry;
    if (risk <= 0) return const StrategyResult.none();
    tp1 = entry - risk * 1.5;
    tp3 = entry - risk * 3;
    tp2 = (rangeLow < tp1 && rangeLow > tp3) ? rangeLow : entry - risk * 2.25;
  }

  String bias5m = 'Neutral';
  if (confirm != null && confirm.length >= 2) {
    final c = confirm.last;
    bias5m = c.c > c.o ? 'Bullish' : (c.c < c.o ? 'Bearish' : 'Neutral');
  }

  final confluenceCount = (chochAgrees ? 1 : 0) + (orderBlock != null ? 1 : 0);
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
    pattern: direction == 'LONG'
        ? 'Wyckoff Spring${chochAgrees ? ' + Bullish CHoCH' : ''}'
        : 'Wyckoff Upthrust${chochAgrees ? ' + Bearish CHoCH' : ''}',
    quickStats: {
      'Range High/Low': '${rangeHigh.toStringAsFixed(5)} / ${rangeLow.toStringAsFixed(5)}',
      'CHoCH': chochAgrees ? (choch?.type ?? 'Yes') : 'None',
      'Order Block': orderBlock != null ? 'Found' : 'None',
    },
    structure: {
      'Wyckoff Phase': direction == 'LONG' ? 'Accumulation (Spring)' : 'Distribution (Upthrust)',
      'Confluence': '$confluenceCount/2',
    },
    detail: direction == 'LONG'
        ? 'দাম একটি accumulation range-এর নিচে Spring (false breakdown) তৈরি করেছিল এবং আবার range-এ ফিরে এসেছে — Wyckoff markup phase শুরুর ইঙ্গিত।'
        : 'দাম একটি distribution range-এর ওপরে Upthrust (false breakout) তৈরি করেছিল এবং আবার range-এ ফিরে এসেছে — Wyckoff markdown phase শুরুর ইঙ্গিত।',
  );

  return result.isStructurallyValid ? result : const StrategyResult.none();
}
