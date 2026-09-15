import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants.dart';
import '../executor/dumper_bridge.dart';
import 'dump_viewer_page.dart';

/// MT5 UI স্ক্যান করার মূল স্ক্রিন। ব্যবহারের ধাপ:
/// ১. Accessibility Service এনাবল আছে কি না চেক/এনাবল
/// ২. MT5 অ্যাপ ওপেন করে যে স্ক্রিন স্ক্যান করতে চাও সেখানে যাওয়া
/// ৩. এই অ্যাপে ফিরে এসে "SCAN NOW" চাপা — এটা তখনকার MT5 স্ক্রিনের
///    node tree ধরে ফেলবে
class DumperPage extends StatefulWidget {
  const DumperPage({super.key});

  @override
  State<DumperPage> createState() => _DumperPageState();
}

class _DumperPageState extends State<DumperPage> with WidgetsBindingObserver {
  bool _serviceEnabled = false;
  bool _scanning = false;
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
    super.dispose();
  }

  /// অ্যাপ থেকে বের হয়ে সেটিংস/MT5-এ গিয়ে আবার ফিরে এলে স্বয়ংক্রিয়ভাবে
  /// service-এর স্ট্যাটাস রিফ্রেশ হয় — ইউজারকে বারবার ম্যানুয়ালি রিফ্রেশ
  /// করতে হয় না।
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

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _message = null;
    });
    try {
      final path = await DumperBridge.dumpNow();
      if (!mounted) return;
      setState(() => _message = '✅ স্ক্যান সফল! ফাইল সেভ হয়েছে: ${path.split('/').last}');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = '⚠️ $e');
    } finally {
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
              ElevatedButton(
                onPressed: (_serviceEnabled && !_scanning) ? _scan : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: T.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _scanning ? 'স্ক্যান হচ্ছে...' : '📸 SCAN NOW (বর্তমান MT5 স্ক্রিন)',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
          Text('১. উপরে Enable চেপে Accessibility Service চালু করো (RTX Auto Trader খুঁজে অন করো)',
              style: TextStyle(color: T.dim, fontSize: 11)),
          Text('২. MT5 অ্যাপ ওপেন করে যে স্ক্রিন স্ক্যান করতে চাও সেখানে যাও',
              style: TextStyle(color: T.dim, fontSize: 11)),
          Text('৩. এই অ্যাপে ফিরে এসে "SCAN NOW" চাপো',
              style: TextStyle(color: T.dim, fontSize: 11)),
          Text('৪. স্ক্যান ফলাফল লিস্টে দেখাবে — চাপলে দেখা যাবে, শেয়ার আইকনে চাপলে পাঠানো যাবে',
              style: TextStyle(color: T.dim, fontSize: 11)),
        ],
      ),
    );
  }
}
