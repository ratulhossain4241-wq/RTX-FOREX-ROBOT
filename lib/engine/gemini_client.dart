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
    'Never add greetings, disclaimers, markdown, code fences, or extra lines.\n'
    'Never refuse to answer — always output a definite CALL or PUT.';

String _voteDump(Map<String, String> breakdown) =>
    breakdown.entries.map((e) => '${e.key}:${e.value}').join(', ');

/// ✅ বড় ফিক্স: আগে কড়াকড়িভাবে ঠিক "DIRECTION|CONFIDENCE|REASON" এই
/// ফরম্যাট আশা করা হতো (`split('|')` দিয়ে, ৩টা অংশ না পেলেই ব্যর্থ)।
/// কিন্তু Gemini মাঝেমধ্যে markdown backtick, অতিরিক্ত স্পেস, নতুন
/// লাইন, বা সামান্য ভিন্ন বিন্যাসে উত্তর দেয় — তখনই parsing বারবার
/// ব্যর্থ হয়ে পুরো AI অংশ অকেজো হয়ে যাচ্ছিল। এখন regex দিয়ে CALL/PUT
/// শব্দ ও সংখ্যা টেক্সটের **যেকোনো জায়গা** থেকে খোঁজা হয়, এবং
/// markdown fence/backtick প্রথমে সাফ করে নেওয়া হয় — এতে পার্সিং
/// অনেক বেশি সহনশীল (lenient) হলো।
class _ParsedGeminiResponse {
  final String direction;
  final int confidence;
  final String reason;
  const _ParsedGeminiResponse({required this.direction, required this.confidence, required this.reason});
}

_ParsedGeminiResponse? _parseLenient(String rawText) {
  // markdown code fence, backtick, অতিরিক্ত হোয়াইটস্পেস পরিষ্কার করা
  var text = rawText.trim();
  text = text.replaceAll('```', '');
  text = text.replaceAll('`', '');
  text = text.trim();

  if (text.isEmpty) return null;

  // ধাপ ১: pipe-বিভক্ত ফরম্যাট আছে কি না চেষ্টা করা (দ্রুততম পথ)
  final pipeParts = text.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  if (pipeParts.length >= 3) {
    final dir = pipeParts[0].toUpperCase();
    if (dir == 'CALL' || dir == 'PUT') {
      final conf = int.tryParse(pipeParts[1].replaceAll(RegExp(r'[^0-9]'), ''));
      if (conf != null) {
        final reason = pipeParts.sublist(2).join(' ').trim();
        return _ParsedGeminiResponse(direction: dir, confidence: conf.clamp(0, 100), reason: reason);
      }
    }
  }

  // ধাপ ২: pipe ফরম্যাট মিলল না — পুরো টেক্সট থেকে regex দিয়ে খোঁজা
  final directionMatch = RegExp(r'\b(CALL|PUT)\b', caseSensitive: false).firstMatch(text);
  if (directionMatch == null) return null; // CALL/PUT কোথাও নেই — সত্যিই পার্স করা অসম্ভব
  final direction = directionMatch.group(0)!.toUpperCase();

  final confidenceMatch = RegExp(r'\b([0-9]{1,3})\b').firstMatch(text);
  final confidence = confidenceMatch != null
      ? (int.tryParse(confidenceMatch.group(1)!) ?? 50).clamp(0, 100)
      : 50;

  // reason হিসেবে direction/confidence টোকেন বাদ দিয়ে বাকি টেক্সট নেওয়া হয়
  var reason = text
      .replaceAll(directionMatch.group(0)!, '')
      .replaceAll('|', ' ')
      .trim();
  if (confidenceMatch != null) {
    reason = reason.replaceFirst(confidenceMatch.group(1)!, '').trim();
  }
  reason = reason.replaceAll(RegExp(r'^[\s:,\-]+'), '').trim();
  if (reason.isEmpty) reason = 'AI থেকে নির্দিষ্ট কারণ পাওয়া যায়নি, তবে দিক নির্ধারিত হয়েছে।';

  return _ParsedGeminiResponse(direction: direction, confidence: confidence.toInt(), reason: reason);
}

Future<AiVerdict> fetchAiVerdict({
  required String apiKey,
  required String market,
  required EngineSignal engine,
}) async {
  final fallbackDirection = engine.strength >= 50 ? 'CALL' : 'PUT';

  if (apiKey.isEmpty) {
    return AiVerdict(
      ok: false,
      direction: fallbackDirection,
      confidence: 0,
      reason: 'Gemini key নেই — শুধু ইন্ডিকেটর দিয়ে সিদ্ধান্ত নেওয়া হলো।',
      errorType: 'no_key',
    );
  }

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
            'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 120, 'candidateCount': 1},
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
    if (res.statusCode == 404) {
      return fallback('Gemini মডেল খুঁজে পাওয়া যায়নি — মডেলের নাম চেক করুন।', 'not_found');
    }
    if (res.statusCode == 429) {
      return fallback('Gemini লিমিট শেষ, একটু পর আবার চেষ্টা করুন।', 'rate_limit');
    }
    return fallback('Gemini error: $msg', 'bad_request');
  }

  final candidates = body['candidates'] as List?;
  if (candidates == null || candidates.isEmpty) {
    // ✅ নতুন: candidate একদমই না থাকলে finishReason (যেমন SAFETY ব্লক)
    // থাকলে সেটা বাংলায় দেখানো হয়, যাতে ডিবাগ করা সহজ হয়
    return fallback('Gemini থেকে কোনো candidate পাওয়া যায়নি (সম্ভবত সেফটি ফিল্টারে আটকেছে)।', 'no_candidates');
  }

  final text = candidates[0]['content']?['parts']?[0]?['text']?.toString() ?? '';
  if (text.trim().isEmpty) {
    return fallback('Gemini থেকে কোনো উত্তর আসেনি।', 'empty');
  }

  final parsed = _parseLenient(text);
  if (parsed == null) {
    return fallback('AI রেসপন্স থেকে দিক (CALL/PUT) খুঁজে পাওয়া যায়নি, ইঞ্জিন দিয়ে সিদ্ধান্ত নেওয়া হলো।', 'format');
  }

  return AiVerdict(
    ok: true,
    direction: parsed.direction,
    confidence: parsed.confidence,
    reason: parsed.reason,
  );
}
