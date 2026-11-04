import 'package:flutter/foundation.dart';
import 'models.dart';
import 'store.dart';
import 'mt5_executor.dart';
import 'execution_logger.dart';
import '../engine/signal_router.dart';
import '../engine/auto_trade_controller.dart';
import 'signal_id_utils.dart';

/// Overlay থেকে সহজে অটো ট্রেড কল করার জন্য হেল্পার।
/// এখানে সব চেক এক জায়গায় করা হয় যাতে UI কোড পরিষ্কার থাকে।
class AutoTradeHelper {
  /// সিগন্যাল পেলে অটো এক্সিকিউট করার চেষ্টা করে এবং লগ রাখে।
  static Future<String> tryExecuteFromOverlay({
    required RouterSignal signal,
    required String market,
  }) async {
    if (signal.noSignal || signal.strategy == null) {
      return 'কোনো বৈধ সিগন্যাল নেই';
    }

    final strat = signal.strategy!;
    final direction = strat.direction ?? '';
    final entry = strat.entry ?? 0.0;

    final signalId = SignalIdUtils.generate(
      market: market,
      direction: direction,
      entry: entry,
    );

    final result = await AutoTradeController.tryAutoExecute(
      signal: signal,
      market: market,
      signalId: signalId,
    );

    // লগ রাখা
    await ExecutionLogger.log(
      signalId: signalId,
      market: market,
      direction: direction,
      action: direction == 'LONG' ? 'BUY' : 'SELL',
      success: result.executed,
      message: result.messageBn,
      lotSize: result.lotSize,
    );

    return result.messageBn;
  }
}
