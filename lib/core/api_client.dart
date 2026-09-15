import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'models.dart';

/// একসাথে একাধিক timeframe (15m, 1h, 4h, 5m) আনার জন্য request গুলো
/// আলাদা করে ধরে রাখা — কোনো একটা timeframe ব্যর্থ হলেও বাকিগুলো
/// কাজ করতে থাকে (partial failure handle করার জন্য)।
class TimeframeFetchResult {
  final Map<String, List<Candle>> timeframes;
  final Map<String, String> errors; // timeframe -> বাংলা error message
  const TimeframeFetchResult({required this.timeframes, required this.errors});
}

class ApiClient {
  /// Twelve Data থেকে একটা নির্দিষ্ট timeframe-এর ক্যান্ডেল আনে।
  /// শেষ ক্যান্ডেলটা বাদ দেওয়া হয় কারণ সেটা এখনো "চলমান" (unclosed)
  /// ক্যান্ডেল হতে পারে — শুধু বন্ধ হওয়া ক্যান্ডেল দিয়ে বিশ্লেষণ করা নিরাপদ।
  static Future<List<Candle>> fetchCandles({
    required String apiKey,
    required String symbol,
    required String interval, // '1min', '5min', '15min', '1h', '4h'
    int outputSize = 100,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.twelveDataBase}'
      '?symbol=${Uri.encodeComponent(symbol)}'
      '&interval=$interval'
      '&outputsize=$outputSize'
      '&timezone=UTC'
      '&apikey=$apiKey',
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    final data = jsonDecode(res.body) as Map<String, dynamic>;

    if (data['status'] == 'error' || data['values'] == null) {
      final msg = data['message']?.toString() ?? 'অজানা API সমস্যা';
      throw ApiException(msg);
    }

    final rawList = (data['values'] as List).cast<Map<String, dynamic>>();
    final list = rawList.reversed.map(Candle.fromJson).toList();

    // শেষ (এখনো চলমান) ক্যান্ডেলটা বাদ দেওয়া হচ্ছে
    if (list.length > 1) return list.sublist(0, list.length - 1);
    return list;
  }

  /// একসাথে সব প্রয়োজনীয় timeframe আনে। কোনো একটা timeframe ব্যর্থ হলে
  /// সেটার জন্য error জমা রাখে, কিন্তু বাকিগুলো চেষ্টা চালিয়ে যায় —
  /// signal_router.dart-এর "15m must-have, বাকি fallback" লজিকের সাথে মেলে।
  static Future<TimeframeFetchResult> fetchAllTimeframes({
    required String apiKey,
    required String symbol,
  }) async {
    final timeframes = <String, List<Candle>>{};
    final errors = <String, String>{};

    const intervals = {
      '15m': '15min',
      '5m': '5min',
      '1h': '1h',
      '4h': '4h',
    };

    for (final entry in intervals.entries) {
      try {
        final candles = await fetchCandles(
          apiKey: apiKey,
          symbol: symbol,
          interval: entry.value,
          outputSize: entry.key == '4h' || entry.key == '1h' ? 80 : 100,
        );
        timeframes[entry.key] = candles;
      } on ApiException catch (e) {
        errors[entry.key] = e.messageBn;
      } catch (e) {
        errors[entry.key] = 'নেটওয়ার্ক সমস্যা: $e';
      }
    }

    return TimeframeFetchResult(timeframes: timeframes, errors: errors);
  }

  /// লাইভ প্রাইস আনার জন্য হালকা কল — শুধু সর্বশেষ close ব্যবহার করে,
  /// পুরো candle history লাগে না।
  static Future<double?> fetchLivePrice({
    required String apiKey,
    required String symbol,
  }) async {
    try {
      final candles = await fetchCandles(
        apiKey: apiKey,
        symbol: symbol,
        interval: '1min',
        outputSize: 2,
      );
      if (candles.isEmpty) return null;
      return candles.last.c;
    } catch (_) {
      return null;
    }
  }
}

/// API থেকে আসা এরর মেসেজকে বাংলায় বোঝার মতো করে রূপান্তর করে।
class ApiException implements Exception {
  final String rawMessage;
  const ApiException(this.rawMessage);

  String get messageBn {
    final lower = rawMessage.toLowerCase();
    if (lower.contains('credit') || lower.contains('limit')) {
      return 'আজকের API কল লিমিট শেষ — কাল আবার চেষ্টা করুন।';
    }
    if (lower.contains('api key') || lower.contains('apikey')) {
      return 'API Key ভুল বা অবৈধ — সেটিংসে গিয়ে চেক করুন।';
    }
    if (lower.contains('symbol')) {
      return 'এই মার্কেট সিম্বল সাপোর্টেড না।';
    }
    return 'ডেটা আনতে সমস্যা হয়েছে: $rawMessage';
  }

  @override
  String toString() => messageBn;
}
