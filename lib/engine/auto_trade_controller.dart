import '../core/mt5_executor.dart';
import '../core/models.dart';
import '../core/risk_engine.dart';
import '../core/store.dart';
import '../core/trade_logger.dart';
import '../core/pip_utils.dart';
import 'signal_router.dart';

class AutoTradeController {
  static Future<AutoTradeResult> tryAutoExecute({
    required RouterSignal signal,
    required String market,
    required String signalId,
  }) async {
    final autoOn = await Store.autoMode();
    final autoTradeOn = await Store.autoTradeEnabled();

    if (!autoOn || !autoTradeOn) {
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

    final openTrades = await TradeLogger.openTrades();
    final entry = strat.entry ?? 0.0;
    final pipValue = pipValuePerStandardLot(market, entry) ?? 10.0;

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

    final exec = await Mt5Executor.executeSignal(
      direction: direction,
      entryPrice: entry,
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
