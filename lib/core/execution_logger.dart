import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// প্রতিটি অটো এক্সিকিউশনের বিস্তারিত লগ রাখে।
/// কোন সিগন্যালে কী অ্যাকশন নেওয়া হয়েছে, সফল/ব্যর্থ — সব এখানে থাকে।
/// ডিবাগ এবং পরে অ্যানালাইসিসের জন্য খুব কাজে লাগে।
class ExecutionLogger {
  static Database? _db;

  static Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'rtx_execution_log.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE execution_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            signalId TEXT,
            market TEXT,
            direction TEXT,
            action TEXT,
            success INTEGER,
            message TEXT,
            lotSize REAL,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  /// একটি এক্সিকিউশন লগ সেভ করে
  static Future<void> log({
    required String signalId,
    required String market,
    required String direction,
    required String action,
    required bool success,
    required String message,
    double? lotSize,
  }) async {
    final db = await _database();
    await db.insert('execution_logs', {
      'signalId': signalId,
      'market': market,
      'direction': direction,
      'action': action,
      'success': success ? 1 : 0,
      'message': message,
      'lotSize': lotSize,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// আজকের সব লগ আনে
  static Future<List<Map<String, dynamic>>> todaysLogs() async {
    final db = await _database();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.query(
      'execution_logs',
      where: "createdAt LIKE ?",
      whereArgs: ['$today%'],
      orderBy: 'createdAt DESC',
    );
  }

  /// শেষ ২০টা লগ
  static Future<List<Map<String, dynamic>>> recentLogs({int limit = 20}) async {
    final db = await _database();
    return db.query(
      'execution_logs',
      orderBy: 'createdAt DESC',
      limit: limit,
    );
  }
}
