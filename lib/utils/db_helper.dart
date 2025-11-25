// lib/db_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/event_model.dart';

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
        id INTEGER PRIMARY KEY,
        event_name TEXT,
        event_date TEXT,
        event_from_date TEXT,
        event_to_date TEXT,
        event_from_time TEXT,
        event_to_time TEXT,
        event_location TEXT,
        event_desc TEXT,
        event_style TEXT,
        event_type TEXT,
        status TEXT,
        created_at TEXT,
        updated_at TEXT,
        event_venue_type TEXT,
        event_banner TEXT,
        event_goal TEXT,
        event_goal_type TEXT,
        event_completion_medal TEXT,
        event_prize_desc TEXT,
        client TEXT,
        event_duration_minutes INTEGER
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

    // NEW: Daily stats table
    await db.execute('''
      CREATE TABLE daily_event_stats(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        eventId INTEGER NOT NULL,
        date TEXT NOT NULL,
        steps INTEGER NOT NULL DEFAULT 0,
        distance REAL NOT NULL DEFAULT 0,
        calories REAL NOT NULL DEFAULT 0,
        UNIQUE(userId, eventId, date)
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
  /// EVENTS
  /// ----------------------------------------------------------------------

  /// Return all events as EventModel objects (ordered by id ASC)
  Future<List<EventModel>> getEvents() async {
    final db = _ensureDb();
    final rows = await db.query('events', orderBy: "id ASC");
    return rows.map((r) => EventModel.fromDb(r)).toList();
  }

  /// Get single event by ID
  Future<EventModel?> getEventById(int id) async {
    final db = _ensureDb();
    final rows = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return EventModel.fromDb(rows.first);
    }
    return null;
  }

  /// Insert or replace an event row (useful for syncing)
  Future<int> insertOrReplaceEvent(EventModel event) async {
    final db = _ensureDb();
    return db.insert(
      'events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert event (used by mock insert)
  Future<int> insertEventRow(Map<String, dynamic> row) async {
    final db = _ensureDb();
    return db.insert('events', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 🔥 Insert mock events if empty (uses the API-shaped mock you provided)
  Future<void> insertMockEventsIfEmpty() async {
    final db = _ensureDb();

    final cnt = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM events"),
    ) ??
        0;

    if (cnt > 0) return;

    final mock = <Map<String, dynamic>>[
      {
        "id": 199,
        "event_name": "Digital Walkathon Morning",
        "event_date": "2025-11-10",
        "event_from_date": "2025-11-10",
        "event_to_date": "2025-12-10",
        "event_from_time": "04:00",
        "event_to_time": "09:00",
        "event_location": "At their own places",
        "event_desc": "Qualifier Criteria (November 10th – December 10th)\nWalk a minimum of 3 km per day.\nComplete at least 21 days.\nCover a total of 63 km before December 10th.\n\nThose who complete 63 km, which is at least 21 days of walking 3 km per day, will be considered Qualifiers.\n\nMega Event – December 14th\nQualifiers only can compete for winners’ titles: 5 km | 10 km | 21 km.\n\nTop 3 finishers in these categories will be declared as winners.\nNon-qualifiers can still participate but won’t be included in the winners list.",
        "event_style": null,
        "event_type": "2",
        "status": "1",
        "created_at": "2025-11-02T09:52:10.000000Z",
        "updated_at": "2025-11-02T14:58:11.000000Z",
        "event_venue_type": "1",
        "event_banner": "https://fitex.co.in/build/images/event_banner/1762077129.png",
        "event_goal": "3",
        "event_goal_type": "1",
        "event_completion_medal": "Yes",
        "event_prize_desc": "5 km | 10 km | 21 km.\nTop 3 finishers in these categories will be declared as winners.",
        "client": "0",
        "event_duration_minutes": 300
      },
      {
        "id": 200,
        "event_name": "Digital Walkathon Evening",
        "event_date": "2025-11-10",
        "event_from_date": "2025-11-10",
        "event_to_date": "2025-12-10",
        "event_from_time": "17:00",
        "event_to_time": "22:00",
        "event_location": "At their own places",
        "event_desc": "Qualifier Criteria (November 10th – December 10th)\nWalk a minimum of 3 km per day.\nComplete at least 21 days.\nCover a total of 63 km before December 10th.\n\nThose who complete 63 km, which is at least 21 days of walking 3 km per day, will be considered Qualifiers.\n\nMega Event – December 14th\nQualifiers only can compete for winners’ titles: 5 km | 10 km | 21 km.\n\nTop 3 finishers in these categories will be declared as winners.\nNon-qualifiers can still participate but won’t be included in the winners list.",
        "event_style": null,
        "event_type": "2",
        "status": "1",
        "created_at": "2025-11-02T09:58:41.000000Z",
        "updated_at": "2025-11-02T09:59:43.000000Z",
        "event_venue_type": "1",
        "event_banner": "https://fitex.co.in/build/images/event_banner/1762077521.png",
        "event_goal": "3",
        "event_goal_type": "1",
        "event_completion_medal": "Yes",
        "event_prize_desc": "5 km | 10 km | 21 km.\nTop 3 finishers in these categories will be declared as winners.",
        "client": "0",
        "event_duration_minutes": 300
      },
      {
        "id": 211,
        "event_name": "Walk it",
        "event_date": "2025-11-22",
        "event_from_date": "2025-11-22",
        "event_to_date": "2025-11-30",
        "event_from_time": "13:25",
        "event_to_time": "13:35",
        "event_location": "venue",
        "event_desc": "Walk More",
        "event_style": null,
        "event_type": "2",
        "status": "1",
        "created_at": "2025-11-22T07:52:14.000000Z",
        "updated_at": "2025-11-22T07:52:14.000000Z",
        "event_venue_type": "1",
        "event_banner": "https://fitex.co.in/build/images/event_banner/1763797934.png",
        "event_goal": "1",
        "event_goal_type": "1",
        "event_completion_medal": "Yes",
        "event_prize_desc": "Test Rewards",
        "client": "0",
        "event_duration_minutes": 10
      }
    ];

    for (final m in mock) {
      // Ensure event_date/from/to are stored as date-only strings
      final row = {
        'id': m['id'],
        'event_name': m['event_name'],
        'event_date': m['event_date'],
        'event_from_date': m['event_from_date'],
        'event_to_date': m['event_to_date'],
        'event_from_time': m['event_from_time'],
        'event_to_time': m['event_to_time'],
        'event_location': m['event_location'],
        'event_desc': m['event_desc'],
        'event_style': m['event_style'],
        'event_type': m['event_type'],
        'status': m['status'],
        'created_at': m['created_at'],
        'updated_at': m['updated_at'],
        'event_venue_type': m['event_venue_type'],
        'event_banner': m['event_banner'],
        'event_goal': m['event_goal'],
        'event_goal_type': m['event_goal_type'],
        'event_completion_medal': m['event_completion_medal'],
        'event_prize_desc': m['event_prize_desc'],
        'client': m['client'],
        'event_duration_minutes': m['event_duration_minutes'],
      };

      await db.insert('events', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    print("✔ Inserted ${mock.length} mock events.");
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

  /// ----------------------------------------------------------------------
  /// DAILY EVENT STATS
  /// ----------------------------------------------------------------------

  /// Adds +steps (delta) to the daily record
  Future<void> updateDailyEventStats({
    required String userId,
    required int eventId,
    required int steps,
    required double distance,
    required double calories,
  }) async {
    final db = _ensureDb();
    final today = DateTime.now();
    final dateStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Get existing record for TODAY
    final exists = await db.query(
      "daily_event_stats",
      where: "userId = ? AND eventId = ? AND date = ?",
      whereArgs: [userId, eventId, dateStr],
      limit: 1,
    );

    if (exists.isNotEmpty) {
      final prev = exists.first;

      final newSteps = (prev['steps'] as int) + steps;
      final newDist = _safeDouble(prev['distance']) + distance;
      final newCal = _safeDouble(prev['calories']) + calories;

      await db.update(
        "daily_event_stats",
        {
          "steps": newSteps,
          "distance": newDist,
          "calories": newCal,
        },
        where: "userId = ? AND eventId = ? AND date = ?",
        whereArgs: [userId, eventId, dateStr],
      );
    } else {
      // Insert fresh for TODAY
      await db.insert("daily_event_stats", {
        "userId": userId,
        "eventId": eventId,
        "date": dateStr,
        "steps": steps,
        "distance": distance,
        "calories": calories,
      });
    }
  }

  /// Get daily stats for one event
  Future<List<Map<String, dynamic>>> getDailyStatsForEvent(String userId, int eventId) async {
    final db = _ensureDb();
    return db.query(
      "daily_event_stats",
      where: "userId = ? AND eventId = ?",
      whereArgs: [userId, eventId],
      orderBy: "date ASC",
    );
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
      whereArgs: [userId],
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
