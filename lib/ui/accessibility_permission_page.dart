import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/accessibility_service.dart';
import '../core/store.dart';

/// ইউজারকে Accessibility Service চালু করার জন্য গাইড করে।
/// এখান থেকে সরাসরি Android Settings এ নিয়ে যাওয়া যায়।
class AccessibilityPermissionPage extends StatefulWidget {
  const AccessibilityPermissionPage({super.key});

  @override
  State<AccessibilityPermissionPage> createState() => _AccessibilityPermissionPageState();
}

class _AccessibilityPermissionPageState extends State<AccessibilityPermissionPage> {
  bool _checking = true;
  bool _isEnabled = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    final enabled = await AccessibilityService.isEnabled();
    await Store.setAccessibilityEnabled(enabled);
    if (!mounted) return;
    setState(() {
      _isEnabled = enabled;
      _checking = false;
      _status = enabled
          ? 'Accessibility Service চালু আছে ✅'
          : 'Accessibility Service বন্ধ আছে — নিচের বাটন দিয়ে চালু করুন';
    });
  }

  Future<void> _openSettings() async {
    await AccessibilityService.openAccessibilitySettings();
    // ইউজার ফিরে আসার পর আবার চেক করার জন্য একটু অপেক্ষা
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.card,
        title: const Text('Accessibility সেটআপ', style: TextStyle(color: T.green, fontSize: 16)),
        iconTheme: const IconThemeData(color: T.green),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: T.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isEnabled ? T.green : T.red),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isEnabled ? Icons.verified : Icons.warning_amber_rounded,
                      color: _isEnabled ? T.green : T.gold,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _checking ? 'চেক করা হচ্ছে...' : _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isEnabled ? T.green : T.gold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'কেন লাগবে?',
                style: TextStyle(color: T.gold, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Text(
                'অটোমেটিকভাবে MetaTrader 5 অ্যাপে Buy/Sell বাটন ক্লিক করতে এবং পজিশন ক্লোজ করতে Accessibility Service প্রয়োজন। '
                'এটা শুধু MT5 অ্যাপের ভিতরে কাজ করবে।',
                style: TextStyle(color: T.dim, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              const Text(
                'কীভাবে চালু করবেন:',
                style: TextStyle(color: T.gold, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Text(
                '১. নিচের বাটনে চাপুন\n'
                '২. “Installed apps” বা “Downloaded apps” এ যান\n'
                '৩. “RTX Auto Trader” খুঁজে চালু করুন\n'
                '৪. ফিরে এসে “আবার চেক করুন” বাটনে চাপুন',
                style: TextStyle(color: T.dim, fontSize: 13, height: 1.5),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: T.green,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _openSettings,
                child: const Text('Accessibility Settings খুলুন', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: T.cyan),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _checkStatus,
                child: const Text('আবার চেক করুন', style: TextStyle(color: T.cyan, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
