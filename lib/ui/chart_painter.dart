import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/models.dart';

/// মিনি ক্যান্ডেলস্টিক চার্ট — বাবলের ভিতরে সাম্প্রতিক প্রাইস অ্যাকশন
/// দেখানোর জন্য। কোনো নির্দিষ্ট লেভেল হাইলাইট করতে চাইলে entry/sl লেভেল
/// আলাদা লাইন হিসেবে আঁকা যাবে (levelLines প্যারামিটার দিয়ে)।
class CandleChartPainter extends CustomPainter {
  final List<Candle> candles;
  final Map<String, double> levelLines; // লেবেল -> প্রাইস (যেমন 'Entry': 1.0823)
  final Map<String, Color> levelColors;

  CandleChartPainter({
    required this.candles,
    this.levelLines = const {},
    this.levelColors = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final allHighs = candles.map((c) => c.h).toList();
    final allLows = candles.map((c) => c.l).toList();
    var maxH = allHighs.reduce(max);
    var minL = allLows.reduce(min);

    // লেভেল লাইনগুলোও রেঞ্জের মধ্যে ধরা হয়, নাহলে চার্টের বাইরে চলে যেতে পারে
    for (final v in levelLines.values) {
      if (v > maxH) maxH = v;
      if (v < minL) minL = v;
    }

    final range = (maxH - minL) == 0 ? 0.0001 : (maxH - minL);
    final slotW = size.width / candles.length;
    final bodyW = slotW * 0.6;

    double yFor(double v) => size.height - ((v - minL) / range) * size.height;

    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      final cx = slotW * i + slotW / 2;
      final up = c.c >= c.o;
      final color = up ? T.green : T.red;

      canvas.drawLine(
        Offset(cx, yFor(c.h)),
        Offset(cx, yFor(c.l)),
        Paint()
          ..color = color
          ..strokeWidth = 1.2,
      );

      final bodyTop = yFor(max(c.o, c.c));
      final bodyBottom = max(yFor(min(c.o, c.c)), bodyTop + 1.5);
      canvas.drawRect(
        Rect.fromLTRB(cx - bodyW / 2, bodyTop, cx + bodyW / 2, bodyBottom),
        Paint()..color = color,
      );
    }

    // Entry/SL/TP লেভেল লাইন আঁকা (ড্যাশড স্টাইল সিমুলেট করার জন্য ছোট ছোট সেগমেন্ট)
    for (final entry in levelLines.entries) {
      final y = yFor(entry.value);
      final lineColor = levelColors[entry.key] ?? T.muted;
      const dashWidth = 5.0, dashGap = 3.0;
      var startX = 0.0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(min(startX + dashWidth, size.width), y),
          Paint()
            ..color = lineColor.withOpacity(0.8)
            ..strokeWidth = 1,
        );
        startX += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CandleChartPainter oldDelegate) {
    return oldDelegate.candles != candles || oldDelegate.levelLines != levelLines;
  }
}
