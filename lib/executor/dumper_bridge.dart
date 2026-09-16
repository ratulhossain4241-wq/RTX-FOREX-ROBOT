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

  /// ✅ ফিক্স: delaySeconds যোগ হলো — বাটন চাপার সময় এই অ্যাপই active
  /// window থাকে, তাই সাথে সাথে dump করলে ব্যর্থ হবে। এই delay চলাকালীন
  /// ইউজার MT5-এ সুইচ করবে, তারপর নেটিভ কোড দেরিতে dump করবে।
  static Future<String> dumpNow({int delaySeconds = 5}) async {
    try {
      final path = await _channel.invokeMethod<String>('dumpNow', {'delaySeconds': delaySeconds});
      if (path == null) throw DumperException('Dump ব্যর্থ হয়েছে — অজানা কারণ।');
      return path;
    } on PlatformException catch (e) {
      if (e.code == 'SERVICE_NOT_RUNNING') {
        throw DumperException('Accessibility Service চালু নেই — আগে সেটিংস থেকে এনাবল করুন।');
      }
      if (e.code == 'DUMP_FAILED') {
        throw DumperException('কোনো active window পাওয়া যায়নি — সময়মতো MT5-এ সুইচ করেছেন তো?');
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
