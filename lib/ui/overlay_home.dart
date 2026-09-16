import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../core/store.dart';
import '../core/models.dart';
import '../core/api_client.dart';
import '../core/pip_utils.dart';
import '../core/market_hours.dart';
import '../core/mode_meta.dart';
import '../core/risk_engine.dart';
import '../core/trade_logger.dart';
import '../engine/signal_router.dart';
import '../engine/signal_enricher.dart';
import 'chart_painter.dart';

class OverlayHome extends StatefulWidget {
  const OverlayHome({super.key});

  @override
  State<OverlayHome> createState() => _OverlayHomeState();
}

class _OverlayHomeState extends State<OverlayHome> {
  String _time = '--:--:--';
  Timer? _clockTimer;
  Timer? _marketPollTimer;
  bool _scanning = false;
  bool _aiThinking = false;
  bool _autoMode = false;

  MarketDef _market = kMarkets.first;
  List<Candle> _chartCandles = [];
  RouterSignal? _lastSignal;
  EnrichedSignal? _enriched;
  ModeMeta? _lastSignalMode;
  String? _statusMessageBn;
  String? _riskBlockedReasonBn;
  double? _approvedLotSize;
  int _todayWon = 0, _todayLost = 0;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _time = DateFormat('HH:mm:ss').format(DateTime.now()));
    });

    // ✅ ফিক্স: বাবল আর মেইন অ্যাপ দুইটা আলাদা Flutter engine-এ চলে,
    // তাই মেইন অ্যাপে মার্কেট বদলালে বাবল সেটা স্বয়ংক্রিয়ভাবে জানতে
    // পারে না। প্রতি ২ সেকেন্ডে SharedPreferences থেকে টাটকা মার্কেট
    // চেক করে এই সমস্যা সমাধান করা হলো।
    _marketPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollMarket());

    _loadInitial();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _marketPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollMarket() async {
    final marketTd = await Store.market();
    if (!mounted) return;
    if (marketTd != _market.td) {
      final next = kMarkets.firstWhere((m) => m.td == marketTd, orElse: () => kMarkets.first);
      setState(() {
        _market = next;
        // মার্কেট বদলালে পুরনো সিগন্যাল/চার্ট আর প্রাসঙ্গিক না, তাই রিসেট করা হচ্ছে
        _lastSignal = null;
        _enriched = null;
        _chartCandles = [];
        _statusMessageBn = null;
      });
    }
  }

  Future<void> _loadInitial() async {
    final marketTd = await Store.market();
    final auto = await Store.autoMode();
    final wl = await TradeLogger.todaysWinLossCount();
    if (!mounted) return;
    setState(() {
      _market = kMarkets.firstWhere((m) => m.td == marketTd, orElse: () => kMarkets.first);
      _autoMode = auto;
      _todayWon = wl['won'] ?? 0;
      _todayLost = wl['lost'] ?? 0;
    });
  }

  Future<void> _toggleAuto() async {
    final next = !_autoMode;
    await Store.setAutoMode(next);
    if (!mounted) return;
    setState(() => _autoMode = next);
  }

  /// ✅ ফিক্স: আগে এখানে showModalBottomSheet(SettingsSheet) খোলা হতো,
  /// কিন্তু overlay window-এ সিস্টেম কীবোর্ড আসে না বলে টাইপ করা যেত
  /// না। তাই এখন Risk Settings মেইন অ্যাপে সরানো হয়েছে — এখানে শুধু
  /// একটা নির্দেশনা দেখানো হয়।
  void _showSettingsHint() {
    setState(() {
      _statusMessageBn =
          'Risk Settings পরিবর্তন করতে মূল RTX Auto Trader অ্যাপ (হোম স্ক্রিন থেকে) খুলে সেখান থেকে Risk Settings-এ যান।';
    });
  }

  Future<void> _generate() async {
    if (!isForexMarketOpen()) {
      setState(() {
        _statusMessageBn = '🔴 Market Closed — খুলবে ${nextOpenDayLabel()}';
        _lastSignal = null;
        _enriched = null;
      });
      return;
    }

    final tdKey = await Store.twelveDataKey();
    if (tdKey.isEmpty) {
      setState(() => _statusMessageBn = '⚠️ Twelve Data API Key নেই — মূল অ্যাপে সেভ করুন।');
      return;
    }

    setState(() {
      _scanning = true;
      _statusMessageBn = null;
      _lastSignal = null;
      _enriched = null;
      _riskBlockedReasonBn = null;
    });

    final fetch = await ApiClient.fetchAllTimeframes(apiKey: tdKey, symbol: _market.td);
    if (!mounted) return;

    if (fetch.timeframes['15m'] == null) {
      setState(() {
        _scanning = false;
        _statusMessageBn = fetch.errors['15m'] ?? '15m ডেটা আনতে ব্যর্থ।';
      });
      return;
    }

    setState(() => _chartCandles = fetch.timeframes['15m']!);

    RouterSignal? best;
    ModeMeta? bestMode;

    for (final mode in kSignalModes) {
      final result = generateRouterSignal(
        modeId: mode.id,
        timeframes: fetch.timeframes,
        marketTd: _market.td,
        marketCategory: _market.cat,
      );
      if (!result.noSignal) {
        if (best == null || (result.rr ?? 0) > (best.rr ?? 0)) {
          best = result;
          bestMode = mode;
        }
      }
    }

    if (best == null) {
      setState(() {
        _scanning = false;
        _statusMessageBn = 'কোনো মোডেই এই মুহূর্তে শক্তিশালী সিগন্যাল নেই।';
      });
      return;
    }

    setState(() {
      _scanning = false;
      _aiThinking = true;
      _lastSignal = best;
      _lastSignalMode = bestMode;
    });

    final geminiKey = await Store.geminiKey();
    final enriched = await enrichSignal(
      router: best,
      candles15m: fetch.timeframes['15m']!,
      geminiApiKey: geminiKey,
      marketName: _market.name,
    );
    if (!mounted) return;

    final strat = best.strategy!;
    final pipValue = pipValuePerStandardLot(_market.td, strat.entry!) ?? 0;
    final openTrades = await TradeLogger.openTrades();
    final riskResult = await RiskEngine.canOpenNewTrade(
      currentOpenTradesCount: openTrades.length,
      slPips: best.slPips!,
      pipValueUsd: pipValue,
    );

    if (!mounted) return;
    setState(() {
      _aiThinking = false;
      _enriched = enriched;
      _riskBlockedReasonBn = riskResult.blocked ? riskResult.reasonBn : null;
      _approvedLotSize = riskResult.approvedLotSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strat = _lastSignal?.strategy;
    final borderColor = strat == null ? T.green : (strat.direction == 'LONG' ? T.green : T.red);

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xF20A0A0A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  children: [
                    _chart(),
                    const SizedBox(height: 10),
                    _signalBox(),
                    const SizedBox(height: 8),
                    _statsRow(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _actionRow(),
          ],
        ),
      ),
    );
  }

  /// ✅ ফিক্স: আগে একটাই Row-তে নাম + মার্কেট bge + settings আইকন +
  /// সময় গাদাগাদি করে বসানো ছিল, ফলে সরু বাবল উইন্ডোতে Flexible/Spacer
  /// এর flex হিসাব ঘেঁটে গিয়ে মার্কেট নাম কখনো প্রায় শূন্য জায়গা পেয়ে
  /// দেখাই যাচ্ছিল না। এখন দুই সারিতে ভাগ করা হলো — নিচের সারিতে
  /// Expanded দিয়ে মার্কেট bge পুরো প্রস্থ নিশ্চিত পায়, তাই আর কখনো
  /// চেপে গিয়ে অদৃশ্য হবে না।
  Widget _header() {
    return Column(
      children: [
        Row(
          children: [
            const Text('RTX AUTO', style: TextStyle(color: T.green, fontSize: 12, fontWeight: FontWeight.w900)),
            const Spacer(),
            Text(_time, style: const TextStyle(color: T.dim, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: T.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: T.gold.withOpacity(0.6)),
                ),
                child: Text(_market.name,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: T.gold, fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showSettingsHint,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: T.card, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.settings, color: T.dim, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chart() {
    if (_chartCandles.isEmpty) {
      return Container(
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: T.muted)),
        child: const Text('NO CHART YET', style: TextStyle(color: T.dim, fontSize: 11)),
      );
    }
    final list = _chartCandles.length > 20 ? _chartCandles.sublist(_chartCandles.length - 20) : _chartCandles;

    final strat = _lastSignal?.strategy;
    final levels = <String, double>{};
    final levelColors = <String, Color>{};
    if (strat != null) {
      levels['Entry'] = strat.entry!;
      levels['SL'] = strat.sl!;
      levels['TP1'] = strat.tp1!;
      levelColors['Entry'] = T.cyan;
      levelColors['SL'] = T.red;
      levelColors['TP1'] = T.green;
    }

    return Container(
      height: 100,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: T.muted)),
      child: CustomPaint(size: Size.infinite, painter: CandleChartPainter(candles: list, levelLines: levels, levelColors: levelColors)),
    );
  }

  Widget _statsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: T.card, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('আজ: $_todayWon W / $_todayLost L', style: const TextStyle(color: T.dim, fontSize: 11)),
          Row(
            children: [
              const Text('AUTO', style: TextStyle(color: T.dim, fontSize: 11)),
              Switch(value: _autoMode, onChanged: (_) => _toggleAuto(), activeColor: T.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _signalBox() {
    if (_scanning) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Text('SCANNING (৪টি মোড যাচাই হচ্ছে)...',
            textAlign: TextAlign.center, style: TextStyle(color: T.green, fontWeight: FontWeight.bold, fontSize: 13)),
      );
    }
    if (_aiThinking) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Text('Gemini AI যাচাই করছে...',
            textAlign: TextAlign.center, style: TextStyle(color: T.cyan, fontWeight: FontWeight.bold, fontSize: 13)),
      );
    }
    if (_statusMessageBn != null) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text(_statusMessageBn!, textAlign: TextAlign.center, style: const TextStyle(color: T.gold, fontSize: 12)),
      );
    }

    final signal = _lastSignal;
    final strat = signal?.strategy;
    final enriched = _enriched;
    if (signal == null || strat == null) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Text('[ READY ] Tap SIGNAL',
            textAlign: TextAlign.center, style: TextStyle(color: T.dim, fontWeight: FontWeight.bold, fontSize: 12)),
      );
    }

    final directionColor = strat.direction == 'LONG' ? T.green : T.red;
    final agrees = enriched?.directionsAgree ?? true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: directionColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(_lastSignalMode?.name ?? '', style: TextStyle(color: _lastSignalMode?.color ?? T.gold, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(strat.direction ?? '-', style: TextStyle(color: directionColor, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Strength: ${strat.strength}', style: const TextStyle(color: T.dim, fontSize: 11)),
          const Text('📊 এন্ট্রি টাইমফ্রেম: 15m (1h/4h = ট্রেন্ড কনফার্মেশন)',
              style: TextStyle(color: T.cyan, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (enriched != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (agrees ? T.green : T.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (agrees ? T.green : T.red).withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  Text(
                    agrees ? '✅ AI ও ইঞ্জিন একমত' : '⚠️ AI ও স্ট্র্যাটেজি ভিন্নমত — সতর্ক থাকুন',
                    style: TextStyle(color: agrees ? T.green : T.red, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text('Grade ${enriched.finalVerdict.grade} · Accuracy ${enriched.finalVerdict.accuracy}%',
                      style: const TextStyle(color: T.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(enriched.finalVerdict.reason,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: T.dim, fontSize: 10)),
                ],
              ),
            ),
          ],
          const Divider(color: T.muted, height: 18),
          _priceRow('Entry', strat.entry!),
          _priceRow('SL', strat.sl!, color: T.red),
          _priceRow('TP1', strat.tp1!, color: T.green),
          _priceRow('TP2', strat.tp2!, color: T.green),
          _priceRow('TP3', strat.tp3!, color: T.green),
          const SizedBox(height: 6),
          Text('R:R  1:${signal.rr!.toStringAsFixed(2)}', style: const TextStyle(color: T.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
          if (_approvedLotSize != null) ...[
            const SizedBox(height: 4),
            Text('অনুমোদিত Lot Size: $_approvedLotSize', style: const TextStyle(color: T.gold, fontSize: 11)),
          ],
          if (_riskBlockedReasonBn != null) ...[
            const SizedBox(height: 8),
            Text('🚫 $_riskBlockedReasonBn', textAlign: TextAlign.center, style: const TextStyle(color: T.red, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(String label, double value, {Color color = T.dim}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: T.dim, fontSize: 11)),
          Text(formatPrice(value, _market.td), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _actionRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: (_scanning || _aiThinking) ? null : _generate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(color: T.green.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: T.green)),
              child: Center(
                child: Text(
                  _scanning ? 'SCAN...' : (_aiThinking ? 'AI...' : '🚀 SIGNAL'),
                  style: const TextStyle(color: T.green, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => FlutterOverlayWindow.closeOverlay(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(color: T.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: T.muted)),
            child: const Text('✕', style: TextStyle(fontSize: 16, color: T.red)),
          ),
        ),
      ],
    );
  }
}
