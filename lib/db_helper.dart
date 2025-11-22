// lib/db/db_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DBHelper {
  DBHelper._privateConstructor();
  static final DBHelper instance = DBHelper._privateConstructor();

  static const _dbName = 'event_tracker.db';
  static const _dbVersion = 1;

  Database? _db;

  /// Initialize the database (should be called once in main)
  Future<void> init() async {
    if (_db != null) return;

    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbName);

    print("DB PATH: $path");

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  /// Database schema creation
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        startDateTime TEXT NOT NULL,
        endDateTime TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE event_stats(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        eventId INTEGER NOT NULL,
        steps INTEGER NOT NULL DEFAULT 0,
        distance REAL NOT NULL DEFAULT 0,
        calories REAL NOT NULL DEFAULT 0,
        UNIQUE(userId, eventId)
      )
    ''');
  }

  // -----------------------------
  // EVENTS TABLE
  // -----------------------------

  Future<int> insertEvent({
    required String name,
    required DateTime start,
    required DateTime end,
  }) async {
    final db = _ensureDb();
    return await db.insert('events', {
      'name': name,
      'startDateTime': start.toIso8601String(),
      'endDateTime': end.toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getEvents() async {
    final db = _ensureDb();
    return await db.query('events', orderBy: 'startDateTime ASC');
  }

  Future<Map<String, dynamic>?> getEventById(int id) async {
    final db = _ensureDb();
    final rows = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  // -----------------------------
  // EVENT_STATS TABLE
  // -----------------------------

  Future<void> updateEventStatsAbsolute({
    required String userId,
    required int eventId,
    required int steps,
    required double distance,
    required double calories,
  }) async {
    final db = _ensureDb();

    final updated = await db.update(
      'event_stats',
      {
        'steps': steps,
        'distance': distance,
        'calories': calories,
      },
      where: 'userId = ? AND eventId = ?',
      whereArgs: [userId, eventId],
    );

    if (updated == 0) {
      await db.insert('event_stats', {
        'userId': userId,
        'eventId': eventId,
        'steps': steps,
        'distance': distance,
        'calories': calories,
      });
    }
  }

  Future<Map<String, dynamic>?> getEventStats(String userId, int eventId) async {
    final db = _ensureDb();
    final rows = await db.query(
      'event_stats',
      where: 'userId = ? AND eventId = ?',
      whereArgs: [userId, eventId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllEventStats() async {
    final db = _ensureDb();
    return await db.query('event_stats');
  }

  /// Aggregate all stats across all events
  Future<Map<String, dynamic>> getTotalStats(String userId) async {
    final db = _ensureDb();
    final rows = await db.rawQuery('''
      SELECT 
        IFNULL(SUM(steps), 0) AS steps,
        IFNULL(SUM(distance), 0) AS distance,
        IFNULL(SUM(calories), 0) AS calories
      FROM event_stats
      WHERE userId = ?
    ''', [userId]);

    final first = rows.first;

    return {
      'steps': first['steps'] ?? 0,
      'distance': _safeDouble(first['distance']),
      'calories': _safeDouble(first['calories']),
    };
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  // -----------------------------
  // DEBUG / MOCK DATA
  // -----------------------------

  Future<void> insertMockEventsIfEmpty() async {
    final db = _ensureDb();

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM events'),
    ) ??
        0;

    if (count == 0) {
      final now = DateTime.now();

      await insertEvent(
        name: 'Morning Walk',
        start: now.add(const Duration(minutes: 1)),
        end: now.add(const Duration(minutes: 2)),
      );

      await insertEvent(
        name: 'Evening Walk',
        start: now.add(const Duration(minutes: 3)),
        end: now.add(const Duration(minutes: 40)),
      );

      print("Mock events inserted ✔");
    }
  }

  // -----------------------------
  // INTERNAL UTILS
  // -----------------------------

  Database _ensureDb() {
    if (_db == null) {
      throw Exception(
        'Database not initialized. Call DBHelper.instance.init() before using.',
      );
    }
    return _db!;
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
