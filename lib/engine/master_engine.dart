import 'dart:math';
import '../core/models.dart';
import 'indicators.dart';
import 'advanced_indicators.dart';
import 'pattern_engine.dart';

/// ১১টা ইন্ডিকেটরকে একত্র করে একটা EngineSignal তৈরি করে। প্রতিটা
/// ইন্ডিকেটরের নিজস্ব "ভোট" (bullish/bearish) থাকে, এবং সব ভোট মিলিয়ে
/// একটা strength score (0-100) বের হয় — ৫০ মানে নিরপেক্ষ।
EngineSignal runMasterEngine(List<Candle> candles) {
  final breakdown = <String, String>{};
  final indicatorValues = <String, double>{};

  if (candles.length < 60) {
    return EngineSignal(
      strength: 50,
      techConfidence: 50,
      breakdown: {'Status': 'অপর্যাপ্ত ডেটা'},
      indicators: {},
    );
  }

  final closes = candles.map((c) => c.c).toList();
  final lastClose = closes.last;
  indicatorValues['lastClose'] = lastClose;

  double score = 0;
  double maxScore = 0;

  // ১. ADX + DI — weight 16
  final adx = calcADX(candles, 14);
  if (adx != null) {
    double v;
    if (adx['adx']! > 25) {
      v = adx['plusDI']! > adx['minusDI']! ? 16 : -16;
    } else if (adx['adx']! > 20) {
      v = adx['plusDI']! > adx['minusDI']! ? 8 : -8;
    } else {
      v = adx['plusDI']! > adx['minusDI']! ? 4 : -4;
    }
    score += v;
    maxScore += 16;
    breakdown['ADX ${adx['adx']!.toStringAsFixed(0)}'] = v > 0 ? 'BULL' : 'BEAR';
    indicatorValues['adx'] = adx['adx']!;
  } else {
    breakdown['ADX'] = 'NEUTRAL';
  }

  // ২. Supertrend — weight 16
  final st = calcSupertrend(candles, 10, 3);
  if (st != null) {
    final v = st['trend'] == 1 ? 16.0 : -16.0;
    score += v;
    maxScore += 16;
    breakdown['Supertrend'] = v > 0 ? 'BULL' : 'BEAR';
    indicatorValues['supertrendTrend'] = st['trend']!;
  } else {
    breakdown['Supertrend'] = 'NEUTRAL';
  }

  // ৩. Ichimoku Cloud — weight 16
  final ichi = calcIchimoku(candles);
  if (ichi != null) {
    double v;
    if (ichi['aboveCloud'] == 1) {
      v = 16;
    } else if (ichi['belowCloud'] == 1) {
      v = -16;
    } else if (ichi['tkCross'] != 0) {
      v = ichi['tkCross']! * 4;
    } else {
      v = lastClose >= ichi['kijun']! ? 4 : -4;
    }
    score += v;
    maxScore += 16;
    breakdown['Ichimoku'] = v > 0 ? 'BULL' : 'BEAR';
  } else {
    breakdown['Ichimoku'] = 'NEUTRAL';
  }

  // ৪. Fractal — weight 16, বয়স বাড়ার সাথে সাথে গুরুত্ব কমে
  final fractal = calcFractal(candles, 2);
  if (fractal != null) {
    final decay = max(0.0, 1 - fractal['age']! * 0.15);
    final v = fractal['type'] == 1 ? 16 * decay : -16 * decay;
    score += v;
    maxScore += 16;
    breakdown['Fractal'] = fractal['type'] == 1 ? 'BULL' : 'BEAR';
  } else {
    final isBullMomentum = lastClose > closes[max(0, closes.length - 4)];
    score += isBullMomentum ? 8.0 : -8.0;
    maxScore += 16;
    breakdown['Fractal'] = isBullMomentum ? 'BULL' : 'BEAR';
  }

  // ৫. EMA 8/21 — weight up to 14
  final ema8 = ema(closes, 8);
  final ema21 = ema(closes, 21);
  if (ema8 != null && ema21 != null) {
    final gap = ((ema8 - ema21) / ema21).abs() * 100;
    final w = min(14.0, gap * 250);
    final v = ema8 > ema21 ? w : -w;
    score += v;
    maxScore += 14;
    breakdown['EMA 8/21'] = v > 0 ? 'BULL' : 'BEAR';
  } else {
    breakdown['EMA 8/21'] = 'NEUTRAL';
  }

  // ৬. EMA 21/50 — weight 12
  final ema50 = ema(closes, 50);
  if (ema21 != null && ema50 != null) {
    final v = ema21 > ema50 ? 12.0 : -12.0;
    score += v;
    maxScore += 12;
    breakdown['EMA 21/50'] = v > 0 ? 'BULL' : 'BEAR';
  } else {
    breakdown['EMA 21/50'] = 'NEUTRAL';
  }

  // ৭. RSI — weight up to 14
  final r = rsi(closes, 14);
  if (r != null) {
    double v;
    if (r < 25) {
      v = 14;
    } else if (r < 35) {
      v = 9;
    } else if (r < 45) {
      v = 3;
    } else if (r > 75) {
      v = -14;
    } else if (r > 65) {
      v = -9;
    } else if (r > 55) {
      v = -3;
    } else {
      v = r >= 50 ? 1 : -1;
    }
    score += v;
    maxScore += 14;
    breakdown['RSI ${r.toStringAsFixed(0)}'] = v > 0 ? 'BULL' : 'BEAR';
    indicatorValues['rsi'] = r;
  } else {
    breakdown['RSI'] = 'NEUTRAL';
  }

  // ৮. Bollinger Bands — weight up to 12
  final bb = bollingerBands(closes, 20);
  if (bb != null) {
    final pct = (lastClose - bb['lower']!) / (bb['upper']! - bb['lower']!);
    double v;
    if (pct < 0.05) {
      v = 12;
    } else if (pct < 0.2) {
      v = 7;
    } else if (pct < 0.4) {
      v = 3;
    } else if (pct > 0.95) {
      v = -12;
    } else if (pct > 0.8) {
      v = -7;
    } else if (pct > 0.6) {
      v = -3;
    } else {
      v = pct >= 0.5 ? 1 : -1;
    }
    score += v;
    maxScore += 12;
    breakdown['Bollinger'] = v > 0 ? 'BULL' : 'BEAR';
  } else {
    breakdown['Bollinger'] = 'NEUTRAL';
  }

  // ৯. MACD — weight 12
  final m = macd(closes);
  if (m != null) {
    final crossVote = m['line']! > m['signal']! ? 7.0 : -7.0;
    final histVote = m['hist']! > 0 ? 5.0 : -5.0;
    score += crossVote + histVote;
    maxScore += 12;
    breakdown['MACD'] = (crossVote + histVote) > 0 ? 'BULL' : 'BEAR';
  } else {
    breakdown['MACD'] = 'NEUTRAL';
  }

  // ১০. Stochastic — weight up to 10
  final stoch = stochastic(candles, 14);
  if (stoch != null) {
    double v;
    if (stoch < 20) {
      v = 10;
    } else if (stoch < 35) {
      v = 5;
    } else if (stoch > 80) {
      v = -10;
    } else if (stoch > 65) {
      v = -5;
    } else {
      v = stoch >= 50 ? 1 : -1;
    }
    score += v;
    maxScore += 10;
    breakdown['Stoch ${stoch.toStringAsFixed(0)}'] = v > 0 ? 'BULL' : 'BEAR';
  } else {
    breakdown['Stoch'] = 'NEUTRAL';
  }

  // ১১. Candle Pattern — weight 10
  final pattern = patternScore(candles);
  indicatorValues['patternScore'] = pattern.toDouble();
  if (pattern != 0) {
    final v = pattern * 5.0;
    score += v;
    maxScore += 10;
    breakdown['Pattern'] = v > 0 ? 'BULL' : 'BEAR';
  } else {
    final lastCandle = candles.last;
    final isBullCandle = lastCandle.c > lastCandle.o;
    score += isBullCandle ? 5.0 : -5.0;
    maxScore += 10;
    breakdown['Pattern'] = isBullCandle ? 'BULL' : 'BEAR';
  }

  if (maxScore == 0) maxScore = 1;
  final strength = (((score / maxScore) + 1) / 2 * 100).clamp(0.0, 100.0).toDouble();
  final bulls = breakdown.values.where((e) => e == 'BULL').length;
  final bears = breakdown.values.where((e) => e == 'BEAR').length;
  final total = max(1, bulls + bears);
  final techConfidence = ((max(bulls, bears) / total) * 100).round();

  return EngineSignal(
    strength: strength,
    techConfidence: techConfidence,
    breakdown: breakdown,
    indicators: indicatorValues,
  );
}
