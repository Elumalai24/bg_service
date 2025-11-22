// lib/main.dart

import 'dart:async';
import 'dart:ui';

import 'package:bg_service/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_helper.dart';
import 'events_screen.dart';

/// ------------------------------------------------------------
/// APP ENTRY
/// ------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ask permissions (activity recognition + notification)
  final ok = await PermissionsService.requestAllPermissions();
  if (!ok) {
    debugPrint("⚠ Some permissions NOT granted!");
  }

  // Init DB and ensure 2 events (Morning + Evening) exist
  await DBHelper.instance.init();
  await DBHelper.instance.insertMockEventsIfEmpty();

  // Store program start date (for 5-day limit)
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey('program_start_date')) {
    final now = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day);
    await prefs.setString('program_start_date', startDay.toIso8601String());
  }

  // Start background service
  await initializeService();

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MyApp(),
  ));
}

/// ------------------------------------------------------------
/// BACKGROUND SERVICE INITIALIZATION
/// ------------------------------------------------------------
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'MY FOREGROUND SERVICE',
    description: 'Important notifications',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin notifications =
  FlutterLocalNotificationsPlugin();

  await notifications.initialize(
    const InitializationSettings(
      iOS: DarwinInitializationSettings(),
      android: AndroidInitializationSettings('ic_bg_service_small'),
    ),
  );

  await notifications
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'SERVICE STARTING',
      initialNotificationContent: 'Preparing...',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

/// ------------------------------------------------------------
/// iOS BACKGROUND ENTRY
/// ------------------------------------------------------------
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  List<String> log = prefs.getStringList('log') ?? [];
  log.add("iOS BG: ${DateTime.now()}");
  await prefs.setStringList('log', log);

  return true;
}

