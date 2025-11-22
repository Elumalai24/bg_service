import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bg_service/permission_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'events_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // request all important permissions
  final ok = await PermissionsService.requestAllPermissions();

  if (!ok) print("⚠ Required permissions NOT granted!");

  await DBHelper.instance.init();
  await DBHelper.instance.insertMockEventsIfEmpty();

  await initializeService();

  runApp(MaterialApp(home: const MyApp()));
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'MY FOREGROUND SERVICE',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      iOS: DarwinInitializationSettings(),
      android: AndroidInitializationSettings('ic_bg_service_small'),
    ),
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'AWESOME SERVICE',
      initialNotificationContent: 'Initializing',
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

// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// 🔥 BACKGROUND SERVICE (Android + iOS foreground)
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await DBHelper.instance.init();

  final FlutterLocalNotificationsPlugin notifications =
  FlutterLocalNotificationsPlugin();

  final prefs = await SharedPreferences.getInstance();

  // ==============================================================
  // 🔥 TOTAL STEP VARIABLES (Restored on service start)
  // ==============================================================
  int lastRaw = prefs.getInt("last_raw") ?? -1;
  int totalSteps = prefs.getInt("total_steps") ?? 0;

  int? eventStartSteps;
  Map<String, dynamic>? activeEvent;

  // used to detect event switching
  int? lastEventId;

  Future<Map<String, dynamic>?> getActiveEvent() async {
    try {
      final now = DateTime.now().toIso8601String();
      final events = await DBHelper.instance.getEvents();
      for (var e in events) {
        if (now.compareTo(e['startDateTime']) >= 0 &&
            now.compareTo(e['endDateTime']) <= 0) {
          return e;
        }
      }
    } catch (e) {}
    return null;
  }

  Future<void> updateNotif(int raw) async {
    if (service is AndroidServiceInstance) {
      notifications.show(
        888,
        "Steps: $raw",
        activeEvent != null
            ? "Event: ${activeEvent!['name']}"
            : "No active event",
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'MY FOREGROUND SERVICE',
            icon: 'ic_bg_service_small',
            ongoing: true,
          ),
        ),
      );

      service.setForegroundNotificationInfo(
        title: "Steps: $raw",
        content: activeEvent != null ? activeEvent!["name"] : "No active event",
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 🔥 STEP STREAM LISTENER
  // ---------------------------------------------------------------------------

  StreamSubscription<StepCount>? pedSub;

  pedSub = Pedometer.stepCountStream.listen((StepCount event) async {
    final raw = event.steps;

    // ==============================================================
    // 🔥 TOTAL STEPS PERSISTENCE
    // ==============================================================
    if (lastRaw == -1) lastRaw = raw;

    int inc = raw - lastRaw;
    if (inc < 0) inc = 0;

    totalSteps += inc;

    prefs.setInt("last_raw", raw);
    prefs.setInt("total_steps", totalSteps);

    lastRaw = raw;

    // send update to UI
    service.invoke("steps_update", {
      "raw_steps": raw,
      "total_steps": totalSteps,
    });

    await updateNotif(raw);

    // ==============================================================
    // 🔥 EVENT SWITCHING LOGIC (Case B Fix)
    // ==============================================================
    final newEvent = await getActiveEvent();

    if (newEvent == null) {
      // No active event, reset everything
      if (activeEvent != null) {
        prefs.remove("event_start_steps_${activeEvent!['id']}");
      }

      activeEvent = null;
      lastEventId = null;
      eventStartSteps = null;
      prefs.remove("last_step_count");

      return;
    }

    if (lastEventId != newEvent['id']) {
      print("🔄 EVENT CHANGED TO → ${newEvent['name']}");

      // reset old event baseline
      if (lastEventId != null) {
        prefs.remove("event_start_steps_$lastEventId");
      }

      activeEvent = newEvent;
      lastEventId = newEvent['id'];
      eventStartSteps = null; // baseline will recalc
      prefs.remove("last_step_count");
    }

    // Now process event steps
    final eventId = activeEvent!["id"];

    final prevStats =
    await DBHelper.instance.getEventStats("user1", eventId);

    if (eventStartSteps == null) {
      if (prevStats != null) {
        eventStartSteps = raw - (prevStats['steps'] as num).toInt();
      } else {
        eventStartSteps = raw;
      }
      prefs.setInt("event_start_steps_$eventId", eventStartSteps!);
    }

    int eventSteps = raw - eventStartSteps!;
    if (eventSteps < 0) eventSteps = 0;

    await DBHelper.instance.updateEventStatsAbsolute(
      userId: "user1",
      eventId: eventId,
      steps: eventSteps,
      distance: eventSteps * 0.8,
      calories: eventSteps * 0.04,
    );
  });

  // ---------------------------------------------------------------------------
  // fallback periodic UI update
  // ---------------------------------------------------------------------------
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    final raw = prefs.getInt("last_raw") ?? 0;
    await updateNotif(raw);

    service.invoke("update", {
      "steps": raw,
      "total": prefs.getInt("total_steps") ?? 0,
      "event": activeEvent != null ? activeEvent!["name"] : "No event",
    });
  });

  service.on('stopService').listen((event) async {
    await pedSub?.cancel();
    service.stopSelf();
  });
}

// ---------------------------------------------------------------------------
// UI — HOME SCREEN
// ---------------------------------------------------------------------------

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

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
    _loadSavedTotals();
    listenUpdates();
  }

  Future<void> _loadSavedTotals() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      totalSteps = (prefs.getInt("total_steps") ?? 0).toString();
      rawSteps = (prefs.getInt("last_raw") ?? 0).toString();
    });
  }

  void listenUpdates() {
    FlutterBackgroundService().on("steps_update").listen((data) {
      if (data == null) return;
      setState(() {
        rawSteps = data["raw_steps"].toString();
        totalSteps = data["total_steps"].toString();
      });
    });

    FlutterBackgroundService().on("update").listen((data) {
      if (data == null) return;
      setState(() {
        eventName = data["event"] ?? "No event";
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
            Text("Raw Steps", style: TextStyle(fontSize: 22)),
            Text(rawSteps, style: TextStyle(fontSize: 36)),
            SizedBox(height: 20),

            Text("TOTAL Steps", style: TextStyle(fontSize: 22)),
            Text(totalSteps,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
            SizedBox(height: 30),

            Text("Active Event", style: TextStyle(fontSize: 22)),
            Text(eventName,
                style: TextStyle(fontSize: 28, color: Colors.blue)),
            SizedBox(height: 40),

            ElevatedButton(
              child: const Text("Show Events"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EventsListScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
