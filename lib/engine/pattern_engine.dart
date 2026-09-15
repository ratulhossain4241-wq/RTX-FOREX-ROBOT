import '../core/models.dart';

/// ৩-ক্যান্ডেল প্যাটার্ন বিশ্লেষণ (engulfing, pin bar, momentum রিভার্সাল,
/// টানা ৩টা একই দিকের ক্যান্ডেল)। রিটার্ন মান -2 থেকে 2:
///   2  = শক্তিশালী bullish প্যাটার্ন
///   1  = মৃদু bullish প্যাটার্ন
///   0  = কোনো স্পষ্ট প্যাটার্ন নেই
///  -1  = মৃদু bearish প্যাটার্ন
///  -2  = শক্তিশালী bearish প্যাটার্ন
int patternScore(List<Candle> candles) {
  if (candles.length < 3) return 0;
  final last3 = candles.sublist(candles.length - 3);
  final c2 = last3[0], c1 = last3[1], c0 = last3[2]; // পুরনো → নতুন

  bool isBullish(Candle c) => c.c > c.o;
  double body(Candle c) => (c.c - c.o).abs();

  final c0Body = body(c0), c1Body = body(c1), c2Body = body(c2);
  final lowerWick = [c0.o, c0.c].reduce((a, b) => a < b ? a : b) - c0.l;
  final upperWick = c0.h - [c0.o, c0.c].reduce((a, b) => a > b ? a : b);

  // Bullish engulfing
  if (isBullish(c0) && !isBullish(c1) && c0.o <= c1.c && c0.c >= c1.o && c0Body > c1Body) {
    return 2;
  }
  // Bearish engulfing
  if (!isBullish(c0) && isBullish(c1) && c0.o >= c1.c && c0.c <= c1.o && c0Body > c1Body) {
    return -2;
  }
  // Bullish pin bar (লম্বা নিচের wick)
  if (lowerWick > c0Body * 2 && upperWick < c0Body * 0.3) return 1;
  // Bearish pin bar (লম্বা ওপরের wick)
  if (upperWick > c0Body * 2 && lowerWick < c0Body * 0.3) return -1;
  // Morning-star ধরনের রিভার্সাল
  if (!isBullish(c2) && c1Body < c2Body * 0.3 && isBullish(c0) && c0.c > (c2.o + c2.c) / 2) {
    return 2;
  }
  // Evening-star ধরনের রিভার্সাল
  if (isBullish(c2) && c1Body < c2Body * 0.3 && !isBullish(c0) && c0.c < (c2.o + c2.c) / 2) {
    return -2;
  }
  // টানা ৩টা bullish/bearish ক্যান্ডেল (momentum)
  if (isBullish(c2) && isBullish(c1) && isBullish(c0)) return 1;
  if (!isBullish(c2) && !isBullish(c1) && !isBullish(c0)) return -1;

  return 0;
}
