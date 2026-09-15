import '../../core/models.dart';
import '../smart_money.dart';
import '../strategy_result.dart';

const int _triggerWindow = 8;

/// Mode 2: CRT (Candle Range Theory) + Three-Bar-Setup — একটা বড়
/// Range Candle-এর পর তিনটা ক্যান্ডেলের প্যাটার্নে রিভার্সাল কনফার্ম হলে
/// এন্ট্রি সিগন্যাল।
StrategyResult runCrtTbs({
  required Map<String, List<Candle>> timeframes,
  required String htfBias4h,
  required String htfBias1h,
}) {
  final ltf = timeframes['15m'];
  final confirm = timeframes['5m'];
  if (ltf == null || ltf.length < 30) return const StrategyResult.none();

  final atr = calcATR(ltf, 14);
  if (atr == null) return const StrategyResult.none();

  var rangeCandleIdx = -1;
  final lowerBound = (ltf.length - 20).clamp(0, ltf.length);
  for (var i = ltf.length - 4; i >= lowerBound; i--) {
    final c = ltf[i];
    if (c.h - c.l > atr * 1.8) {
      rangeCandleIdx = i;
      break;
    }
  }
  if (rangeCandleIdx == -1) return const StrategyResult.none();

  final rangeCandle = ltf[rangeCandleIdx];
  final afterRange = ltf.sublist(rangeCandleIdx + 1);
  if (afterRange.length < 3) return const StrategyResult.none();

  final htfAgreesBullish = htfBias4h != 'Bearish';
  final htfAgreesBearish = htfBias4h != 'Bullish';

  String? direction;
  Candle? triggerB2;

  final scanStart = afterRange.length - 1;
  final scanEnd = (afterRange.length - _triggerWindow).clamp(2, afterRange.length);

  for (var j = scanStart; j >= scanEnd; j--) {
    if (j < 2) break;
    final b1 = afterRange[j - 2];
    final b2 = afterRange[j - 1];
    final b3 = afterRange[j];

    final b2BullishBody = b2.o > b2.c ? b2.o : b2.c;
    final b2BearishBody = b2.o < b2.c ? b2.o : b2.c;

    final bullishTBS = b2.l < rangeCandle.l &&
        b2.l <= b1.l &&
        b3.c > b2BullishBody &&
        b3.c > rangeCandle.l;

    final bearishTBS = b2.h > rangeCandle.h &&
        b2.h >= b1.h &&
        b3.c < b2BearishBody &&
        b3.c < rangeCandle.h;

    if (bullishTBS && htfAgreesBullish) {
      direction = 'LONG';
      triggerB2 = b2;
      break;
    }
    if (bearishTBS && htfAgreesBearish) {
      direction = 'SHORT';
      triggerB2 = b2;
      break;
    }
  }

  if (direction == null || triggerB2 == null) return const StrategyResult.none();

  final lastCandle = ltf.last;
  final stillValid =
      direction == 'LONG' ? lastCandle.c > rangeCandle.l : lastCandle.c < rangeCandle.h;
  if (!stillValid) return const StrategyResult.none();

  final entry = lastCandle.c;
  final buffer = atr * 0.5;

  double sl, tp1, tp2, tp3;
  if (direction == 'LONG') {
    sl = triggerB2.l - buffer;
    final risk = entry - sl;
    if (risk <= 0) return const StrategyResult.none();
    tp1 = entry + risk * 1.5;
    tp3 = entry + risk * 3;
    tp2 = (rangeCandle.h > tp1 && rangeCandle.h < tp3) ? rangeCandle.h : entry + risk * 2.25;
  } else {
    sl = triggerB2.h + buffer;
    final risk = sl - entry;
    if (risk <= 0) return const StrategyResult.none();
    tp1 = entry - risk * 1.5;
    tp3 = entry - risk * 3;
    tp2 = (rangeCandle.l < tp1 && rangeCandle.l > tp3) ? rangeCandle.l : entry - risk * 2.25;
  }

  String bias5m = 'Neutral';
  if (confirm != null && confirm.length >= 2) {
    final c = confirm.last;
    bias5m = c.c > c.o ? 'Bullish' : (c.c < c.o ? 'Bearish' : 'Neutral');
  }

  final rangeSizeVsAtr = (rangeCandle.h - rangeCandle.l) / atr;

  final result = StrategyResult(
    direction: direction,
    strength: rangeSizeVsAtr > 2.5 ? 'Strong' : 'Moderate',
    entry: entry,
    sl: sl,
    tp1: tp1,
    tp2: tp2,
    tp3: tp3,
    bias15m: direction == 'LONG' ? 'Bullish' : 'Bearish',
    bias5m: bias5m,
    pattern: direction == 'LONG'
        ? 'Bullish CRT + Three Bar Setup'
        : 'Bearish CRT + Three Bar Setup',
    quickStats: {
      'CRT Range Size': (rangeCandle.h - rangeCandle.l).toStringAsFixed(5),
      'Range vs ATR': '${rangeSizeVsAtr.toStringAsFixed(1)}x',
      'Grade': rangeSizeVsAtr > 2.5 ? 'A' : 'B',
    },
    structure: {
      'CRT High': rangeCandle.h.toStringAsFixed(5),
      'CRT Low': rangeCandle.l.toStringAsFixed(5),
    },
    detail: direction == 'LONG'
        ? 'একটি বড় Range Candle তৈরি হওয়ার পর দাম তার নিচের সীমা ভেঙেছিল, কিন্তু Three Bar Setup দিয়ে আবার রেঞ্জের ভেতরে ফিরে ক্লোজ করেছে — লিকুইডিটি গ্র্যাব করে রিভার্সালের সংকেত।'
        : 'একটি বড় Range Candle তৈরি হওয়ার পর দাম তার ওপরের সীমা ভেঙেছিল, কিন্তু Three Bar Setup দিয়ে আবার রেঞ্জের ভেতরে ফিরে ক্লোজ করেছে — লিকুইডিটি গ্র্যাব করে রিভার্সালের সংকেত।',
  );

  return result.isStructurallyValid ? result : const StrategyResult.none();
}
