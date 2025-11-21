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

  /// Call from main.dart before runApp()
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground',
      'My Foreground Service',
      description: 'Used for pedometer tracking',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

    // Initialize notification plugin (needed for foreground mode)
    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_bg_service_small'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Create Android channel
    await notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'Pedometer Service',
        initialNotificationContent: 'Starting...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  // iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList("log") ?? [];
    logs.add("iOS BG: ${DateTime.now()}");
    await prefs.setStringList("log", logs);

    return true;
  }

  // ANDROID / iOS FOREGROUND BACKGROUND SERVICE ENTRY
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // Ensure DB is ready
    try {
      await DBHelper.instance.init();
    } catch (e) {
      print("[BG] DB Init Error: $e");
    }

    final prefs = await SharedPreferences.getInstance();
    final notifications = FlutterLocalNotificationsPlugin();

    // State Variables
    Map<String, dynamic>? activeEvent;
    int? eventStartSteps;

    // -------------------------------
    // HELPERS
    // -------------------------------

    Future<Map<String, dynamic>?> getActiveEvent() async {
      try {
        final now = DateTime.now().toIso8601String();
        final events = await DBHelper.instance.getEvents();

        for (var e in events) {
          if (now.compareTo(e["startDateTime"]) >= 0 &&
              now.compareTo(e["endDateTime"]) <= 0) {
            return e;
          }
        }
      } catch (e) {
        print("[BG] ActiveEvent Error: $e");
      }
      return null;
    }

    Future<void> updateNotification(int steps, String status) async {
      if (service is AndroidServiceInstance) {
        final android = AndroidNotificationDetails(
          'my_foreground',
          'My Foreground Service',
          icon: 'ic_bg_service_small',
          ongoing: true,
          importance: Importance.low,
        );

        await notifications.show(
          888,
          "Steps: $steps",
          status,
          NotificationDetails(android: android),
        );

        service.setForegroundNotificationInfo(
          title: "Steps: $steps",
          content: status,
        );
      }
    }

    // -------------------------------
    // STEP LISTENER
    // -------------------------------

    StreamSubscription<StepCount>? stepListener;
    StreamSubscription<PedestrianStatus>? statusListener;

    try {
      // Pedestrian Status
      statusListener =
          Pedometer.pedestrianStatusStream.listen((PedestrianStatus status) {
            prefs.setString("ped_status", status.status);
          });

      // MAIN STEP HANDLER
      stepListener = Pedometer.stepCountStream.listen((StepCount event) async {
        final rawSteps = event.steps;

        // Save raw steps
        prefs.setInt("current_steps_snapshot", rawSteps);

        // --------------------------------
        // Calculate TOTAL steps
        // --------------------------------
        int last = prefs.getInt("last_raw") ?? rawSteps;
        int inc = rawSteps - last;
        if (inc < 0) inc = 0;

        int total = prefs.getInt("total_steps") ?? 0;
        total += inc;

        prefs.setInt("last_raw", rawSteps);
        prefs.setInt("total_steps", total);

        // --------------------------------
        // Update notification
        // --------------------------------
        await updateNotification(rawSteps,
            activeEvent != null ? "Event: ${activeEvent!['name']}" : "No event");

        // --------------------------------
        // Event logic
        // --------------------------------

        activeEvent ??= await getActiveEvent();
        if (activeEvent == null) return;

        int eventId = activeEvent!["id"];

        final prevStats =
        await DBHelper.instance.getEventStats("user1", eventId);

        if (eventStartSteps == null) {
          if (prevStats != null) {
            eventStartSteps = rawSteps - (prevStats["steps"] as int);
          } else {
            eventStartSteps = rawSteps;
          }
          prefs.setInt("event_start_steps_$eventId", eventStartSteps!);
        }

        int eventSteps = rawSteps - eventStartSteps!;
        if (eventSteps < 0) eventSteps = 0;

        double distance = eventSteps * 0.8;
        double calories = eventSteps * 0.04;

        try {
          await DBHelper.instance.updateEventStatsAbsolute(
            userId: "user1",
            eventId: eventId,
            steps: eventSteps,
            distance: distance,
            calories: calories,
          );
        } catch (e) {
          print("[BG] DB Update Failed: $e");
        }

        prefs.setInt("last_step_count", rawSteps);

        // SEND TO UI
        service.invoke("steps_update", {
          "raw_steps": rawSteps,
          "total_steps": total,
          "event": activeEvent!["name"],
        });
      });
    } catch (e) {
      print("[BG] Step Listener Error: $e");
    }

    // -------------------------------
    // PERIODIC NOTIFICATION REFRESH
    // -------------------------------
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      int steps = prefs.getInt("current_steps_snapshot") ?? 0;

      activeEvent = await getActiveEvent();

      await updateNotification(
          steps, activeEvent != null ? "Event: ${activeEvent!['name']}" : "No event");

      service.invoke("update", {
        "current_date": DateTime.now().toIso8601String(),
        "steps": steps,
        "total": prefs.getInt("total_steps") ?? 0,
        "event": activeEvent != null ? activeEvent!["name"] : "",
      });
    });

    // -------------------------------
    // STOP HANDLER
    // -------------------------------
    service.on("stopService").listen((event) async {
      await stepListener?.cancel();
      await statusListener?.cancel();
      service.stopSelf();
    });
  }
}
