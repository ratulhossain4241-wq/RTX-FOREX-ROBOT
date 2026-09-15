import 'dart:math';
import '../core/models.dart';

/// উচ্চ-নির্ভরযোগ্যতার ৪টা ইন্ডিকেটর: ADX+DI, Supertrend, Ichimoku,
/// Fractal — এগুলো মূল ইঞ্জিনে সবচেয়ে বেশি ওজন (weight) পায়, কারণ
/// এরা ট্রেন্ড ও রিভার্সাল উভয়ই শক্তিশালীভাবে শনাক্ত করে।

Map<String, double>? calcADX(List<Candle> candles, [int period = 14]) {
  if (candles.length < period * 2 + 1) return null;
  final highs = candles.map((c) => c.h).toList();
  final lows = candles.map((c) => c.l).toList();
  final closes = candles.map((c) => c.c).toList();

  final plusDM = <double>[], minusDM = <double>[], trs = <double>[];
  for (var i = 1; i < candles.length; i++) {
    final upMove = highs[i] - highs[i - 1];
    final downMove = lows[i - 1] - lows[i];
    plusDM.add(upMove > downMove && upMove > 0 ? upMove : 0);
    minusDM.add(downMove > upMove && downMove > 0 ? downMove : 0);
    trs.add([
      highs[i] - lows[i],
      (highs[i] - closes[i - 1]).abs(),
      (lows[i] - closes[i - 1]).abs(),
    ].reduce(max));
  }

  List<double> wilderSmooth(List<double> arr, int p) {
    final out = <double>[arr.sublist(0, p).reduce((a, b) => a + b)];
    for (var i = p; i < arr.length; i++) {
      out.add(out.last - out.last / p + arr[i]);
    }
    return out;
  }

  final sTR = wilderSmooth(trs, period);
  final sPlus = wilderSmooth(plusDM, period);
  final sMinus = wilderSmooth(minusDM, period);

  final plusDI = <double>[], minusDI = <double>[];
  for (var i = 0; i < sPlus.length; i++) {
    final trv = sTR[i] == 0 ? 1 : sTR[i];
    plusDI.add(100 * sPlus[i] / trv);
    minusDI.add(100 * sMinus[i] / trv);
  }
  final dx = <double>[];
  for (var i = 0; i < plusDI.length; i++) {
    final denom = (plusDI[i] + minusDI[i]) == 0 ? 1 : (plusDI[i] + minusDI[i]);
    dx.add(100 * (plusDI[i] - minusDI[i]).abs() / denom);
  }

  if (dx.length < period) return null;
  var adxVal = dx.sublist(0, period).reduce((a, b) => a + b) / period;
  for (var i = period; i < dx.length; i++) {
    adxVal = (adxVal * (period - 1) + dx[i]) / period;
  }
  return {'adx': adxVal, 'plusDI': plusDI.last, 'minusDI': minusDI.last};
}

Map<String, double>? calcSupertrend(List<Candle> candles, [int period = 10, double mult = 3]) {
  if (candles.length < period + 2) return null;
  final highs = candles.map((c) => c.h).toList();
  final lows = candles.map((c) => c.l).toList();
  final closes = candles.map((c) => c.c).toList();

  final trs = <double>[];
  for (var i = 1; i < candles.length; i++) {
    trs.add([
      highs[i] - lows[i],
      (highs[i] - closes[i - 1]).abs(),
      (lows[i] - closes[i - 1]).abs(),
    ].reduce(max));
  }
  var atrVal = trs.sublist(0, period).reduce((a, b) => a + b) / period;
  final atrSeries = <double>[atrVal];
  for (var i = period; i < trs.length; i++) {
    atrVal = (atrVal * (period - 1) + trs[i]) / period;
    atrSeries.add(atrVal);
  }

  var trend = 1;
  var finalUpper = 0.0, finalLower = 0.0;
  final offset = candles.length - atrSeries.length;
  for (var i = 0; i < atrSeries.length; i++) {
    final idx = i + offset;
    final hl2 = (highs[idx] + lows[idx]) / 2;
    final bUpper = hl2 + mult * atrSeries[i];
    final bLower = hl2 - mult * atrSeries[i];
    if (i == 0) {
      finalUpper = bUpper;
      finalLower = bLower;
      continue;
    }
    final prevClose = closes[idx - 1];
    finalUpper = (bUpper < finalUpper || prevClose > finalUpper) ? bUpper : finalUpper;
    finalLower = (bLower > finalLower || prevClose < finalLower) ? bLower : finalLower;
    if (trend == 1 && closes[idx] < finalLower) {
      trend = -1;
    } else if (trend == -1 && closes[idx] > finalUpper) {
      trend = 1;
    }
  }
  return {'trend': trend.toDouble(), 'value': trend == 1 ? finalLower : finalUpper};
}

Map<String, double>? calcIchimoku(List<Candle> candles) {
  if (candles.length < 52) return null;
  final highs = candles.map((c) => c.h).toList();
  final lows = candles.map((c) => c.l).toList();
  final close = candles.last.c;

  double periodHL(int p) {
    final hs = highs.sublist(highs.length - p);
    final ls = lows.sublist(lows.length - p);
    return (hs.reduce(max) + ls.reduce(min)) / 2;
  }

  final tenkan = periodHL(9);
  final kijun = periodHL(26);
  final spanA = (tenkan + kijun) / 2;
  final spanB = periodHL(52);
  final aboveCloud = close > max(spanA, spanB);
  final belowCloud = close < min(spanA, spanB);
  final tkCross = tenkan > kijun ? 1.0 : (tenkan < kijun ? -1.0 : 0.0);

  return {
    'tenkan': tenkan,
    'kijun': kijun,
    'spanA': spanA,
    'spanB': spanB,
    'aboveCloud': aboveCloud ? 1 : 0,
    'belowCloud': belowCloud ? 1 : 0,
    'tkCross': tkCross,
  };
}

/// নিশ্চিত (confirmed) ৫-ক্যান্ডেল ফ্র্যাক্টাল — কখনো repaint হয় না।
/// type: 1 = low (bullish), -1 = high (bearish); age = কনফার্ম হওয়ার
/// পর থেকে কয়টা ক্যান্ডেল পার হয়েছে (যত পুরনো, তত কম গুরুত্ব)।
Map<String, double>? calcFractal(List<Candle> candles, [int n = 2]) {
  if (candles.length < n * 2 + 1) return null;
  final highs = candles.map((c) => c.h).toList();
  final lows = candles.map((c) => c.l).toList();
  final idx = candles.length - 1 - n;
  if (idx < n) return null;

  var isHigh = true, isLow = true;
  for (var i = 1; i <= n; i++) {
    if (!(highs[idx] > highs[idx - i] && highs[idx] > highs[idx + i])) isHigh = false;
    if (!(lows[idx] < lows[idx - i] && lows[idx] < lows[idx + i])) isLow = false;
  }
  final age = candles.length - 1 - (idx + n);
  if (isHigh) return {'type': -1, 'age': age.toDouble()};
  if (isLow) return {'type': 1, 'age': age.toDouble()};
  return null;
}
