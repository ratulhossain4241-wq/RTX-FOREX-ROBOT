import 'accessibility_service.dart';
import 'constants.dart';
import 'models.dart';
import 'risk_engine.dart';
import 'store.dart';
import 'trade_logger.dart';

/// MT5 অ্যাপে আসলে ট্রেড এক্সিকিউট করার দায়িত্ব এই ক্লাসের।
/// Accessibility Service এর মাধ্যমে Buy/Sell/Close ক্লিক করায়।
///
/// নিরাপত্তা:
/// - RiskEngine দিয়ে আগে চেক করে
/// - Cooldown থাকে যাতে বারবার ক্লিক না হয়
/// - শুধু MT5 প্যাকেজে কাজ করে
class Mt5Executor {
  static DateTime? _lastExecutionTime;

  /// একটি সিগন্যাল অনুযায়ী ট্রেড খোলার চেষ্টা করে।
  /// সফল হলে true রিটার্ন করে এবং TradeLogger এ রেকর্ড করে।
  static Future<ExecutionResult> executeSignal({
    required String direction, // 'LONG' বা 'SHORT'
    required double entryPrice,
    required double slPrice,
    required double tp1Price,
    required double lotSize,
    required String market,
    required String signalId,
  }) async {
    // ১. Accessibility চালু আছে কিনা
    final isAccEnabled = await AccessibilityService.isEnabled();
    if (!isAccEnabled) {
      return ExecutionResult(
        success: false,
        messageBn: 'Accessibility Service চালু নেই। সেটিংস থেকে চালু করুন।',
      );
    }

    // ২. MT5 ফোরগ্রাউন্ডে আছে কিনা
    final isMt5Open = await AccessibilityService.isMt5InForeground();
    if (!isMt5Open) {
      return ExecutionResult(
        success: false,
        messageBn: 'MetaTrader 5 অ্যাপটি খোলা নেই বা ফোরগ্রাউন্ডে নেই।',
      );
    }

    // ৩. Cooldown চেক
    final cooldown = await Store.executionCooldownSeconds();
    if (_lastExecutionTime != null) {
      final diff = DateTime.now().difference(_lastExecutionTime!).inSeconds;
      if (diff < cooldown) {
        return ExecutionResult(
          success: false,
          messageBn: 'অপেক্ষা করুন — পরবর্তী ট্রেড ${cooldown - diff} সেকেন্ড পরে সম্ভব।',
        );
      }
    }

    // ৪. একই সিগন্যাল আগে এক্সিকিউট হয়েছে কিনা
    final lastId = await Store.lastExecutedSignalId();
    if (lastId == signalId) {
      return ExecutionResult(
        success: false,
        messageBn: 'এই সিগন্যাল ইতিমধ্যে এক্সিকিউট করা হয়েছে।',
      );
    }

    // ৫. অ্যাকশন টাইপ নির্ধারণ
    final action = direction.toUpperCase() == 'LONG' ? 'BUY' : 'SELL';

    // ৬. নেটিভ সাইডে কমান্ড পাঠানো
    final result = await AccessibilityService.performAction(
      actionType: action,
      extraData: {
        'symbol': market,
        'lot': lotSize,
        'sl': slPrice,
        'tp': tp1Price,
        'entry': entryPrice,
      },
    );

    final success = result['success'] == true;

    if (success) {
      _lastExecutionTime = DateTime.now();
      await Store.setLastExecutedSignalId(signalId);

      // ট্রেড লগ করা
      final trade = TradeRecord(
        market: market,
        direction: direction == 'LONG' ? 'CALL' : 'PUT',
        entryPrice: entryPrice,
        lotSize: lotSize,
        openedAt: DateTime.now(),
        status: 'open',
      );
      await TradeLogger.insertOpenTrade(trade);
    }

    return ExecutionResult(
      success: success,
      messageBn: success
          ? 'ট্রেড সফলভাবে পাঠানো হয়েছে ($action)'
          : (result['message']?.toString() ?? 'এক্সিকিউশন ব্যর্থ হয়েছে'),
      rawResult: result,
    );
  }

  /// সব ওপেন পজিশন ক্লোজ করার চেষ্টা করে।
  static Future<ExecutionResult> closeAllPositions() async {
    final isAccEnabled = await AccessibilityService.isEnabled();
    if (!isAccEnabled) {
      return ExecutionResult(
        success: false,
        messageBn: 'Accessibility Service চালু নেই।',
      );
    }

    final result = await AccessibilityService.performAction(
      actionType: 'CLOSE_ALL',
    );

    return ExecutionResult(
      success: result['success'] == true,
      messageBn: result['success'] == true
          ? 'সব পজিশন ক্লোজ করার কমান্ড পাঠানো হয়েছে'
          : (result['message']?.toString() ?? 'ক্লোজ ব্যর্থ'),
      rawResult: result,
    );
  }
}

/// এক্সিকিউশনের ফলাফল
class ExecutionResult {
  final bool success;
  final String messageBn;
  final Map<String, dynamic>? rawResult;

  const ExecutionResult({
    required this.success,
    required this.messageBn,
    this.rawResult,
  });
}