/// ------------------------------------------------------------
/// ANDROID BACKGROUND ENTRY
/// ------------------------------------------------------------
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await DBHelper.instance.init();
  final prefs = await SharedPreferences.getInstance();
  final notifications = FlutterLocalNotificationsPlugin();

  // -----------------------------
  // PROGRAM RANGE: 5 DAYS ONLY
  // -----------------------------
  String? startStr = prefs.getString("program_start_date");
  DateTime? programStart =
  startStr != null ? DateTime.parse(startStr) : null;

  bool isWithinProgramDays(DateTime now) {
    if (programStart == null) return true; // fallback
    final startDay = DateTime(programStart!.year, programStart!.month, programStart!.day);
    final currentDay = DateTime(now.year, now.month, now.day);
    final diff = currentDay.difference(startDay).inDays;
    // Valid for 5 days: days 0,1,2,3,4
    return diff >= 0 && diff < 5;
  }

  // -----------------------------
  // TOTAL STEPS (lifetime)
  // -----------------------------
  int lastRaw = prefs.getInt("last_raw") ?? -1;
  int totalSteps = prefs.getInt("total_steps") ?? 0;

  // -----------------------------
  // EVENT STATE (Morning / Evening)
  // -----------------------------
  Map<String, dynamic>? activeEvent;
  int? lastEventId;
  int? eventStartSteps;  // baseline raw steps for this event window
  int lastEventSteps = 0; // last computed eventSteps for delta accumulation

  // -----------------------------
  // TIME JUMP DETECTION
  // -----------------------------
  int lastSystemTime =
      prefs.getInt("last_system_time") ?? DateTime.now().millisecondsSinceEpoch;

  Future<void> checkTimeJump() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final diff = (nowMs - lastSystemTime).abs();

    if (diff > 60000) {
      debugPrint("⏱ TIME JUMP DETECTED: ${diff ~/ 1000}s");

      // Reset event state on big jump
      activeEvent = null;
      lastEventId = null;
      eventStartSteps = null;
      lastEventSteps = 0;
      await prefs.remove("last_step_count");
    }

    lastSystemTime = nowMs;
    await prefs.setInt("last_system_time", nowMs);
  }

  // Find active event for current time using DB times as templates
  Future<Map<String, dynamic>?> getActiveEvent(DateTime now) async {
    final events = await DBHelper.instance.getEvents();

    for (var e in events) {
      final storedStart = DateTime.parse(e['startDateTime']);
      final storedEnd = DateTime.parse(e['endDateTime']);

      final startToday = DateTime(
        now.year,
        now.month,
        now.day,
        storedStart.hour,
        storedStart.minute,
      );
      final endToday = DateTime(
        now.year,
        now.month,
        now.day,
        storedEnd.hour,
        storedEnd.minute,
      );

      if (!now.isBefore(startToday) && !now.isAfter(endToday)) {
        return e;
      }
    }
    return null;
  }

  // Update ongoing notification
  Future<void> updateNotification(int raw) async {
    final name = activeEvent != null ? activeEvent!['name'].toString() : "No active event";

    if (service is AndroidServiceInstance) {
      await notifications.show(
        888,
        "Steps: $raw",
        name,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'MY FOREGROUND SERVICE',
            icon: 'ic_bg_service_small',
            ongoing: true,
          ),
        ),
      );

      await service.setForegroundNotificationInfo(
        title: "Steps: $raw",
        content: name,
      );
    }
  }

  // --------------------------------------------------------
  // PEDOMETER LISTENER
  // --------------------------------------------------------
  final pedStream = Pedometer.stepCountStream.listen((StepCount ev) async {
    final raw = ev.steps;
    final now = DateTime.now();

    await checkTimeJump();

    // -------------------------
    // TOTAL STEPS (always)
    // -------------------------
    if (lastRaw == -1) lastRaw = raw;

    int inc = raw - lastRaw;
    if (inc < 0) inc = 0;

    totalSteps += inc;

    lastRaw = raw;

    await prefs.setInt("last_raw", raw);
    await prefs.setInt("total_steps", totalSteps);

    // Notify UI about total & raw
    service.invoke("steps_update", {
      "raw_steps": raw,
      "total_steps": totalSteps,
    });

    await updateNotification(raw);

    // -------------------------
    // EVENT LOGIC: only within 5 days
    // -------------------------
    if (!isWithinProgramDays(now)) {
      // After 5 days → no event updates, only total
      return;
    }

    // Determine which event (morning/evening) is active right now
    final newEvent = await getActiveEvent(now);

    if (newEvent == null) {
      // No event window currently
      activeEvent = null;
      lastEventId = null;
      eventStartSteps = null;
      lastEventSteps = 0;
      return;
    }

    // If event switched (Morning ↔ Evening)
    if (lastEventId != newEvent['id']) {
      activeEvent = newEvent;
      lastEventId = newEvent['id'];
      eventStartSteps = null;
      lastEventSteps = 0;
    }

    final eventId = activeEvent!['id'] as int;

    // Setup baseline for this event window
    if (eventStartSteps == null) {
      eventStartSteps = raw;
      lastEventSteps = 0;
      await prefs.setInt("event_start_steps_$eventId", eventStartSteps!);
    }

    // eventSteps = raw steps inside this window
    int eventSteps = raw - eventStartSteps!;
    if (eventSteps < 0) eventSteps = 0;

    // delta steps since last call (important!)
    int delta = eventSteps - lastEventSteps;
    if (delta < 0) delta = 0;

    lastEventSteps = eventSteps;

    if (delta > 0) {
      await DBHelper.instance.updateEventStatsAccumulate(
        userId: "user1",
        eventId: eventId,
        steps: delta,
        distance: delta * 0.8,
        calories: delta * 0.04,
      );
    }
  });

  // --------------------------------------------------------
  // PERIODIC UI UPDATE (fallback)
  // --------------------------------------------------------
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    await checkTimeJump();

    int raw = prefs.getInt("last_raw") ?? 0;
    await updateNotification(raw);

    service.invoke("update", {
      "steps": raw,
      "total": prefs.getInt("total_steps") ?? 0,
      "event": activeEvent != null ? activeEvent!['name'] : "No event",
    });
  });

  // Optional: handle explicit stop
  service.on('stopService').listen((event) async {
    await pedStream.cancel();
    service.stopSelf();
  });
}

/// ------------------------------------------------------------
/// UI — HOME SCREEN
/// ------------------------------------------------------------
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String rawSteps = "0";
  String totalSteps = "0";
  String eventName = "No event";

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _listenUpdates();
  }

  Future<void> _loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      rawSteps = (prefs.getInt('last_raw') ?? 0).toString();
      totalSteps = (prefs.getInt('total_steps') ?? 0).toString();
      eventName = "No event";
    });
  }

  void _listenUpdates() {
    FlutterBackgroundService().on('steps_update').listen((data) {
      if (data == null) return;
      setState(() {
        rawSteps = data['raw_steps'].toString();
        totalSteps = data['total_steps'].toString();
      });
    });

    FlutterBackgroundService().on('update').listen((data) {
      if (data == null) return;
      setState(() {
        eventName = (data['event'] ?? "No event").toString();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pedometer Home")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Raw Steps", style: TextStyle(fontSize: 22)),
            Text(rawSteps, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 20),
            const Text("Total Steps", style: TextStyle(fontSize: 22)),
            Text(
              totalSteps,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text("Active Event", style: TextStyle(fontSize: 22)),
            Text(
              eventName,
              style: const TextStyle(fontSize: 26, color: Colors.blue),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EventsListScreen(),
                  ),
                );
              },
              child: const Text("Show Events"),
            ),
          ],
        ),
      ),
    );
  }
}
