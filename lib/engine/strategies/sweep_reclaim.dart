import '../../core/models.dart';
import '../smart_money.dart';
import '../strategy_result.dart';

const int _triggerWindow = 6;

/// Mode 1: Liquidity Sweep + Reclaim — দাম আগের swing high/low ভেঙে
/// liquidity নিয়ে আবার সেই লেভেলের ভেতরে ফিরে ক্লোজ করলে এন্ট্রি সিগন্যাল।
StrategyResult runSweepReclaim({
  required Map<String, List<Candle>> timeframes,
  required String htfBias4h,
  required String htfBias1h,
}) {
  final ltf = timeframes['15m'];
  final confirm = timeframes['5m'];
  if (ltf == null || ltf.length < 30) return const StrategyResult.none();

  final swings = findSwings(ltf, 2);
  if (swings.swingHighs.length < 2 || swings.swingLows.length < 2) {
    return const StrategyResult.none();
  }

  final lastCandle = ltf.last;
  final atr = calcATR(ltf, 14);
  if (atr == null) return const StrategyResult.none();

  final recentSwingHigh = swings.swingHighs.last;
  final recentSwingLow = swings.swingLows.last;

  final htfAgreesBullish = htfBias4h != 'Bearish';
  final htfAgreesBearish = htfBias4h != 'Bullish';

  String? direction;
  double? sweepLevel;

  final scanStart = ltf.length - 1;
  final scanEnd = (ltf.length - _triggerWindow).clamp(1, ltf.length);

  for (var i = scanStart; i >= scanEnd; i--) {
    final candle = ltf[i];
    if (i - 1 < 0) continue;
    final prev = ltf[i - 1];

    final bullishSweep = prev.l < recentSwingLow.price &&
        (candle.o < candle.c ? candle.o : candle.c) > recentSwingLow.price;
    final bearishSweep = prev.h > recentSwingHigh.price &&
        (candle.o > candle.c ? candle.o : candle.c) < recentSwingHigh.price;

    if (bullishSweep && htfAgreesBullish) {
      direction = 'LONG';
      sweepLevel = recentSwingLow.price;
      break;
    }
    if (bearishSweep && htfAgreesBearish) {
      direction = 'SHORT';
      sweepLevel = recentSwingHigh.price;
      break;
    }
  }

  if (direction == null || sweepLevel == null) return const StrategyResult.none();

  final stillValid =
      direction == 'LONG' ? lastCandle.c > sweepLevel : lastCandle.c < sweepLevel;
  if (!stillValid) return const StrategyResult.none();

  final entry = lastCandle.c;
  final buffer = atr * 0.5;

  double sl, tp1, tp2, tp3;
  if (direction == 'LONG') {
    sl = sweepLevel - buffer;
    final risk = entry - sl;
    if (risk <= 0) return const StrategyResult.none();
    tp1 = entry + risk * 1.5;
    tp3 = entry + risk * 3;
    final structureTarget = swings.swingHighs.last.price;
    tp2 = (structureTarget > tp1 && structureTarget < tp3) ? structureTarget : entry + risk * 2.25;
  } else {
    sl = sweepLevel + buffer;
    final risk = sl - entry;
    if (risk <= 0) return const StrategyResult.none();
    tp1 = entry - risk * 1.5;
    tp3 = entry - risk * 3;
    final structureTarget = swings.swingLows.last.price;
    tp2 = (structureTarget < tp1 && structureTarget > tp3) ? structureTarget : entry - risk * 2.25;
  }

  String bias5m = 'Neutral';
  if (confirm != null && confirm.length >= 2) {
    final c = confirm.last;
    bias5m = c.c > c.o ? 'Bullish' : (c.c < c.o ? 'Bearish' : 'Neutral');
  }

  final strong = (entry - sweepLevel).abs() > atr * 0.5;

  final result = StrategyResult(
    direction: direction,
    strength: strong ? 'Strong' : 'Moderate',
    entry: entry,
    sl: sl,
    tp1: tp1,
    tp2: tp2,
    tp3: tp3,
    bias15m: direction == 'LONG' ? 'Bullish' : 'Bearish',
    bias5m: bias5m,
    pattern: direction == 'LONG'
        ? 'Bullish Liquidity Sweep + Reclaim'
        : 'Bearish Liquidity Sweep + Reclaim',
    quickStats: {
      'Sweep Level': sweepLevel.toStringAsFixed(5),
      'ATR (15m)': atr.toStringAsFixed(5),
      'Grade': strong ? 'A' : 'B',
    },
    structure: {
      'Swept Level': sweepLevel.toStringAsFixed(5),
      'Structure Target': tp2.toStringAsFixed(5),
    },
    detail: direction == 'LONG'
        ? 'দাম আগের একটি swing low ভেঙে liquidity sweep করেছে, তারপর candle body আবার সেই লেভেলের ওপরে ক্লোজ করে reclaim নিশ্চিত করেছে।'
        : 'দাম আগের একটি swing high ভেঙে liquidity sweep করেছে, তারপর candle body আবার সেই লেভেলের নিচে ক্লোজ করে reclaim নিশ্চিত করেছে।',
  );

  return result.isStructurallyValid ? result : const StrategyResult.none();
}
