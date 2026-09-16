import 'package:flutter/material.dart';
import 'constants.dart';

class ModeMeta {
  final String id;
  final String name;
  final Color color;
  const ModeMeta({required this.id, required this.name, required this.color});
}

const List<ModeMeta> kSignalModes = [
  ModeMeta(id: 'sweep', name: 'Sweep Reclaim', color: T.cyan),
  ModeMeta(id: 'crt_tbs', name: 'CRT + TBS', color: T.gold),
  ModeMeta(id: 'wyckoff_ict', name: 'Wyckoff + ICT', color: Color(0xFFFF9F45)),
  ModeMeta(id: 'qm_smc', name: 'QM + SMC', color: T.green),
  ModeMeta(id: 'price_action_fib', name: 'Price Action + Fib', color: Color(0xFFFF66CC)),
];

ModeMeta modeMetaFor(String id) =>
    kSignalModes.firstWhere((m) => m.id == id, orElse: () => kSignalModes.first);
