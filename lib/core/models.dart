/// ───────────────── CANDLE ─────────────────
class Candle {
  final double o, h, l, c;
  final String time;
  const Candle(this.o, this.h, this.l, this.c, this.time);

  factory Candle.fromJson(Map<String, dynamic> j) => Candle(
        double.parse(j['open'].toString()),
        double.parse(j['high'].toString()),
        double.parse(j['low'].toString()),
        double.parse(j['close'].toString()),
        (j['datetime'] ?? '').toString(),
      );
}

/// ইঞ্জিনের raw আউটপুট — কোনো ভোট এখানে UI-এর জন্য না, বরং router-এর
/// জন্য, যাতে ফাইনাল সিদ্ধান্তের আগে সব ডেটা একসাথে দেখা যায়।
class EngineSignal {
  final double strength; // 0-100
  final int techConfidence; // 0-100
  final Map<String, String> breakdown;
  final Map<String, double> indicators;
  const EngineSignal({
    required this.strength,
    required this.techConfidence,
    required this.breakdown,
    required this.indicators,
  });
}

/// Gemini থেকে আসা ফলাফল — সবসময় ok=false হলেও একটা fallback reason
/// থাকবে, কখনো null থাকবে না, যাতে UI-তে "কিছু না দেখানো" অবস্থা না হয়।
class AiVerdict {
  final bool ok;
  final String direction; // 'CALL' or 'PUT'
  final int confidence; // 0-100
  final String reason;
  final String? errorType;
  const AiVerdict({
    required this.ok,
    required this.direction,
    required this.confidence,
    required this.reason,
    this.errorType,
  });
}

/// ইউজারকে দেখানো ফাইনাল সিদ্ধান্ত — CALL/PUT সবসময় নির্ধারিত থাকে।
class FinalSignal {
  final String grade; // A+, A, B+, B, C
  final String direction; // CALL or PUT
  final int accuracy; // 0-99
  final String reason;
  const FinalSignal({
    required this.grade,
    required this.direction,
    required this.accuracy,
    required this.reason,
  });
}

/// একটা সম্পন্ন (closed) বা চলমান (open) ট্রেডের রেকর্ড — লগ ও
/// রিস্ক-গেট দুই জায়গাতেই ব্যবহৃত হবে।
class TradeRecord {
  final int? id;
  final String market;
  final String direction; // CALL or PUT
  final double entryPrice;
  final double? exitPrice;
  final double lotSize;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String status; // 'open', 'won', 'lost', 'cancelled'
  final double? profitUsd;

  const TradeRecord({
    this.id,
    required this.market,
    required this.direction,
    required this.entryPrice,
    this.exitPrice,
    required this.lotSize,
    required this.openedAt,
    this.closedAt,
    required this.status,
    this.profitUsd,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'market': market,
        'direction': direction,
        'entryPrice': entryPrice,
        'exitPrice': exitPrice,
        'lotSize': lotSize,
        'openedAt': openedAt.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
        'status': status,
        'profitUsd': profitUsd,
      };

  factory TradeRecord.fromMap(Map<String, dynamic> m) => TradeRecord(
        id: m['id'] as int?,
        market: m['market'] as String,
        direction: m['direction'] as String,
        entryPrice: (m['entryPrice'] as num).toDouble(),
        exitPrice: (m['exitPrice'] as num?)?.toDouble(),
        lotSize: (m['lotSize'] as num).toDouble(),
        openedAt: DateTime.parse(m['openedAt'] as String),
        closedAt: m['closedAt'] != null ? DateTime.parse(m['closedAt'] as String) : null,
        status: m['status'] as String,
        profitUsd: (m['profitUsd'] as num?)?.toDouble(),
      );
}

/// ইউজারের বর্তমান রিস্ক সেটিংস — RiskDefaults-এর হার্ড ক্যাপ দিয়ে
/// সবসময় clamp করা থাকবে (risk_engine.dart-এ প্রয়োগ হবে)।
class RiskSettings {
  final double accountBalance;
  final double riskPercent;
  final int maxDailyLosses;
  final int maxConcurrentTrades;
  const RiskSettings({
    required this.accountBalance,
    required this.riskPercent,
    required this.maxDailyLosses,
    required this.maxConcurrentTrades,
  });
}
