import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/store.dart';
import '../core/models.dart';

/// Risk Settings — আগে এটা বাবলের ভেতরে bottom-sheet হিসেবে ছিল, কিন্তু
/// Android-এর overlay window সিস্টেম কীবোর্ড দেখাতে পারে না (overlay
/// window ফোকাস নিতে পারে না বলে)। তাই এটা এখন মেইন অ্যাপের একটা সাধারণ
/// পূর্ণ-স্ক্রিন পেজ, যেখানে টাইপ করা স্বাভাবিকভাবেই কাজ করবে।
class RiskSettingsPage extends StatefulWidget {
  const RiskSettingsPage({super.key});

  @override
  State<RiskSettingsPage> createState() => _RiskSettingsPageState();
}

class _RiskSettingsPageState extends State<RiskSettingsPage> {
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
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.card,
        title: const Text('Risk Settings', style: TextStyle(color: T.green, fontSize: 15)),
        iconTheme: const IconThemeData(color: T.green),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: T.green))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'সর্বোচ্চ সীমা: Risk ${(RiskDefaults.maxRiskPercent * 100).toStringAsFixed(0)}%, '
                      'Daily Loss ${RiskDefaults.maxAllowedDailyLosses}, '
                      'Concurrent ${RiskDefaults.maxAllowedConcurrentTrades}',
                      style: const TextStyle(color: T.dim, fontSize: 11),
                    ),
                    const SizedBox(height: 20),
                    _field(_riskController, 'Risk per Trade (%)', TextInputType.number),
                    const SizedBox(height: 12),
                    _field(_dailyLossController, 'Max Daily Losses', TextInputType.number),
                    const SizedBox(height: 12),
                    _field(_concurrentController, 'Max Concurrent Trades', TextInputType.number),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(backgroundColor: T.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('SAVE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: T.gold, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field(TextEditingController c, String label, TextInputType type) {
    return TextField(
      controller: c,
      keyboardType: type,
      style: const TextStyle(color: T.green, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: T.dim, fontSize: 12),
        filled: true,
        fillColor: T.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: T.muted)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
