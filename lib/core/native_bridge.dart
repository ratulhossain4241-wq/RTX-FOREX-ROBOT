import 'package:flutter/services.dart';

/// MethodChannel এর অতিরিক্ত সেফটি র‍্যাপার।
/// ভবিষ্যতে আরও নেটিভ ফিচার যোগ করলে এখানে এক জায়গায় রাখা যাবে।
class NativeBridge {
  static const MethodChannel channel =
      MethodChannel('com.rtxauto.rtx_auto_trader/accessibility');

  static Future<T?> invoke<T>(String method, [dynamic arguments]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('NativeBridge error [$method]: ${e.message}');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('NativeBridge unexpected error [$method]: $e');
      return null;
    }
  }
}
