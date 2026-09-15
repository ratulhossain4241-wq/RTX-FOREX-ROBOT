/// প্রতিটা স্ট্র্যাটেজি মোড (Sweep, CRT+TBS, QM+SMC, ইত্যাদি) এই একই
/// কাঠামোতে ফলাফল দেয়, যাতে signal_router.dart একটাই কোড দিয়ে সবগুলো
/// সামলাতে পারে। noSignal=true হলে বাকি ফিল্ড অগ্রাহ্য করতে হবে।
class StrategyResult {
  final bool noSignal;
  final String? direction; // 'LONG' or 'SHORT'
  final String? strength; // 'Strong' or 'Moderate' or 'Weak'
  final double? entry;
  final double? sl;
  final double? tp1;
  final double? tp2;
  final double? tp3;
  final String? bias15m;
  final String? bias5m;
  final String? pattern;
  final String? detail; // বাংলায় ব্যাখ্যা
  final Map<String, String> quickStats;
  final Map<String, String> structure;

  const StrategyResult.none()
      : noSignal = true,
        direction = null,
        strength = null,
        entry = null,
        sl = null,
        tp1 = null,
        tp2 = null,
        tp3 = null,
        bias15m = null,
        bias5m = null,
        pattern = null,
        detail = null,
        quickStats = const {},
        structure = const {};

  const StrategyResult({
    required this.direction,
    required this.strength,
    required this.entry,
    required this.sl,
    required this.tp1,
    required this.tp2,
    required this.tp3,
    required this.bias15m,
    required this.bias5m,
    required this.pattern,
    required this.detail,
    this.quickStats = const {},
    this.structure = const {},
  }) : noSignal = false;

  /// TP-এর ক্রম, SL-এর দিক, আর কোনো NaN/Infinity আছে কি না — সব একসাথে
  /// যাচাই করে। এই চেক ফেল করলে সিগন্যাল ব্যবহার করা নিরাপদ না।
  bool get isStructurallyValid {
    if (noSignal) return false;
    final nums = [entry, sl, tp1, tp2, tp3];
    if (nums.any((n) => n == null || !n.isFinite)) return false;

    final e = entry!, s = sl!, t1 = tp1!, t2 = tp2!, t3 = tp3!;
    if (direction == 'LONG') {
      if (s >= e) return false;
      if (!(t1 < t2 && t2 < t3 && t1 > e)) return false;
    } else if (direction == 'SHORT') {
      if (s <= e) return false;
      if (!(t1 > t2 && t2 > t3 && t1 < e)) return false;
    } else {
      return false;
    }
    return true;
  }
}
