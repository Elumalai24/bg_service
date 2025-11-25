import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_helper.dart';
import '../models/event_model.dart';

@pragma('vm:entry-point')
class BackgroundService {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  // ---------------------------------------------------------------
  // INITIALIZER
  // ---------------------------------------------------------------
  @pragma('vm:entry-point')
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground',
      'MY FOREGROUND SERVICE',
      description: 'Step counter service',
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
        onStart: BackgroundService.onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: "Starting…",
        initialNotificationContent: "Initializing",
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: BackgroundService.onStart,
        onBackground: BackgroundService.onIosBackground,
      ),
    );
  }

  // ---------------------------------------------------------------
  // iOS BG
  // ---------------------------------------------------------------
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList("ios_log") ?? [];
    logs.add("iOS BG: ${DateTime.now()}");
    await prefs.setStringList("ios_log", logs);
    return true;
  }

  // ---------------------------------------------------------------
  // ANDROID BG ENTRYPOINT
  // ---------------------------------------------------------------
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    await DBHelper.instance.init();

    final prefs = await SharedPreferences.getInstance();
    final notifications = FlutterLocalNotificationsPlugin();

    int lastRaw = prefs.getInt("last_raw") ?? -1;
    int totalSteps = prefs.getInt("total_steps") ?? 0;

    int? eventStartSteps;
    EventModel? activeEvent;
    int? lastEventId;

    // Program 5-day validity
    DateTime programStart =
    DateTime.parse(prefs.getString("program_start_date")!);
    DateTime programEnd = programStart.add(const Duration(days: 5));

    int lastSystemTime =
        prefs.getInt("last_system_time") ?? DateTime.now().millisecondsSinceEpoch;

    Future<void> checkTimeJump() async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final diff = (nowMs - lastSystemTime).abs();
      if (diff > 60000) {
        lastEventId = null;
        eventStartSteps = null;
      }
      lastSystemTime = nowMs;
      await prefs.setInt("last_system_time", nowMs);
    }

    // Active event from DB
    Future<EventModel?> getActiveEvent() async {
      final now = DateTime.now();
      if (now.isAfter(programEnd)) return null;

      final events = await DBHelper.instance.getEvents();
      for (final e in events) {
        final start = e.slotStartDateTimeForDate(now);
        final end = e.slotEndDateTimeForDate(now);

        if (!now.isBefore(start) && !now.isAfter(end)) return e;
      }
      return null;
    }

    Future<void> updateNotif(int raw, String name) async {
      if (service is AndroidServiceInstance) {
        await notifications.show(
          888,
          "Steps: $raw",
          name,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'MY FOREGROUND SERVICE',
              ongoing: true,
              icon: 'ic_bg_service_small',
            ),
          ),
        );

        service.setForegroundNotificationInfo(
          title: "Steps: $raw",
          content: name,
        );
      }
    }

    // PEDOMETER STREAM
    final pedStream = Pedometer.stepCountStream.listen((ev) async {
      final raw = ev.steps;

      await checkTimeJump();

      // TOTAL STEPS
      if (lastRaw == -1) lastRaw = raw;
      int inc = raw - lastRaw;
      if (inc < 0) inc = 0;

      totalSteps += inc;

      lastRaw = raw;
      prefs.setInt("last_raw", raw);
      prefs.setInt("total_steps", totalSteps);

      service.invoke("steps_update", {
        "raw_steps": raw,
        "total_steps": totalSteps,
      });

      await updateNotif(raw, "Updating…");

      // EVENT LOGIC
      final newEvent = await getActiveEvent();
      if (newEvent == null) {
        activeEvent = null;
        eventStartSteps = null;
        lastEventId = null;
        return;
      }

      // SWITCH EVENT
      if (lastEventId != newEvent.id) {
        activeEvent = newEvent;
        eventStartSteps = null;
        lastEventId = newEvent.id;
      }

      // BASELINE
      if (eventStartSteps == null) {
        eventStartSteps = raw;
        prefs.setInt("event_start_steps_${newEvent.id}", eventStartSteps!);
      }

      // Calculate delta since last update (or start)
      // We need to track the last processed raw value for the event to get a true delta
      // However, the existing logic uses a baseline `eventStartSteps` and calculates total `eventSteps` from it.
      // To get a delta for *this* update, we can compare with the previous `eventSteps`.
      // BUT, the user wants to split day wise.
      // The safest way to handle "daily" splits without complex state management is to just add the *increment* (delta) to the DB.
      // The `inc` variable calculated earlier (lines 165-166) represents the new steps since the last stream event.
      // We should use THAT `inc` for the event as well, provided the event is active.

      // Let's use `inc` (calculated at line 165) which is the delta since the last Pedometer event.
      // If we are in an event, this `inc` belongs to that event.

      if (inc > 0) {
        await DBHelper.instance.updateEventStatsAccumulate(
          userId: "user1",
          eventId: newEvent.id,
          steps: inc,
          distance: inc * 0.8,
          calories: inc * 0.04,
        );

        await DBHelper.instance.updateDailyEventStats(
          userId: "user1",
          eventId: newEvent.id,
          steps: inc,
          distance: inc * 0.8,
          calories: inc * 0.04,
        );
      }

      await updateNotif(raw, newEvent.eventName);
    });

    // PERIODIC UI UPDATE
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      await checkTimeJump();

      final raw = prefs.getInt("last_raw") ?? 0;
      final evt = await getActiveEvent();

      await updateNotif(raw, evt?.eventName ?? "No event");

      service.invoke("update", {
        "steps": raw,
        "total": prefs.getInt("total_steps") ?? 0,
        "event": evt?.eventName ?? "No event",
      });
    });
  }
}
