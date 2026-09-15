import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'models.dart';

/// সব ট্রেডের স্থায়ী রেকর্ড — SharedPreferences-এ শত শত ট্রেড রাখা
/// অনুপযুক্ত, তাই SQLite ব্যবহার করা হচ্ছে যাতে History স্ক্রিন আর
/// ভবিষ্যতের পারফরম্যান্স-অ্যানালাইসিস দুটোই ফাস্ট থাকে।
class TradeLogger {
  static Database? _db;

  static Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'rtx_trades.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE trades (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            market TEXT NOT NULL,
            direction TEXT NOT NULL,
            entryPrice REAL NOT NULL,
            exitPrice REAL,
            lotSize REAL NOT NULL,
            openedAt TEXT NOT NULL,
            closedAt TEXT,
            status TEXT NOT NULL,
            profitUsd REAL
          )
        ''');
      },
    );
    return _db!;
  }

  static Future<int> insertOpenTrade(TradeRecord trade) async {
    final db = await _database();
    return db.insert('trades', trade.toMap()..remove('id'));
  }

  static Future<void> closeTrade({
    required int id,
    required double exitPrice,
    required String status, // 'won' or 'lost'
    required double profitUsd,
  }) async {
    final db = await _database();
    await db.update(
      'trades',
      {
        'exitPrice': exitPrice,
        'closedAt': DateTime.now().toIso8601String(),
        'status': status,
        'profitUsd': profitUsd,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<List<TradeRecord>> openTrades() async {
    final db = await _database();
    final rows = await db.query('trades', where: "status = 'open'");
    return rows.map(TradeRecord.fromMap).toList();
  }

  static Future<List<TradeRecord>> todaysTrades() async {
    final db = await _database();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.query(
      'trades',
      where: "openedAt LIKE ?",
      whereArgs: ['$today%'],
      orderBy: 'openedAt DESC',
    );
    return rows.map(TradeRecord.fromMap).toList();
  }

  static Future<Map<String, int>> todaysWinLossCount() async {
    final trades = await todaysTrades();
    final won = trades.where((t) => t.status == 'won').length;
    final lost = trades.where((t) => t.status == 'lost').length;
    return {'won': won, 'lost': lost};
  }
}
