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

  if (!ok) {
    print("⚠ Required permissions NOT granted!");
  }
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

  // Create notification channel (Android)
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

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Init DB inside isolate
  await DBHelper.instance.init();

  final FlutterLocalNotificationsPlugin notifications =
  FlutterLocalNotificationsPlugin();

  final prefs = await SharedPreferences.getInstance();

  int? eventStartSteps;
  Map<String, dynamic>? activeEvent;

  // ============================================================
  // 🔥 TOTAL STEPS VARIABLES
  // ============================================================
  int lastRaw = prefs.getInt("last_raw") ?? -1;
  int totalSteps = prefs.getInt("total_steps") ?? 0;

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
    } catch (e) {
      print("[BG] ActiveEvent lookup failed: $e");
    }
    return null;
  }

  Future<void> updateNotif(int steps) async {
    if (service is AndroidServiceInstance) {
      notifications.show(
        888,
        "Steps: $steps",
        activeEvent != null ? "Event: ${activeEvent!["name"]}" : "No active event",
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
        title: "Steps: $steps",
        content: activeEvent != null ? activeEvent!["name"] : "No active event",
      );
    }
  }

  StreamSubscription<StepCount>? pedSub;
  StreamSubscription<PedestrianStatus>? pedStatusSub;

  try {
    pedStatusSub = Pedometer.pedestrianStatusStream.listen((status) {
      prefs.setString("ped_status", status.status);
    });

    pedSub = Pedometer.stepCountStream.listen((StepCount event) async {
      final raw = event.steps;

      // ============================================================
      // 🔥 TOTAL STEPS FIX
      // ============================================================
      if (lastRaw == -1) {
        lastRaw = raw;
      }

      int inc = raw - lastRaw;
      if (inc < 0) inc = 0;

      totalSteps += inc;

      // save to prefs
      prefs.setInt("last_raw", raw);
      prefs.setInt("total_steps", totalSteps);

      lastRaw = raw;

      // send to UI
      service.invoke("steps_update", {
        "raw_steps": raw,
        "total_steps": totalSteps,
      });

      // Update notification
      await updateNotif(raw);

      // ============================================================
      // EVENT LOGIC
      // ============================================================
      activeEvent ??= await getActiveEvent();
      if (activeEvent == null) return;

      int eventId = activeEvent!["id"];

      final prevStats =
      await DBHelper.instance.getEventStats("user1", eventId);

      if (eventStartSteps == null) {
        if (prevStats != null) {
          eventStartSteps = raw - (prevStats['steps'] as int);
        } else {
          eventStartSteps = raw;
        }
        prefs.setInt("event_start_steps_$eventId", eventStartSteps!);
      }

      int eventSteps = raw - eventStartSteps!;
      if (eventSteps < 0) eventSteps = 0;

      double dist = eventSteps * 0.8;
      double cal = eventSteps * 0.04;

      await DBHelper.instance.updateEventStatsAbsolute(
        userId: "user1",
        eventId: eventId,
        steps: eventSteps,
        distance: dist,
        calories: cal,
      );
    });
  } catch (e) {
    print("[BG] Pedometer stream error: $e");
  }

  // periodic UI update & event refresh
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    int raw = prefs.getInt("current_steps_snapshot") ?? 0;
    await updateNotif(raw);

    service.invoke("update", {
      "steps": raw,
      "total": prefs.getInt("total_steps") ?? 0,
      "event": activeEvent != null ? activeEvent!["name"] : "No event",
    });
  });

  service.on('stopService').listen((event) async {
    await pedSub?.cancel();
    await pedStatusSub?.cancel();
    service.stopSelf();
  });
}

// ===================================================================
// ✅ UPDATED HOME SCREEN — SHOWS TOTAL STEPS + RAW STEPS + EVENT
// ===================================================================

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
    listenUpdates();
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
            Text(totalSteps, style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
            SizedBox(height: 30),

            Text("Active Event", style: TextStyle(fontSize: 22)),
            Text(eventName, style: TextStyle(fontSize: 28, color: Colors.blue)),

            SizedBox(height: 40),

            ElevatedButton(
              child: const Text("Show Events"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EventsListScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


class LogView extends StatefulWidget {
  const LogView({Key? key}) : super(key: key);

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late final Timer timer;
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      await sp.reload();
      logs = sp.getStringList('log') ?? [];
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs.elementAt(index);
        return Text(log);
      },
    );
  }
}