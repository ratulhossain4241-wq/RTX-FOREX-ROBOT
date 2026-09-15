import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants.dart';
import '../executor/dumper_bridge.dart';

/// একটা নির্দিষ্ট dump ফাইলের ভেতরের কন্টেন্ট (পুরো node tree) দেখানোর
/// স্ক্রিন — মনোস্পেস ফন্টে, যাতে indentation স্পষ্ট বোঝা যায়।
class DumpViewerPage extends StatefulWidget {
  final String fileName;
  const DumpViewerPage({super.key, required this.fileName});

  @override
  State<DumpViewerPage> createState() => _DumpViewerPageState();
}

class _DumpViewerPageState extends State<DumpViewerPage> {
  String _content = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final content = await DumperBridge.readDump(widget.fileName);
    if (!mounted) return;
    setState(() {
      _content = content;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.card,
        title: Text(widget.fileName, style: const TextStyle(color: T.green, fontSize: 13)),
        iconTheme: const IconThemeData(color: T.green),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: T.cyan),
            onPressed: () => Share.share(_content, subject: widget.fileName),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: T.green))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _content.isEmpty ? 'ফাইল খালি বা পড়া যায়নি।' : _content,
                style: const TextStyle(color: T.green, fontSize: 11, fontFamily: 'monospace', height: 1.4),
              ),
            ),
    );
  }
}
