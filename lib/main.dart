import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'ui/launch_page.dart';
import 'ui/overlay_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RtxAutoTraderApp());
}

/// ফ্লোটিং বাবল একটা সম্পূর্ণ আলাদা Flutter engine-এ চলে (মেইন অ্যাপ
/// থেকে independent), তাই এর নিজস্ব entry point দরকার — এই
/// @pragma("vm:entry-point") ছাড়া flutter_overlay_window এটা খুঁজে পাবে না।
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayHome(),
  ));
}

class RtxAutoTraderApp extends StatelessWidget {
  const RtxAutoTraderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RTX Auto Trader',
      theme: ThemeData(
        scaffoldBackgroundColor: T.bg,
        colorScheme: ColorScheme.dark(
          primary: T.green,
          secondary: T.gold,
          surface: T.card,
        ),
        fontFamily: 'Roboto',
      ),
      home: const LaunchPage(),
    );
  }
}
