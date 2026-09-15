import '../core/models.dart';
import '../engine/master_engine.dart';
import '../engine/gemini_client.dart';
import '../engine/final_signal_builder.dart';
import 'signal_router.dart';

/// স্ট্র্যাটেজি মোডের Entry/SL/TP + ১১-ইন্ডিকেটর মাস্টার ইঞ্জিন +
/// Gemini AI — এই তিনটাকে একসাথে যুক্ত করে একটা সম্পূর্ণ, AI-কনফার্মড
/// সিদ্ধান্ত তৈরি করে। এটা ছাড়া Gemini key input করলেও কোনো প্রভাব
/// পড়ত না — এই ফাইলই সেই সংযোগ তৈরি করছে।
class EnrichedSignal {
  final RouterSignal router;
  final EngineSignal engine;
  final AiVerdict ai;
  final FinalSignal finalVerdict;
  const EnrichedSignal({
    required this.router,
    required this.engine,
    required this.ai,
    required this.finalVerdict,
  });

  /// স্ট্র্যাটেজির নিজস্ব দিক (LONG/SHORT) আর AI+ইঞ্জিনের ফাইনাল দিক
  /// (CALL/PUT) যদি না মেলে — এটা একটা সতর্কতা সংকেত, ট্রেড না নেওয়াই ভালো।
  bool get directionsAgree {
    final stratDir = router.strategy?.direction;
    if (stratDir == null) return false;
    final stratAsCallPut = stratDir == 'LONG' ? 'CALL' : 'PUT';
    return stratAsCallPut == finalVerdict.direction;
  }
}

/// রাউটার থেকে একটা ভ্যালিড সিগন্যাল পাওয়ার পর এই ফাংশন কল করে
/// ইঞ্জিন + AI দিয়ে সেটা সমৃদ্ধ (enrich) করা হয়।
Future<EnrichedSignal> enrichSignal({
  required RouterSignal router,
  required List<Candle> candles15m,
  required String geminiApiKey,
  required String marketName,
}) async {
  final engine = runMasterEngine(candles15m);
  final ai = await fetchAiVerdict(
    apiKey: geminiApiKey,
    market: marketName,
    engine: engine,
  );
  final finalVerdict = buildFinalSignal(engine: engine, ai: ai);

  return EnrichedSignal(
    router: router,
    engine: engine,
    ai: ai,
    finalVerdict: finalVerdict,
  );
}
