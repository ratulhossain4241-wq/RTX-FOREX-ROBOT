import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants.dart';
import '../executor/dumper_bridge.dart';
import 'dump_viewer_page.dart';

const int _scanDelaySeconds = 5;

class DumperPage extends StatefulWidget {
  const DumperPage({super.key});

  @override
  State<DumperPage> createState() => _DumperPageState();
}

class _DumperPageState extends State<DumperPage> with WidgetsBindingObserver {
  bool _serviceEnabled = false;
  bool _scanning = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  String? _message;
  List<String> _dumps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final enabled = await DumperBridge.isAccessibilityServiceEnabled();
    final dumps = await DumperBridge.listDumps();
    if (!mounted) return;
    setState(() {
      _serviceEnabled = enabled;
      _dumps = dumps;
    });
  }

  /// ✅ ফিক্স: এখন স্ক্যান দুই ধাপে হয় — প্রথমে একটা কাউন্টডাউন দেখানো
  /// হয় (এই সময়ে ইউজার MT5-এ সুইচ করবে), তারপর নেটিভ কোড দেরিতে dump
  /// করে। কাউন্টডাউন শেষ হওয়ার আগেই ইউজার এই স্ক্রিন ছেড়ে চলে যাবে —
  /// এটাই উদ্দেশ্য, তাই UI countdown শুধু প্রথম কয়েক মুহূর্ত দেখা যাবে।
  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _message = null;
      _countdown = _scanDelaySeconds;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown = (_countdown - 1).clamp(0, _scanDelaySeconds));
      if (_countdown <= 0) timer.cancel();
    });

    try {
      final path = await DumperBridge.dumpNow(delaySeconds: _scanDelaySeconds);
      if (!mounted) return;
      setState(() => _message = '✅ স্ক্যান সফল! ফাইল সেভ হয়েছে: ${path.split('/').last}');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = '⚠️ $e');
    } finally {
      _countdownTimer?.cancel();
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _shareDump(String fileName) async {
    final content = await DumperBridge.readDump(fileName);
    if (content.isEmpty) return;
    await Share.share(content, subject: fileName);
  }

  Future<void> _deleteDump(String fileName) async {
    await DumperBridge.deleteDump(fileName);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.card,
        title: const Text('MT5 Screen Scanner', style: TextStyle(color: T.green, fontSize: 15)),
        iconTheme: const IconThemeData(color: T.green),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statusCard(),
              const SizedBox(height: 16),
              _instructionsCard(),
              const SizedBox(height: 16),
              if (_scanning) _countdownCard(),
              if (!_scanning)
                ElevatedButton(
                  onPressed: _serviceEnabled ? _scan : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: T.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    '📸 SCAN NOW (৫ সেকেন্ড পর স্ক্যান হবে)',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              if (_message != null) ...[
                const SizedBox(height: 10),
                Text(_message!, style: const TextStyle(color: T.gold, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              const Text('সেভ করা স্ক্যান তালিকা',
                  style: TextStyle(color: T.dim, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: _dumps.isEmpty
                    ? const Center(
                        child: Text('এখনো কোনো স্ক্যান নেই।', style: TextStyle(color: T.muted, fontSize: 12)))
                    : ListView.builder(
                        itemCount: _dumps.length,
                        itemBuilder: (_, i) {
                          final fileName = _dumps[i];
                          return Card(
                            color: T.card,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(fileName, style: const TextStyle(color: T.green, fontSize: 12)),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => DumpViewerPage(fileName: fileName)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.share, color: T.cyan, size: 20),
                                    onPressed: () => _shareDump(fileName),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: T.red, size: 20),
                                    onPressed: () => _deleteDump(fileName),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countdownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: T.gold),
      ),
      child: Column(
        children: [
          Text(
            _countdown > 0 ? '$_countdown' : '⏳ স্ক্যান হচ্ছে...',
            style: const TextStyle(color: T.gold, fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'এখনই MT5 অ্যাপে সুইচ করো এবং যে স্ক্রিন স্ক্যান করতে চাও সেখানে যাও!',
            textAlign: TextAlign.center,
            style: TextStyle(color: T.dim, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _serviceEnabled ? T.green : T.red),
      ),
      child: Row(
        children: [
          Icon(_serviceEnabled ? Icons.check_circle : Icons.error, color: _serviceEnabled ? T.green : T.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _serviceEnabled
                  ? 'Accessibility Service চালু আছে ✅'
                  : 'Accessibility Service বন্ধ আছে — এনাবল করতে হবে',
              style: TextStyle(color: _serviceEnabled ? T.green : T.red, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          if (!_serviceEnabled)
            TextButton(
              onPressed: () async {
                await DumperBridge.openAccessibilitySettings();
              },
              child: const Text('Enable', style: TextStyle(color: T.gold, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _instructionsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: T.panel, borderRadius: BorderRadius.circular(10)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ব্যবহারের ধাপ:', style: TextStyle(color: T.gold, fontSize: 12, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('১. Accessibility Service এনাবল আছে কি না নিশ্চিত হও',
              style: TextStyle(color: T.dim, fontSize: 11)),
          Text('২. "SCAN NOW" চাপো — সাথে সাথে ৫ সেকেন্ডের কাউন্টডাউন শুরু হবে',
              style: TextStyle(color: T.dim, fontSize: 11)),
          Text('৩. কাউন্টডাউন চলাকালীনই দ্রুত MT5 অ্যাপে সুইচ করো এবং কাঙ্ক্ষিত স্ক্রিনে যাও',
              style: TextStyle(color: T.dim, fontSize: 11)),
          Text('৪. ৫ সেকেন্ড পর স্বয়ংক্রিয়ভাবে স্ক্যান হবে — তারপর এই অ্যাপে ফিরে এসে ফলাফল দেখো',
              style: TextStyle(color: T.dim, fontSize: 11)),
        ],
      ),
    );
  }
}
