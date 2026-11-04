import 'package:flutter/services.dart';
import 'constants.dart';
import 'store.dart';

/// Flutter সাইড থেকে Android Accessibility Service কে কন্ট্রোল করার জন্য
/// এই ক্লাস ব্যবহার করা হয়। MethodChannel দিয়ে নেটিভ সাইডের সাথে কথা বলে।
///
/// গুরুত্বপূর্ণ:
/// - সার্ভিস চালু আছে কিনা চেক করে
/// - ইউজারকে Settings এ নিয়ে যেতে পারে
/// - MT5 স্ক্যান রেজাল্ট ও ক্লিক কমান্ড পাঠাতে পারে
class AccessibilityService {
  static const MethodChannel _channel =
      MethodChannel('com.rtxauto.rtx_auto_trader/accessibility');

  /// Accessibility Service বর্তমানে চালু আছে কিনা চেক করে।
  static Future<bool> isEnabled() async {
    try {
      final bool enabled = await _channel.invokeMethod('isAccessibilityEnabled');
      await Store.setAccessibilityEnabled(enabled);
      return enabled;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// ইউজারকে Android Accessibility Settings পেজে নিয়ে যায়।
  /// সেখান থেকে "RTX Auto Trader" সার্ভিসটা ম্যানুয়ালি চালু করতে হয়।
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('Accessibility settings open failed: ${e.message}');
    }
  }

  /// MT5 অ্যাপটি বর্তমানে ফোরগ্রাউন্ডে আছে কিনা চেক করে।
  static Future<bool> isMt5InForeground() async {
    try {
      final bool result = await _channel.invokeMethod('isMt5InForeground');
      return result;
    } catch (_) {
      return false;
    }
  }

  /// নেটিভ সাইডকে বলে একটি নির্দিষ্ট অ্যাকশন করার জন্য।
  /// actionType: 'BUY' | 'SELL' | 'CLOSE_ALL' | 'CLOSE_PROFIT' | 'CHANGE_SYMBOL'
  /// extraData: প্রয়োজন হলে সিম্বল নাম বা অন্য তথ্য
  static Future<Map<String, dynamic>> performAction({
    required String actionType,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final result = await _channel.invokeMethod('performAction', {
        'action': actionType,
        'data': extraData ?? {},
      });
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {'success': false, 'message': 'Invalid response from native'};
    } on PlatformException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Platform exception',
        'code': e.code,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// নেটিভ সাইড থেকে লাইভ স্ক্যান রেজাল্ট আনে (বর্তমান সিম্বল, বিড/আস্ক ইত্যাদি)।
  static Future<Map<String, dynamic>?> getCurrentMt5State() async {
    try {
      final result = await _channel.invokeMethod('getCurrentMt5State');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
