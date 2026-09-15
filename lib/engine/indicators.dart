import 'dart:math';
import '../core/models.dart';

/// মৌলিক ৫টা ইন্ডিকেটর: EMA, RSI, Bollinger, MACD, Stochastic
/// প্রতিটা ফাংশন null রিটার্ন করে যদি candle সংখ্যা যথেষ্ট না থাকে —
/// কখনো ভুল/অনুমান করা মান রিটার্ন করে না।

double? ema(List<double> a, int period) {
  if (a.length < period) return null;
  final k = 2 / (period + 1);
  var v = a.sublist(0, period).reduce((x, y) => x + y) / period;
  for (var i = period; i < a.length; i++) {
    v = a[i] * k + v * (1 - k);
  }
  return v;
}

double? rsi(List<double> a, [int period = 14]) {
  if (a.length < period + 1) return null;
  final s = a.sublist(a.length - period - 1);
  final changes = <double>[];
  for (var i = 1; i < s.length; i++) {
    changes.add(s[i] - s[i - 1]);
  }
  final avgGain = changes.where((e) => e > 0).fold(0.0, (x, y) => x + y) / period;
  final avgLoss = changes.where((e) => e < 0).fold(0.0, (x, y) => x - y) / period;
  if (avgLoss == 0) return 100;
  return 100 - 100 / (1 + avgGain / avgLoss);
}

Map<String, double>? bollingerBands(List<double> a, [int period = 20]) {
  if (a.length < period) return null;
  final s = a.sublist(a.length - period);
  final mid = s.reduce((x, y) => x + y) / period;
  final variance = s.map((v) => pow(v - mid, 2)).reduce((x, y) => x + y) / period;
  final std = sqrt(variance);
  return {'upper': mid + 2 * std, 'mid': mid, 'lower': mid - 2 * std};
}

Map<String, double>? macd(List<double> a) {
  if (a.length < 35) return null;
  final series = <double>[];
  for (var i = a.length - 9; i < a.length; i++) {
    final sl = a.sublist(0, i + 1);
    final e12 = ema(sl, 12);
    final e26 = ema(sl, 26);
    if (e12 != null && e26 != null) series.add(e12 - e26);
  }
  if (series.length < 9) return null;
  final signal = series.reduce((x, y) => x + y) / 9;
  final line = series.last;
  return {'line': line, 'signal': signal, 'hist': line - signal};
}

double? stochastic(List<Candle> candles, [int period = 14]) {
  if (candles.length < period) return null;
  final s = candles.sublist(candles.length - period);
  final highest = s.map((e) => e.h).reduce(max);
  final lowest = s.map((e) => e.l).reduce(min);
  if (highest == lowest) return 50;
  return ((candles.last.c - lowest) / (highest - lowest)) * 100;
}
