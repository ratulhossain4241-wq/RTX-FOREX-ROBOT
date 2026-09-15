import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/store.dart';
import '../core/models.dart';

/// Risk %, Max Daily Loss, Max Concurrent Trades এডিট করার শিট।
/// সব ইনপুট RiskEngine-এর hard cap দিয়ে clamp হয়ে সেভ হয় — ভুল করে
/// অতিরিক্ত ঝুঁকিপূর্ণ মান বসানো যাবে না।
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final _riskController = TextEditingController();
  final _dailyLossController = TextEditingController();
  final _concurrentController = TextEditingController();
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _riskController.dispose();
    _dailyLossController.dispose();
    _concurrentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await Store.riskSettings();
    setState(() {
      _riskController.text = (s.riskPercent * 100).toStringAsFixed(1);
      _dailyLossController.text = s.maxDailyLosses.toString();
      _concurrentController.text = s.maxConcurrentTrades.toString();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final riskPct = (double.tryParse(_riskController.text.trim()) ?? 1.0) / 100;
    final dailyLoss = int.tryParse(_dailyLossController.text.trim()) ?? RiskDefaults.defaultMaxDailyLosses;
    final concurrent = int.tryParse(_concurrentController.text.trim()) ?? RiskDefaults.defaultMaxConcurrentTrades;

    final clampedRisk = riskPct.clamp(0.001, RiskDefaults.maxRiskPercent);
    final clampedDailyLoss = dailyLoss.clamp(1, RiskDefaults.maxAllowedDailyLosses);
    final clampedConcurrent = concurrent.clamp(1, RiskDefaults.maxAllowedConcurrentTrades);

    final current = await Store.riskSettings();
    await Store.saveRiskSettings(RiskSettings(
      accountBalance: current.accountBalance,
      riskPercent: clampedRisk.toDouble(),
      maxDailyLosses: clampedDailyLoss.toInt(),
      maxConcurrentTrades: clampedConcurrent.toInt(),
    ));

    if (!mounted) return;
    setState(() {
      _riskController.text = (clampedRisk * 100).toStringAsFixed(1);
      _dailyLossController.text = clampedDailyLoss.toString();
      _concurrentController.text = clampedConcurrent.toString();
      _message = 'সেভ হয়েছে ✅ (নিরাপত্তার জন্য সর্বোচ্চ সীমার মধ্যে রাখা হয়েছে)';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: T.green)));
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('⚙️ RISK SETTINGS',
              style: TextStyle(color: T.gold, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text('সর্বোচ্চ সীমা: Risk ${(RiskDefaults.maxRiskPercent * 100).toStringAsFixed(0)}%, '
              'Daily Loss ${RiskDefaults.maxAllowedDailyLosses}, '
              'Concurrent ${RiskDefaults.maxAllowedConcurrentTrades}',
              style: const TextStyle(color: T.dim, fontSize: 10)),
          const SizedBox(height: 16),
          _field(_riskController, 'Risk per Trade (%)', TextInputType.number),
          const SizedBox(height: 10),
          _field(_dailyLossController, 'Max Daily Losses', TextInputType.number),
          const SizedBox(height: 10),
          _field(_concurrentController, 'Max Concurrent Trades', TextInputType.number),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(backgroundColor: T.green, padding: const EdgeInsets.symmetric(vertical: 12)),
            child: const Text('SAVE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: T.gold, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, TextInputType type) {
    return TextField(
      controller: c,
      keyboardType: type,
      style: const TextStyle(color: T.green, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: T.dim, fontSize: 12),
        filled: true,
        fillColor: T.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: T.muted)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
