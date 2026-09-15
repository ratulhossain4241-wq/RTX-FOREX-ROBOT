import 'package:flutter/material.dart';
import 'constants.dart';

/// প্রতিটা স্ট্র্যাটেজি মোডের নাম ও রঙ — UI-তে দেখানোর জন্য।
/// signal_router.dart-এর kModeRunners-এর key-গুলোর সাথে id মিলতে হবে।
class ModeMeta {
  final String id;
  final String name;
  final Color color;
  const ModeMeta({required this.id, required this.name, required this.color});
}

const List<ModeMeta> kSignalModes = [
  ModeMeta(id: 'sweep', name: 'Sweep Reclaim', color: T.cyan),
  ModeMeta(id: 'crt_tbs', name: 'CRT + TBS', color: T.gold),
  ModeMeta(id: 'qm_smc', name: 'QM + SMC', color: T.green),
  ModeMeta(id: 'price_action_fib', name: 'Price Action + Fib', color: Color(0xFFFF66CC)),
];

ModeMeta modeMetaFor(String id) =>
    kSignalModes.firstWhere((m) => m.id == id, orElse: () => kSignalModes.first);
