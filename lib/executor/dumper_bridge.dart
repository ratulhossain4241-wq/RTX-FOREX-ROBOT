import 'package:flutter/services.dart';

/// MainActivity.kt-এর MethodChannel-এর সাথে Dart সাইডের সংযোগ।
class DumperBridge {
  static const MethodChannel _channel = MethodChannel('rtx_auto_trader/native');

  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  /// ✅ ফিক্স: এই কল এখন সাথে সাথেই ফিরে আসে (শুধু "শিডিউল করা হলো"
  /// নিশ্চিত করে) — আসল dump কাজ নেটিভ সাইডে AccessibilityService
  /// independent ভাবে চালায়। তাই MainActivity ব্যাকগ্রাউন্ডে গিয়ে
  /// recreate হলেও (MT5-এ সুইচ করার সময় প্রায়ই হয়) কোনো ফলাফল হারায় না।
  static Future<void> scheduleDump({int delaySeconds = 5}) async {
    try {
      await _channel.invokeMethod('scheduleDump', {'delaySeconds': delaySeconds});
    } on PlatformException catch (e) {
      if (e.code == 'SERVICE_NOT_RUNNING') {
        throw DumperException('Accessibility Service চালু নেই — আগে সেটিংস থেকে এনাবল করুন।');
      }
      throw DumperException(e.message ?? 'অজানা সমস্যা হয়েছে।');
    }
  }

  static Future<List<String>> listDumps() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('listDumps');
      return result?.map((e) => e.toString()).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<String> readDump(String fileName) async {
    try {
      final result = await _channel.invokeMethod<String>('readDump', {'fileName': fileName});
      return result ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<bool> deleteDump(String fileName) async {
    try {
      final result = await _channel.invokeMethod<bool>('deleteDump', {'fileName': fileName});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}

class DumperException implements Exception {
  final String messageBn;
  const DumperException(this.messageBn);

  @override
  String toString() => messageBn;
}
