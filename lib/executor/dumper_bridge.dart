import 'package:flutter/services.dart';

/// MainActivity.kt-এর MethodChannel-এর সাথে Dart সাইডের সংযোগ।
/// এই ক্লাসটাই একমাত্র জায়গা যেখান থেকে নেটিভ Android কোড কল করা
/// হয় — ভবিষ্যতে Trade Executor বানানোর সময়ও এই একই প্যাটার্নে নতুন
/// মেথড যোগ হবে।
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
    } catch (_) {
      // সেটিংস খুলতে ব্যর্থ হলেও অ্যাপ ক্র্যাশ করবে না — UI থেকে
      // ইউজারকে ম্যানুয়ালি সেটিংসে যেতে বলা হবে।
    }
  }

  /// বর্তমানে স্ক্রিনে যা আছে (আশা করা হচ্ছে MT5) তার node tree ডাম্প
  /// করে ফাইলে সেভ করে, ফাইলের path রিটার্ন করে। ব্যর্থ হলে কারণসহ
  /// exception throw করে যাতে UI-তে নির্দিষ্ট বাংলা বার্তা দেখানো যায়।
  static Future<String> dumpNow() async {
    try {
      final path = await _channel.invokeMethod<String>('dumpNow');
      if (path == null) throw DumperException('Dump ব্যর্থ হয়েছে — অজানা কারণ।');
      return path;
    } on PlatformException catch (e) {
      if (e.code == 'SERVICE_NOT_RUNNING') {
        throw DumperException('Accessibility Service চালু নেই — আগে সেটিংস থেকে এনাবল করুন।');
      }
      if (e.code == 'DUMP_FAILED') {
        throw DumperException('কোনো active window পাওয়া যায়নি — MT5 অ্যাপ সামনে আছে কি না দেখুন।');
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
