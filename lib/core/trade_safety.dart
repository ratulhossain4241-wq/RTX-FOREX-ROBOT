/// এক্সিকিউশনের আগে অতিরিক্ত সেফটি চেক করে।
/// ভুল ডেটা বা অস্বাভাবিক ভ্যালু থাকলে ট্রেড আটকে দেয়।
class TradeSafety {
  static SafetyResult checkBeforeExecution({
    required String direction,
    required double entry,
    required double sl,
    required double tp,
    required double lot,
  }) {
    if (direction != 'LONG' && direction != 'SHORT') {
      return SafetyResult(ok: false, message: 'দিক নির্দেশনা ভুল');
    }

    if (entry <= 0 || !entry.isFinite) {
      return SafetyResult(ok: false, message: 'Entry প্রাইস সঠিক নয়');
    }

    if (sl <= 0 || !sl.isFinite) {
      return SafetyResult(ok: false, message: 'Stop Loss সঠিক নয়');
    }

    if (tp <= 0 || !tp.isFinite) {
      return SafetyResult(ok: false, message: 'Take Profit সঠিক নয়');
    }

    if (lot < 0.01 || lot > 50) {
      return SafetyResult(ok: false, message: 'Lot Size অস্বাভাবিক ($lot)');
    }

    // দিক অনুযায়ী SL/TP লজিক চেক
    if (direction == 'LONG') {
      if (sl >= entry) {
        return SafetyResult(ok: false, message: 'LONG ট্রেডে SL এন্ট্রির উপরে থাকতে পারে না');
      }
      if (tp <= entry) {
        return SafetyResult(ok: false, message: 'LONG ট্রেডে TP এন্ট্রির নিচে থাকতে পারে না');
      }
    } else {
      if (sl <= entry) {
        return SafetyResult(ok: false, message: 'SHORT ট্রেডে SL এন্ট্রির নিচে থাকতে পারে না');
      }
      if (tp >= entry) {
        return SafetyResult(ok: false, message: 'SHORT ট্রেডে TP এন্ট্রির উপরে থাকতে পারে না');
      }
    }

    return const SafetyResult(ok: true, message: 'OK');
  }
}

class SafetyResult {
  final bool ok;
  final String message;

  const SafetyResult({required this.ok, required this.message});
}
