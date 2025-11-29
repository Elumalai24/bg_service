import 'dart:async';
import 'dart:math';
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

    // Get current user ID from storage (set during login)
    String currentUserId = prefs.getString('current_user_id') ?? 'user1';

    // Event completion tracking
    EventModel? lastActiveEvent;

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

    // Helper: Get today's date as YYYY-MM-DD string
    String getTodayDateString() {
      final now = DateTime.now();
      return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
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

    // Handle event completion and sync to API
    Future<void> handleEventCompletion(EventModel completedEvent) async {
      try {
        print("🔔 handleEventCompletion called for event ${completedEvent.id}");
        final today = getTodayDateString();
        print("📅 Today's date: $today");

        // Check if already synced
        final alreadySynced = await DBHelper.instance.isEventSynced(
          userId: currentUserId,
          eventId: completedEvent.id,
          activityDate: today,
        );

        if (alreadySynced) {
          print("✓ Event ${completedEvent.id} already synced for $today");
          return;
        }

        print("🔍 Fetching daily stats for event ${completedEvent.id}...");
        // Get today's stats for this event
        final dailyStats = await DBHelper.instance.getDailyStatsForEvent(
          currentUserId,
          completedEvent.id,
        );

        print("📊 Found ${dailyStats.length} daily records for event ${completedEvent.id}");

        // Find today's record
        final todayStats = dailyStats.where((s) => s['date'] == today).toList();

        if (todayStats.isEmpty) {
          print("⚠ No stats for event ${completedEvent.id} on $today");
          return;
        }

        final stats = todayStats.first;
        final steps = stats['steps'] as int? ?? 0;
        final distance = (stats['distance'] as num?)?.toDouble() ?? 0.0;
        final calories = (stats['calories'] as num?)?.toDouble() ?? 0.0;

        print("📤 Syncing event ${completedEvent.id}: $steps steps on $today");

        // Post to API with random delay to distribute server load
        try {
          // Generate random delay between 0-15 minutes
          final random = Random();
          final randomMinutes = random.nextInt(2); // 0 to 1 minutes for testing
          final scheduledTime = DateTime.now().add(Duration(minutes: randomMinutes));

          print("💾 Calling addPendingSync for event ${completedEvent.id}...");
          await DBHelper.instance.addPendingSync(
            userId: currentUserId,
            eventId: completedEvent.id,
            activityDate: today,
            steps: steps,
            distance: distance,
            calories: calories,
            scheduledSyncTime: scheduledTime,
          );

          print("✓ Event ${completedEvent.id} queued for sync in $randomMinutes minutes (at ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')})");
        } catch (e) {
          print("❌ Failed to queue sync for event ${completedEvent.id}: $e");
        }
      } catch (e) {
        print("❌ Failed to handle event completion ${completedEvent.id}: $e");
      }
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

      // Debug: Log current event status
      if (newEvent != null) {
        // Only log every 60 seconds to avoid spam
        if (DateTime.now().second == 0) {
          print("📍 Active event: ${newEvent.id} (${newEvent.eventName})");
        }
      }

      // DETECT EVENT COMPLETION
      if (lastActiveEvent != null && newEvent?.id != lastActiveEvent?.id) {
        // Previous event has ended (either no event now, or different event)
        print("🏁 Event ${lastActiveEvent!.id} (${lastActiveEvent!.eventName}) completed, triggering sync...");
        await handleEventCompletion(lastActiveEvent!);
      }

      // Update last active event
      if (lastActiveEvent?.id != newEvent?.id) {
        if (newEvent != null) {
          print("🎯 Event started: ${newEvent.id} (${newEvent.eventName})");
        } else if (lastActiveEvent != null) {
          print("⏸️ No active event (previous: ${lastActiveEvent!.id})");
        }
      }
      lastActiveEvent = newEvent;

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
          userId: currentUserId,
          eventId: newEvent.id,
          steps: inc,
          distance: inc * 0.8,
          calories: inc * 0.04,
        );

        await DBHelper.instance.updateDailyEventStats(
          userId: currentUserId,
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
