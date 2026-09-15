import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../core/constants.dart';
import '../core/store.dart';
import '../core/models.dart';
import 'risk_settings_page.dart';
import 'dumper_page.dart';

class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  bool _loading = true;
  bool _overlayPermission = false;
  String _statusMessage = '';

  final _tdController = TextEditingController();
  final _geminiController = TextEditingController();
  final _balanceController = TextEditingController();
  MarketDef _selectedMarket = kMarkets.first;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _tdController.dispose();
    _geminiController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    final td = await Store.twelveDataKey();
    final gemini = await Store.geminiKey();
    final marketTd = await Store.market();
    final risk = await Store.riskSettings();

    setState(() {
      _overlayPermission = granted;
      _tdController.text = td;
      _geminiController.text = gemini;
      _balanceController.text = risk.accountBalance > 0 ? risk.accountBalance.toString() : '';
      _selectedMarket = kMarkets.firstWhere((m) => m.td == marketTd, orElse: () => kMarkets.first);
      _loading = false;
    });
  }

  Future<void> _saveKeys() async {
    await Store.saveKeys(td: _tdController.text.trim(), gemini: _geminiController.text.trim());
    if (!mounted) return;
    setState(() => _statusMessage = 'API Key সংরক্ষিত হয়েছে ✅');
  }

  Future<void> _saveBalance() async {
    final balance = double.tryParse(_balanceController.text.trim());
    if (balance == null || balance <= 0) {
      setState(() => _statusMessage = '⚠️ সঠিক একটি Account Balance লিখুন');
      return;
    }
    final current = await Store.riskSettings();
    await Store.saveRiskSettings(RiskSettings(
      accountBalance: balance,
      riskPercent: current.riskPercent,
      maxDailyLosses: current.maxDailyLosses,
      maxConcurrentTrades: current.maxConcurrentTrades,
    ));
    if (!mounted) return;
    setState(() => _statusMessage = 'Balance সংরক্ষিত হয়েছে ✅');
  }

  Future<void> _pickMarket() async {
    final picked = await showModalBottomSheet<MarketDef>(
      context: context,
      backgroundColor: T.card,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: 420,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('MARKET বাছাই করুন',
                  style: TextStyle(color: T.green, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: kMarkets.length,
                itemBuilder: (_, i) {
                  final m = kMarkets[i];
                  return ListTile(
                    title: Text(m.name, style: const TextStyle(color: T.green)),
                    subtitle: Text(m.cat, style: const TextStyle(color: T.dim, fontSize: 11)),
                    onTap: () => Navigator.pop(ctx, m),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await Store.saveMarket(picked.td);
      setState(() {
        _selectedMarket = picked;
        _statusMessage = 'Market সেট হয়েছে: ${picked.name} — বাবল খোলা থাকলে ২ সেকেন্ডের মধ্যে আপডেট হবে';
      });
    }
  }

  Future<void> _startBot() async {
    if (_tdController.text.trim().isEmpty) {
      setState(() => _statusMessage = '⚠️ আগে Twelve Data API Key দিয়ে সেভ করুন');
      return;
    }
    final risk = await Store.riskSettings();
    if (risk.accountBalance <= 0) {
      setState(() => _statusMessage = '⚠️ আগে Account Balance সেভ করুন');
      return;
    }

    await _saveKeys();

    if (!_overlayPermission) {
      await FlutterOverlayWindow.requestPermission();
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      setState(() => _overlayPermission = granted);
      if (!granted) {
        setState(() => _statusMessage = '⚠️ Overlay permission দিতে হবে');
        return;
      }
    }

    final active = await FlutterOverlayWindow.isActive();
    if (!active) {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        height: 640,
        width: 380,
        alignment: OverlayAlignment.center,
        flag: OverlayFlag.defaultFlag,
        overlayTitle: 'RTX Auto Trader',
        overlayContent: 'Signal running',
      );
    }
    setState(() => _statusMessage = 'বাবল চালু হয়েছে ✅');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: T.bg,
        body: Center(child: CircularProgressIndicator(color: T.green)),
      );
    }

    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(
                child: Text('🤖 RTX AUTO TRADER',
                    style: TextStyle(
                        color: T.green, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text('SETUP — API KEY, MARKET, RISK',
                    style: TextStyle(color: T.dim, fontSize: 10, letterSpacing: 1)),
              ),
              const SizedBox(height: 20),
              Text(
                _overlayPermission ? 'OVERLAY PERMISSION: ON' : 'OVERLAY PERMISSION: OFF',
                style: TextStyle(
                    color: _overlayPermission ? T.green : T.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              const _SectionTitle('API KEYS'),
              _textField(_tdController, 'Twelve Data API Key (আবশ্যক)'),
              const SizedBox(height: 10),
              _textField(_geminiController, 'Gemini API Key (ঐচ্ছিক, AI বিশ্লেষণের জন্য)'),
              const SizedBox(height: 10),
              _outlineButton('SAVE KEYS', _saveKeys),

              const SizedBox(height: 24),
              const _SectionTitle('MARKET'),
              InkWell(
                onTap: _pickMarket,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: T.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: T.muted),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_selectedMarket.name,
                          style: const TextStyle(color: T.green, fontWeight: FontWeight.bold)),
                      const Text('▼ পরিবর্তন করুন', style: TextStyle(color: T.dim, fontSize: 11)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const _SectionTitle('RISK — ACCOUNT BALANCE (USD)'),
              _textField(_balanceController, 'যেমন: 500', keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              _outlineButton('SAVE BALANCE', _saveBalance),
              const SizedBox(height: 10),
              _outlineButton('⚙️ RISK SETTINGS (Risk %, Daily Loss, ইত্যাদি)', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RiskSettingsPage()));
              }),

              const SizedBox(height: 24),
              const _SectionTitle('TOOLS'),
              _outlineButton('📸 MT5 SCREEN SCANNER', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DumperPage()));
              }),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: T.green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _startBot,
                  child: Text(
                    _overlayPermission ? 'START FLOATING BUBBLE' : 'GRANT + START',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_statusMessage.isNotEmpty)
                Center(
                  child: Text(_statusMessage,
                      textAlign: TextAlign.center, style: const TextStyle(color: T.gold, fontSize: 12)),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController c, String hint, {TextInputType? keyboardType}) {
    return TextField(
      controller: c,
      keyboardType: keyboardType,
      style: const TextStyle(color: T.green, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: T.dim, fontSize: 12),
        filled: true,
        fillColor: T.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: T.muted),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _outlineButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: T.green),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: onTap,
      child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: T.green, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: T.gold, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
