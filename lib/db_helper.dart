// lib/db_helper.dart

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

  /// ----------------------------------------------------------------------
  /// INITIALIZE DB
  /// ----------------------------------------------------------------------
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

  /// ----------------------------------------------------------------------
  /// SCHEMA
  /// ----------------------------------------------------------------------
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

  Database _ensureDb() {
    if (_db == null) {
      throw Exception("DB not initialized. Call DBHelper.instance.init()");
    }
    return _db!;
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  /// ----------------------------------------------------------------------
  /// EVENTS — Only 2 events permanently
  /// ----------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getEvents() async {
    final db = _ensureDb();
    return db.query('events', orderBy: "id ASC");
  }

  Future<int> insertEvent({
    required String name,
    required DateTime start,
    required DateTime end,
  }) async {
    final db = _ensureDb();
    return db.insert('events', {
      'name': name,
      'startDateTime': start.toIso8601String(),
      'endDateTime': end.toIso8601String(),
    });
  }

  /// 🔥 ONLY create 2 events: morning + evening
  Future<void> insertMockEventsIfEmpty() async {
    final db = _ensureDb();

    final cnt = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM events"),
    ) ??
        0;

    if (cnt > 0) return;

    // Create ANY day — time portion only is important
    final today = DateTime.now();

    // Morning
    await insertEvent(
      name: "Morning Event",
      start: DateTime(today.year, today.month, today.day, 10, 0),
      end: DateTime(today.year, today.month, today.day, 10, 5),
    );

    // Evening
    await insertEvent(
      name: "Evening Event",
      start: DateTime(today.year, today.month, today.day, 18, 0),
      end: DateTime(today.year, today.month, today.day, 18, 5),
    );

    print("✔ Inserted 2 permanent events.");
  }

  /// ----------------------------------------------------------------------
  /// ACCUMULATIVE EVENT STATS
  /// ----------------------------------------------------------------------

  /// Adds +steps (delta), not overwriting
  Future<void> updateEventStatsAccumulate({
    required String userId,
    required int eventId,
    required int steps,
    required double distance,
    required double calories,
  }) async {
    final db = _ensureDb();

    // Get existing record
    final exists = await db.query(
      "event_stats",
      where: "userId = ? AND eventId = ?",
      whereArgs: [userId, eventId],
      limit: 1,
    );

    if (exists.isNotEmpty) {
      final prev = exists.first;

      final newSteps = (prev['steps'] as int) + steps;
      final newDist = _safeDouble(prev['distance']) + distance;
      final newCal = _safeDouble(prev['calories']) + calories;

      await db.update(
        "event_stats",
        {
          "steps": newSteps,
          "distance": newDist,
          "calories": newCal,
        },
        where: "userId = ? AND eventId = ?",
        whereArgs: [userId, eventId],
      );
    } else {
      // Insert fresh
      await db.insert("event_stats", {
        "userId": userId,
        "eventId": eventId,
        "steps": steps,
        "distance": distance,
        "calories": calories,
      });
    }
  }

  /// Get stats for one event
  Future<Map<String, dynamic>?> getEventStats(String userId, int eventId) async {
    final db = _ensureDb();
    final rows = await db.query(
      "event_stats",
      where: "userId = ? AND eventId = ?",
      whereArgs: [userId, eventId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Get ALL stats for user
  Future<List<Map<String, dynamic>>> getAllEventStats(String userId) async {
    final db = _ensureDb();
    return db.query(
      "event_stats",
      where: "userId = ?",
    );
  }

  /// TOTAL (sum of both events)
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

    final r = rows.first;

    return {
      "steps": r["steps"] ?? 0,
      "distance": _safeDouble(r["distance"]),
      "calories": _safeDouble(r["calories"]),
    };
  }

  /// ----------------------------------------------------------------------
  /// SAFE TYPE CONVERSION
  /// ----------------------------------------------------------------------
  double _safeDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
