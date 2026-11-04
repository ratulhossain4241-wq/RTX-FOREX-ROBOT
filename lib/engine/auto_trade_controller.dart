import '../core/mt5_executor.dart';
import '../core/models.dart';
import '../core/risk_engine.dart';
import '../core/store.dart';
import '../core/trade_logger.dart';
import 'signal_router.dart';

/// সিগন্যাল পাওয়ার পর অটোমেটিকভাবে ট্রেড এক্সিকিউট করার কন্ট্রোলার।
/// এটা overlay বা মেইন লজিক থেকে কল করা হয়।
///
/// কাজের ধাপ:
/// 1. অটো ট্রেড মোড চালু আছে কিনা চেক
/// 2. RiskEngine দিয়ে অনুমতি নেওয়া
/// 3. Mt5Executor দিয়ে আসলে ক্লিক করানো
class AutoTradeController {
  /// একটি RouterSignal নিয়ে অটো এক্সিকিউশনের চেষ্টা করে।
  static Future<AutoTradeResult> tryAutoExecute({
    required RouterSignal signal,
    required String market,
    required String signalId,
  }) async {
    // অটো মোড চালু আছে কিনা
    final autoOn = await Store.autoMode();
    if (!autoOn) {
      return const AutoTradeResult(
        executed: false,
        messageBn: 'অটো ট্রেড মোড বন্ধ আছে।',
      );
    }

    if (signal.noSignal || signal.strategy == null) {
      return const AutoTradeResult(
        executed: false,
        messageBn: 'কোনো বৈধ সিগন্যাল নেই।',
      );
    }

    final strat = signal.strategy!;
    final direction = strat.direction ?? '';
    if (direction != 'LONG' && direction != 'SHORT') {
      return const AutoTradeResult(
        executed: false,
        messageBn: 'দিক নির্দেশনা সঠিক নয়।',
      );
    }

    // রিস্ক গেট
    final openTrades = await TradeLogger.openTrades();
    final pipValue = 10.0; // পরে pip_utils থেকে সঠিক মান নেওয়া হবে
    final riskResult = await RiskEngine.canOpenNewTrade(
      currentOpenTradesCount: openTrades.length,
      slPips: signal.slPips ?? 0,
      pipValueUsd: pipValue,
    );

    if (riskResult.blocked) {
      return AutoTradeResult(
        executed: false,
        messageBn: riskResult.reasonBn ?? 'রিস্ক গেট ব্লক করেছে।',
      );
    }

    final lot = riskResult.approvedLotSize ?? 0.01;

    // আসলে এক্সিকিউট
    final exec = await Mt5Executor.executeSignal(
      direction: direction,
      entryPrice: strat.entry ?? 0,
      slPrice: strat.sl ?? 0,
      tp1Price: strat.tp1 ?? 0,
      lotSize: lot,
      market: market,
      signalId: signalId,
    );

    return AutoTradeResult(
      executed: exec.success,
      messageBn: exec.messageBn,
      lotSize: lot,
    );
  }
}

class AutoTradeResult {
  final bool executed;
  final String messageBn;
  final double? lotSize;

  const AutoTradeResult({
    required this.executed,
    required this.messageBn,
    this.lotSize,
  });
}
