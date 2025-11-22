// lib/services/background_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_helper.dart';

class BackgroundService {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  /// ---------------------------------------------------------------
  /// INITIALIZE SERVICE
  /// ---------------------------------------------------------------
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground',
      'MY FOREGROUND SERVICE',
      description: 'Shows step counter & event status',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_bg_service_small'),
        iOS: DarwinInitializationSettings(),
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
        initialNotificationTitle: "Starting…",
        initialNotificationContent: "Initializing",
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: onIosBackground,
        autoStart: true,
      ),
    );
  }

  /// ---------------------------------------------------------------
  /// iOS BACKGROUND
  /// ---------------------------------------------------------------
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList("ios_log") ?? [];
    logs.add("iOS BG Triggered: ${DateTime.now()}");
    await prefs.setStringList("ios_log", logs);
    return true;
  }

  /// ---------------------------------------------------------------
  /// ANDROID BACKGROUND ENTRYPOINT
  /// ---------------------------------------------------------------
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    print("🔥 BACKGROUND SERVICE STARTED");

    await DBHelper.instance.init();
    final prefs = await SharedPreferences.getInstance();
    final notifications = FlutterLocalNotificationsPlugin();

    // ---------------------------------------------------------------
    // TOTAL STEPS VARIABLES
    // ---------------------------------------------------------------
    int lastRaw = prefs.getInt("last_raw") ?? -1;
    int totalSteps = prefs.getInt("total_steps") ?? 0;

    // ---------------------------------------------------------------
    // EVENT LOGIC
    // ---------------------------------------------------------------
    int? eventStartSteps;
    Map<String, dynamic>? activeEvent;
    int? lastEventId;

    // PROGRAM START DATE (5-DAY WINDOW)
    DateTime programStart =
    DateTime.parse(prefs.getString("program_start_date")!);
    DateTime programEnd = programStart.add(const Duration(days: 5));

    // ---------------------------------------------------------------
    // TIME JUMP DETECTION
    // ---------------------------------------------------------------
    int lastSystemTime =
        prefs.getInt("last_system_time") ?? DateTime.now().millisecondsSinceEpoch;

    Future<void> handleTimeJump() async {
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;
      final diff = (nowMs - lastSystemTime).abs();

      if (diff > 60 * 1000) {
        print("⏱ TIME JUMP DETECTED: ${diff ~/ 1000}s");

        lastEventId = null;
        eventStartSteps = null;
        prefs.remove("last_step_count");
      }

      prefs.setInt("last_system_time", nowMs);
      lastSystemTime = nowMs;
    }

    // ---------------------------------------------------------------
    // 2 EVENTS DAILY
    // ---------------------------------------------------------------
    Future<Map<String, dynamic>?> getCurrentDailyEvent() async {
      final now = DateTime.now();

      // STOP COUNTING IF > 5 DAYS
      if (now.isAfter(programEnd)) {
        print("⛔ PROGRAM EXPIRED — 5 days completed.");
        return null;
      }

      // Morning today 10:00–10:05
      final morning = {
        "id": 1,
        "name": "Morning Event",
        "start": DateTime(now.year, now.month, now.day, 10, 0),
        "end": DateTime(now.year, now.month, now.day, 10, 5),
      };

      // Evening today 18:00–18:05
      final evening = {
        "id": 2,
        "name": "Evening Event",
        "start": DateTime(now.year, now.month, now.day, 18, 0),
        "end": DateTime(now.year, now.month, now.day, 18, 5),
      };

      if (now.isAfter(morning["start"] as DateTime) &&
          now.isBefore(morning["end"] as DateTime)) {
        return morning;
      }

      if (now.isAfter(evening["start"] as DateTime) &&
          now.isBefore(evening["end"] as DateTime)) {
        return evening;
      }


      return null;
    }

    // ---------------------------------------------------------------
    // NOTIFICATION
    // ---------------------------------------------------------------
    Future<void> updateNotification(int raw, String eventName) async {
      if (service is AndroidServiceInstance) {
        await notifications.show(
          888,
          "Steps: $raw",
          eventName,
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
          content: eventName,
        );
      }
    }

    // ---------------------------------------------------------------
    // PEDOMETER STREAM
    // ---------------------------------------------------------------
    StreamSubscription<StepCount>? pedStream;

    pedStream = Pedometer.stepCountStream.listen((StepCount event) async {
      final raw = event.steps;
      final now = DateTime.now();

      await handleTimeJump();

      // ---------------- TOTAL STEPS ALWAYS COUNTED ----------------
      if (lastRaw == -1) lastRaw = raw;

      int inc = raw - lastRaw;
      if (inc < 0) inc = 0;

      totalSteps += inc;

      prefs.setInt("last_raw", raw);
      prefs.setInt("total_steps", totalSteps);

      lastRaw = raw;

      service.invoke("steps_update", {
        "raw_steps": raw,
        "total_steps": totalSteps,
      });

      // ---------------- EVENT STEP LOGIC ----------------
      final newEvent = await getCurrentDailyEvent();

      if (newEvent == null) {
        activeEvent = null;
        eventStartSteps = null;
        lastEventId = null;

        await updateNotification(raw, "No Active Event");
        return;
      }

      // EVENT SWITCH
      if (lastEventId != newEvent["id"]) {
        print("🔄 EVENT CHANGED → ${newEvent["name"]}");

        eventStartSteps = null;
        lastEventId = newEvent["id"];
        activeEvent = newEvent;
      }

      // BASELINE
      if (eventStartSteps == null) {
        final prevStats = await DBHelper.instance.getEventStats("user1", newEvent["id"]);

        if (prevStats != null) {
          eventStartSteps = raw - (prevStats["steps"] as int);
        } else {
          eventStartSteps = raw;
        }

        prefs.setInt("event_start_steps_${newEvent["id"]}", eventStartSteps!);
      }

      // EVENT STEPS
      int eventSteps = raw - eventStartSteps!;
      if (eventSteps < 0) eventSteps = 0;

      // SAVE ACCUMULATED STEPS
      await DBHelper.instance.updateEventStatsAccumulate(
        userId: "user1",
        eventId: newEvent["id"],
        steps: eventSteps,
        distance: eventSteps * 0.8,
        calories: eventSteps * 0.04,
      );

      await updateNotification(raw, newEvent["name"]);
    });

    // ---------------------------------------------------------------
    // PERIODIC SAFE UI UPDATE LOOP
    // ---------------------------------------------------------------
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      final raw = prefs.getInt("last_raw") ?? 0;

      final evt = await getCurrentDailyEvent();
      final name = evt != null ? evt["name"] : "No event";

      await updateNotification(raw, name);

      service.invoke("update", {
        "steps": raw,
        "total": prefs.getInt("total_steps") ?? 0,
        "event": name,
      });
    });
  }
}
