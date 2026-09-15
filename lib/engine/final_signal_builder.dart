import '../core/models.dart';

/// accuracy স্কোরের ভিত্তিতে গ্রেড ঠিক করে — CALL আর PUT দুটোই সমান
/// মানদণ্ডে A+ পর্যন্ত পৌঁছাতে পারে, দিক (direction) গ্রেডকে প্রভাবিত করে না।
String _gradeFromAccuracy(int accuracy) {
  if (accuracy >= 88) return 'A+';
  if (accuracy >= 76) return 'A';
  if (accuracy >= 63) return 'B+';
  if (accuracy >= 50) return 'B';
  return 'C';
}

/// টেকনিক্যাল ইঞ্জিন + Gemini-এর মতামত একত্র করে একটা চূড়ান্ত, সবসময়
/// নির্ধারিত (never-undecided) সিদ্ধান্ত তৈরি করে।
FinalSignal buildFinalSignal({
  required EngineSignal engine,
  required AiVerdict ai,
}) {
  final techScore = ((engine.strength - 50).abs() * 2).clamp(0, 100).toDouble();
  final techDirection = engine.strength >= 50 ? 'CALL' : 'PUT';

  String finalDirection;
  int accuracy;
  String reason;

  if (!ai.ok) {
    // Gemini ব্যর্থ হলে শুধু টেকনিক্যাল ইঞ্জিনের ওপর নির্ভর করে, কিন্তু
    // accuracy সর্বোচ্চ ৯৫-এ ক্যাপ করা থাকে (AI confirmation ছাড়া
    // ১০০% নিশ্চয়তা দাবি করা হয় না)।
    finalDirection = techDirection;
    accuracy = ((techScore * 0.7) + (engine.techConfidence * 0.3)).round().clamp(0, 95).toInt();
    reason = ai.reason;
  } else {
    finalDirection = ai.direction;
    final agree = ai.direction == techDirection;
    final base = (techScore * 0.5) + (ai.confidence * 0.5);
    accuracy = agree ? (base + 8).round().clamp(0, 99) : (base - 18).round().clamp(20, 100);
    reason = ai.reason;
  }

  return FinalSignal(
    grade: _gradeFromAccuracy(accuracy),
    direction: finalDirection,
    accuracy: accuracy,
    reason: reason,
  );
}
