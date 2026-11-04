import 'accessibility_service.dart';
import 'constants.dart';
import 'models.dart';
import 'risk_engine.dart';
import 'store.dart';
import 'trade_logger.dart';
import 'execution_logger.dart';

class Mt5Executor {
  static DateTime? _lastExecutionTime;

  static Future<ExecutionResult> executeSignal({
    required String direction,
    required double entryPrice,
    required double slPrice,
    required double tp1Price,
    required double lotSize,
    required String market,
    required String signalId,
  }) async {
    final isAccEnabled = await AccessibilityService.isEnabled();
    if (!isAccEnabled) {
      return ExecutionResult(
        success: false,
        messageBn: 'Accessibility Service চালু নেই। সেটিংস থেকে চালু করুন।',
      );
    }

    final isMt5Open = await AccessibilityService.isMt5InForeground();
    if (!isMt5Open) {
      return ExecutionResult(
        success: false,
        messageBn: 'MetaTrader 5 অ্যাপটি খোলা নেই বা ফোরগ্রাউন্ডে নেই।',
      );
    }

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

    final lastId = await Store.lastExecutedSignalId();
    if (lastId == signalId) {
      return ExecutionResult(
        success: false,
        messageBn: 'এই সিগন্যাল ইতিমধ্যে এক্সিকিউট করা হয়েছে।',
      );
    }

    final action = direction.toUpperCase() == 'LONG' ? 'BUY' : 'SELL';

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

    await ExecutionLogger.log(
      signalId: signalId,
      market: market,
      direction: direction,
      action: action,
      success: success,
      message: result['message']?.toString() ?? '',
      lotSize: lotSize,
    );

    return ExecutionResult(
      success: success,
      messageBn: success
          ? 'ট্রেড সফলভাবে পাঠানো হয়েছে ($action) — Lot: $lotSize'
          : (result['message']?.toString() ?? 'এক্সিকিউশন ব্যর্থ হয়েছে'),
      rawResult: result,
    );
  }

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
