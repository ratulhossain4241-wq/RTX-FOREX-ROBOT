import '../core/models.dart';

/// একটা swing high বা swing low পয়েন্ট — কোন index-এ, কোন দামে, কখন।
class SwingPoint {
  final int index;
  final double price;
  final String time;
  const SwingPoint({required this.index, required this.price, required this.time});
}

class OrderBlockZone {
  final int index;
  final double high, low;
  final String time;
  const OrderBlockZone({required this.index, required this.high, required this.low, required this.time});
}

class FairValueGap {
  final String type; // 'bullish' or 'bearish'
  final double top, bottom;
  final int index;
  const FairValueGap({required this.type, required this.top, required this.bottom, required this.index});
}

class BosChochResult {
  final String type; // 'BOS' or 'CHoCH'
  final String direction; // 'bullish' or 'bearish'
  final double level;
  const BosChochResult({required this.type, required this.direction, required this.level});
}

class SwingResult {
  final List<SwingPoint> swingHighs;
  final List<SwingPoint> swingLows;
  const SwingResult({required this.swingHighs, required this.swingLows});
}

bool isFiniteNumber(double n) => n.isFinite;

double? calcATR(List<Candle> candles, [int period = 14]) {
  if (candles.length < period + 1) return null;
  final trueRanges = <double>[];
  for (var i = 1; i < candles.length; i++) {
    final curr = candles[i];
    final prev = candles[i - 1];
    final tr = [
      curr.h - curr.l,
      (curr.h - prev.c).abs(),
      (curr.l - prev.c).abs(),
    ].reduce((a, b) => a > b ? a : b);
    trueRanges.add(tr);
  }
  final lastN = trueRanges.length > period
      ? trueRanges.sublist(trueRanges.length - period)
      : trueRanges;
  final sum = lastN.reduce((a, b) => a + b);
  return sum / lastN.length;
}

/// সাম্প্রতিক swing high/low গুলো খুঁজে বের করে — "সর্বশেষ ক্যান্ডেল বাদ
/// পড়ে যাওয়া" বাগ এড়াতে upper bound সাবধানে সেট করা হয়েছে।
SwingResult findSwings(List<Candle> candles, [int lookback = 2]) {
  final swingHighs = <SwingPoint>[];
  final swingLows = <SwingPoint>[];

  for (var i = lookback; i < candles.length - 1; i++) {
    final c = candles[i];
    final from = (i - lookback).clamp(0, candles.length - 1);
    final to = (i + lookback).clamp(0, candles.length - 1);
    final window = candles.sublist(from, to + 1);

    final maxHigh = window.map((w) => w.h).reduce((a, b) => a > b ? a : b);
    final minLow = window.map((w) => w.l).reduce((a, b) => a < b ? a : b);

    if (c.h == maxHigh) {
      swingHighs.add(SwingPoint(index: i, price: c.h, time: c.time));
    }
    if (c.l == minLow) {
      swingLows.add(SwingPoint(index: i, price: c.l, time: c.time));
    }
  }
  return SwingResult(swingHighs: swingHighs, swingLows: swingLows);
}

double? _calcAvgRange(List<Candle> candles) {
  if (candles.isEmpty) return null;
  final sum = candles.fold<double>(0, (a, c) => a + (c.h - c.l));
  return sum / candles.length;
}

/// শেষ ৫০ ক্যান্ডেলের মধ্যেই order block খুঁজবে — পুরনো, অপ্রাসঙ্গিক
/// zone কখনো রিটার্ন করবে না।
OrderBlockZone? detectOrderBlock(List<Candle> candles, String direction) {
  if (candles.length < 5) return null;
  final scanFrom = (candles.length - 50).clamp(1, candles.length);

  for (var i = candles.length - 3; i >= scanFrom; i--) {
    final c = candles[i];
    if (i + 1 >= candles.length) continue;
    final next = candles[i + 1];

    final isBearishCandle = c.c < c.o;
    final isBullishCandle = c.c > c.o;
    final displacement = (next.c - next.o).abs();
    final rangeSlice = candles.sublist((i - 10).clamp(0, candles.length), i);
    final avgRange = _calcAvgRange(rangeSlice);
    if (avgRange == null || avgRange == 0) continue;

    if (direction == 'LONG' &&
        isBearishCandle &&
        next.c > next.o &&
        displacement > avgRange * 1.5) {
      return OrderBlockZone(index: i, high: c.h, low: c.l, time: c.time);
    }
    if (direction == 'SHORT' &&
        isBullishCandle &&
        next.c < next.o &&
        displacement > avgRange * 1.5) {
      return OrderBlockZone(index: i, high: c.h, low: c.l, time: c.time);
    }
  }
  return null;
}

List<FairValueGap> detectFVG(List<Candle> candles) {
  final gaps = <FairValueGap>[];
  for (var i = 0; i < candles.length - 2; i++) {
    final a = candles[i];
    final c = candles[i + 2];
    if (a.h < c.l) {
      gaps.add(FairValueGap(type: 'bullish', top: c.l, bottom: a.h, index: i + 1));
    } else if (a.l > c.h) {
      gaps.add(FairValueGap(type: 'bearish', top: a.l, bottom: c.h, index: i + 1));
    }
  }
  return gaps;
}

/// শুধু সাম্প্রতিক (শেষ ৫০ ক্যান্ডেলের মধ্যে) কাঠামোগত ব্রেক-ই ধরা হয় —
/// ২০০ ক্যান্ডেল আগের পুরনো ব্রেককে আজকের "সক্রিয় শিফট" হিসেবে ধরা হয় না।
BosChochResult? detectBOSCHoCH(List<Candle> candles) {
  final swings = findSwings(candles, 2);
  if (swings.swingHighs.length < 2 || swings.swingLows.length < 2) return null;

  final lastClose = candles.last.c;
  final lastSwingHigh = swings.swingHighs.last;
  final lastSwingLow = swings.swingLows.last;
  final prevSwingHigh = swings.swingHighs[swings.swingHighs.length - 2];
  final prevSwingLow = swings.swingLows[swings.swingLows.length - 2];

  final recentThreshold = candles.length - 50;
  final highIsRecent = lastSwingHigh.index >= recentThreshold;
  final lowIsRecent = lastSwingLow.index >= recentThreshold;

  if (highIsRecent && lastClose > lastSwingHigh.price) {
    final trendWasUp = lastSwingHigh.price > prevSwingHigh.price;
    return BosChochResult(
      type: trendWasUp ? 'BOS' : 'CHoCH',
      direction: 'bullish',
      level: lastSwingHigh.price,
    );
  }
  if (lowIsRecent && lastClose < lastSwingLow.price) {
    final trendWasDown = lastSwingLow.price < prevSwingLow.price;
    return BosChochResult(
      type: trendWasDown ? 'BOS' : 'CHoCH',
      direction: 'bearish',
      level: lastSwingLow.price,
    );
  }
  return null;
}

/// Higher-timeframe (4h/1h) bias — ট্রেডের দিক HTF-এর সাথে মিলছে কি না
/// যাচাই করতে সব স্ট্র্যাটেজি মোডেই ব্যবহৃত হয়।
String getHtfBias(List<Candle> candles) {
  final result = detectBOSCHoCH(candles);
  if (result == null) return 'Neutral';
  return result.direction == 'bullish' ? 'Bullish' : 'Bearish';
}
