import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/models.dart';

const String _systemInstruction =
    'You are a professional forex trading assistant analyzing 11 technical '
    'indicators (ADX+DI, Supertrend, Ichimoku, Fractal, EMA8/21, EMA21/50, '
    'RSI, Bollinger, MACD, Stochastic, Pattern) for a 15-minute chart.\n'
    'You ONLY ever output exactly one line in this exact format, nothing else:\n'
    'DIRECTION|CONFIDENCE|REASON\n'
    'DIRECTION must be exactly CALL or PUT.\n'
    'CONFIDENCE is an integer 0-100.\n'
    'REASON must be written in Bengali (বাংলা), up to about 20 words.\n'
    'Never add greetings, disclaimers, or markdown.\n'
    'Never refuse to answer — always output a definite CALL or PUT.';

String _voteDump(Map<String, String> breakdown) =>
    breakdown.entries.map((e) => '${e.key}:${e.value}').join(', ');

/// Gemini API কল করে চূড়ান্ত মতামত আনে। কোনো কারণে ব্যর্থ হলে (key নেই,
/// network সমস্যা, timeout ইত্যাদি) কখনো crash করে না — বরং একটা
/// ok:false verdict রিটার্ন করে যাতে caller নিরাপদে fallback করতে পারে।
Future<AiVerdict> fetchAiVerdict({
  required String apiKey,
  required String market,
  required EngineSignal engine,
}) async {
  if (apiKey.isEmpty) {
    final fallbackDirection = engine.strength >= 50 ? 'CALL' : 'PUT';
    return AiVerdict(
      ok: false,
      direction: fallbackDirection,
      confidence: 0,
      reason: 'Gemini key নেই — শুধু ইন্ডিকেটর দিয়ে সিদ্ধান্ত নেওয়া হলো।',
      errorType: 'no_key',
    );
  }

  final fallbackDirection = engine.strength >= 50 ? 'CALL' : 'PUT';

  AiVerdict fallback(String reasonBn, String errorType) => AiVerdict(
        ok: false,
        direction: fallbackDirection,
        confidence: 0,
        reason: reasonBn,
        errorType: errorType,
      );

  final prompt = '''
Pair: $market
Technical engine reading: strength=${engine.strength.toStringAsFixed(1)}/100, agreement=${engine.techConfidence}%
All indicator votes: ${_voteDump(engine.breakdown)}

Respond with exactly one line: DIRECTION|CONFIDENCE|REASON
''';

  http.Response res;
  try {
    final uri = Uri.parse(
      '${ApiConfig.geminiBase}/${ApiConfig.geminiModel}:generateContent?key=${Uri.encodeComponent(apiKey)}',
    );
    res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': _systemInstruction}
              ]
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {'temperature': 0.15, 'maxOutputTokens': 100, 'candidateCount': 1},
          }),
        )
        .timeout(const Duration(seconds: 15));
  } on TimeoutException {
    return fallback('Gemini রেসপন্সে সময় বেশি লাগছে, ইঞ্জিন দিয়ে সিদ্ধান্ত নেওয়া হলো।', 'timeout');
  } catch (e) {
    return fallback('নেটওয়ার্ক সমস্যা: $e', 'network');
  }

  Map<String, dynamic> body;
  try {
    body = jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {
    return fallback('Gemini রেসপন্স পার্স করা যায়নি (status ${res.statusCode})', 'parse');
  }

  if (res.statusCode != 200 || body['error'] != null) {
    final err = body['error'] as Map<String, dynamic>?;
    final msg = err?['message']?.toString() ?? 'Unknown error';
    if (res.statusCode == 401 || res.statusCode == 403) {
      return fallback('Gemini API key ভুল বা অবৈধ।', 'auth');
    }
    if (res.statusCode == 429) {
      return fallback('Gemini লিমিট শেষ, একটু পর আবার চেষ্টা করুন।', 'rate_limit');
    }
    return fallback('Gemini error: $msg', 'bad_request');
  }

  final candidates = body['candidates'] as List?;
  final text = (candidates != null && candidates.isNotEmpty)
      ? (candidates[0]['content']?['parts']?[0]?['text']?.toString() ?? '')
      : '';
  if (text.trim().isEmpty) {
    return fallback('Gemini থেকে কোনো উত্তর আসেনি।', 'empty');
  }

  final parts = text.trim().split('|');
  if (parts.length < 3) {
    return fallback('AI রেসপন্স ফরম্যাট ভুল ছিল, ইঞ্জিন দিয়ে সিদ্ধান্ত নেওয়া হলো।', 'format');
  }

  final direction = parts[0].trim().toUpperCase();
  if (direction != 'CALL' && direction != 'PUT') {
    return fallback('AI দিক বুঝতে পারা যায়নি, ইঞ্জিন দিয়ে সিদ্ধান্ত নেওয়া হলো।', 'bad_direction');
  }
  final confidence = int.tryParse(parts[1].trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 50;
  final reason = parts.sublist(2).join('|').trim();

  return AiVerdict(
    ok: true,
    direction: direction,
    confidence: confidence.clamp(0, 100),
    reason: reason.isNotEmpty ? reason : 'কোনো কারণ দেওয়া হয়নি।',
  );
}
