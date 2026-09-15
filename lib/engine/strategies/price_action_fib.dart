import '../../core/models.dart';
import '../smart_money.dart';
import '../strategy_result.dart';

const double _goldenPocketLow = 0.5;
const double _goldenPocketHigh = 0.79;
const int _triggerWindow = 8;

/// Mode 5: Price Action + Fibonacci — সর্বশেষ impulse leg-এর ৫০-৭৯%
/// রিট্রেসমেন্ট জোনে (Golden Pocket) reversal ক্যান্ডেল দেখা গেলে
/// এন্ট্রি সিগন্যাল।
StrategyResult runPriceActionFib({
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
  if (swings.swingHighs.length < 2 || swings.swingLows.length < 2) {
    return const StrategyResult.none();
  }

  final lastSwingHigh = swings.swingHighs.last;
  final lastSwingLow = swings.swingLows.last;
  final lastCandle = ltf.last;

  final impulseIsUp = lastSwingHigh.index > lastSwingLow.index;

  double fibHigh, fibLow, entryZoneLow, entryZoneHigh;

  if (impulseIsUp) {
    fibLow = lastSwingLow.price;
    fibHigh = lastSwingHigh.price;
    final range = fibHigh - fibLow;
    entryZoneHigh = fibHigh - range * _goldenPocketLow;
    entryZoneLow = fibHigh - range * _goldenPocketHigh;
  } else {
    fibHigh = lastSwingHigh.price;
    fibLow = lastSwingLow.price;
    final range = fibHigh - fibLow;
    entryZoneLow = fibLow + range * _goldenPocketLow;
    entryZoneHigh = fibLow + range * _goldenPocketHigh;
  }

  if (!entryZoneLow.isFinite || !entryZoneHigh.isFinite) {
    return const StrategyResult.none();
  }

  String? direction;

  final scanStart = ltf.length - 1;
  final scanEnd = (ltf.length - _triggerWindow).clamp(0, ltf.length);

  for (var i = scanStart; i >= scanEnd; i--) {
    final c = ltf[i];
    final bodySize = (c.c - c.o).abs();
    final totalRange = c.h - c.l;
    final bodyRatio = totalRange > 0 ? bodySize / totalRange : 0.0;

    if (impulseIsUp) {
      final inZone = c.l <= entryZoneHigh && c.l >= entryZoneLow;
      final bullishReversalCandle = c.c > c.o && bodyRatio >= 0.3;
      if (inZone && bullishReversalCandle) {
        direction = 'LONG';
        break;
      }
    } else {
      final inZone = c.h >= entryZoneLow && c.h <= entryZoneHigh;
      final bearishReversalCandle = c.c < c.o && bodyRatio >= 0.3;
      if (inZone && bearishReversalCandle) {
        direction = 'SHORT';
        break;
      }
    }
  }

  if (direction == null) return const StrategyResult.none();

  final htfAgreesBullish = htfBias4h != 'Bearish';
  final htfAgreesBearish = htfBias4h != 'Bullish';
  if (direction == 'LONG' && !htfAgreesBullish) return const StrategyResult.none();
  if (direction == 'SHORT' && !htfAgreesBearish) return const StrategyResult.none();

  final stillValid = direction == 'LONG' ? lastCandle.c > fibLow : lastCandle.c < fibHigh;
  if (!stillValid) return const StrategyResult.none();

  final entry = lastCandle.c;
  final buffer = atr * 0.5;

  double sl, tp1, tp2, tp3;
  if (direction == 'LONG') {
    sl = fibLow - buffer;
    final risk = entry - sl;
    if (risk <= 0) return const StrategyResult.none();
    tp1 = entry + risk * 1.5;
    final extensionTarget = fibHigh + (fibHigh - fibLow) * 0.272;
    tp3 = extensionTarget > entry + risk * 3 ? extensionTarget : entry + risk * 3;
    tp2 = (fibHigh > tp1 && fibHigh < tp3) ? fibHigh : entry + risk * 2.25;
  } else {
    sl = fibHigh + buffer;
    final risk = sl - entry;
    if (risk <= 0) return const StrategyResult.none();
    tp1 = entry - risk * 1.5;
    final extensionTarget = fibLow - (fibHigh - fibLow) * 0.272;
    tp3 = extensionTarget < entry - risk * 3 ? extensionTarget : entry - risk * 3;
    tp2 = (fibLow < tp1 && fibLow > tp3) ? fibLow : entry - risk * 2.25;
  }

  String bias5m = 'Neutral';
  if (confirm != null && confirm.length >= 2) {
    final c = confirm.last;
    bias5m = c.c > c.o ? 'Bullish' : (c.c < c.o ? 'Bearish' : 'Neutral');
  }

  final result = StrategyResult(
    direction: direction,
    strength: 'Moderate',
    entry: entry,
    sl: sl,
    tp1: tp1,
    tp2: tp2,
    tp3: tp3,
    bias15m: direction == 'LONG' ? 'Bullish' : 'Bearish',
    bias5m: bias5m,
    pattern: direction == 'LONG' ? 'Bullish Fibonacci Retracement' : 'Bearish Fibonacci Retracement',
    quickStats: {
      'Fib Zone': '${entryZoneLow.toStringAsFixed(5)} - ${entryZoneHigh.toStringAsFixed(5)}',
      'Impulse': (fibHigh - fibLow).toStringAsFixed(5),
      'Grade': 'B',
    },
    structure: {
      'Swing High': fibHigh.toStringAsFixed(5),
      'Swing Low': fibLow.toStringAsFixed(5),
    },
    detail: direction == 'LONG'
        ? 'একটি bullish impulse leg-এর পর দাম 50-79% Fibonacci zone-এ retrace করে reversal তৈরি করেছে।'
        : 'একটি bearish impulse leg-এর পর দাম 50-79% Fibonacci zone-এ retrace করে reversal তৈরি করেছে।',
  );

  return result.isStructurallyValid ? result : const StrategyResult.none();
}
