import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';

import 'db_helper.dart';
import '../models/event_model.dart';
import '../core/constants/app_constants.dart';

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

    // Init DB and Storage
    await DBHelper.instance.init();
    await GetStorage.init();

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

    // SYNC LOGIC
    Future<void> syncEventData(EventModel event) async {
      try {
        print("🚀 Syncing data for event: ${event.eventName}");

        // Get user ID from SharedPreferences (more reliable across isolates)
        String? token = prefs.getString("bg_auth_token");
        String? userIdStr = prefs.getString("bg_auth_user_id");

        // Fallback to GetStorage if Prefs empty (in case it worked for some reason)
        if (token == null || userIdStr == null) {
          final storage = GetStorage();
          userIdStr = storage.read(AppConstants.userIdKey)?.toString();
          token = storage.read(AppConstants.tokenKey)?.toString();
        }

        if (userIdStr == null || token == null) {
          print("❌ Cannot sync: Missing user ID or token. Make sure to login and open the app once.");
          return;
        }

        final userId = int.tryParse(userIdStr.toString()) ?? 0;
        
        // Get stats for today
        final today = DateTime.now();
        final dateStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
        
        print("🔍 Sync Debug: UserID=$userIdStr ($userId), EventID=${event.id}, Date=$dateStr");

        // Using raw query to get specific day stats
        final db = await DBHelper.instance.getDailyStatsForEvent(userIdStr.toString(), event.id);
        print("🔍 Sync Debug: Daily Stats Found: ${db.length} records");
        if (db.isNotEmpty) {
           print("🔍 Sync Debug: Record 0: ${db.first}");
        } else {
           // Debug: Check if ANY stats exist for this user
           final allStats = await DBHelper.instance.getAllEventStats(userIdStr.toString());
           print("🔍 Sync Debug: Total Event Stats for user: ${allStats.length} records");
           if (allStats.isNotEmpty) print("🔍 Sync Debug: First stat: ${allStats.first}");
        }

        final dayStat = db.firstWhere(
          (element) => element['date'] == dateStr, 
          orElse: () => {},
        );

        if (dayStat.isEmpty || (dayStat['steps'] as int? ?? 0) == 0) {
          print("⚠️ No steps to sync for this event today");
          return;
        }

        final steps = dayStat['steps'] as int;
        final distance = dayStat['distance'] as double;
        final calories = dayStat['calories'] as double;

        print("📤 Posting moves: $steps steps, $distance km, $calories kcal");

        final dio = Dio();
        dio.options.headers['Authorization'] = 'Bearer $token';
        dio.options.headers['Accept'] = 'application/json';
        dio.options.headers['Content-Type'] = 'application/json';

        final response = await dio.post(
          '${AppConstants.baseUrl}${AppConstants.movesEndpoint}',
          data: {
            "user_id": userId,
            "event_id": event.id,
            "activity_date": dateStr,
            "steps_count": steps,
            "distance_km": distance,
            "calories": calories
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          print("✅ Sync successful!");
        } else {
          print("❌ Sync failed: ${response.statusCode} - ${response.statusMessage}");
        }

      } catch (e) {
        print("❌ Error syncing event data: $e");
      }
    }

    // LISTEN FOR AUTH UPDATE
    service.on("update_auth").listen((event) async {
      if (event != null) {
        print("🔐 Auth info updated in background service");
        final token = event['token'] as String?;
        final userId = event['user_id'] as String?;

        if (token != null && userId != null) {
           await prefs.setString("bg_auth_token", token);
           await prefs.setString("bg_auth_user_id", userId);
        }
      }
    });




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
      
      // Check if event ended (active -> null)
      if (newEvent == null) {
        if (activeEvent != null) {
           // Event just ended! Sync.
           await syncEventData(activeEvent!);
        }
        activeEvent = null;
        eventStartSteps = null;
        lastEventId = null;
        return;
      }

      // SWITCH EVENT (active -> different active)
      if (lastEventId != newEvent.id) {
        if (activeEvent != null) {
           // Previous event ended! Sync.
           await syncEventData(activeEvent!);
        }
        activeEvent = newEvent;
        eventStartSteps = null;
        lastEventId = newEvent.id;
      }

      // BASELINE
      if (eventStartSteps == null) {
        eventStartSteps = raw;
        prefs.setInt("event_start_steps_${newEvent.id}", eventStartSteps!);
      }

      // Let's use `inc` (calculated at line 165) which is the delta since the last Pedometer event.
      // If we are in an event, this `inc` belongs to that event.

      if (inc > 0) {
        // Get user ID from SharedPreferences (consistent with sync logic)
        String userId = prefs.getString("bg_auth_user_id") ?? "user1";
        
        // Fallback to GetStorage if Prefs empty
        if (userId == "user1") {
           final storage = GetStorage();
           userId = storage.read(AppConstants.userIdKey)?.toString() ?? "user1";
        }

        await DBHelper.instance.updateEventStatsAccumulate(
          userId: userId,
          eventId: newEvent.id,
          steps: inc,
          distance: inc * 0.8,
          calories: inc * 0.04,
        );

        await DBHelper.instance.updateDailyEventStats(
          userId: userId,
          eventId: newEvent.id,
          steps: inc,
          distance: inc * 0.8,
          calories: inc * 0.04,
        );
      }

      await updateNotif(raw, newEvent.eventName);
    });

    // LISTEN FOR FORCE SYNC (FOR TESTING)
    service.on("force_sync").listen((event) async {
      print("🔄 Force sync requested from UI");
      if (activeEvent != null) {
        await syncEventData(activeEvent!);
      } else {
        print("⚠️ Cannot force sync: No active event found");
        // Try to sync the last known event if available, or just log
        if (lastEventId != null) {
             print("Trying to sync last event ID: $lastEventId");
             // We'd need to fetch the event object again or keep it. 
             // For now, just warning is enough.
        }
      }
    });

    // PERIODIC UI UPDATE & EVENT CHECK
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      await checkTimeJump();

      final raw = prefs.getInt("last_raw") ?? 0;
      final evt = await getActiveEvent();

      // Check for event end via timer (in case no steps are taken but time expires)
      if (evt == null && activeEvent != null) {
         // Event ended (time expired)! Sync.
         final eventToSync = activeEvent!;
         activeEvent = null; // Update state IMMEDIATELY to prevent re-entry
         lastEventId = null;
         await syncEventData(eventToSync);
      } else if (evt != null && activeEvent != null && evt.id != activeEvent!.id) {
         // Event switched! Sync previous.
         final eventToSync = activeEvent!;
         activeEvent = evt; // Update state IMMEDIATELY to prevent re-entry
         lastEventId = evt.id;
         await syncEventData(eventToSync);
      } else if (evt != null && activeEvent == null) {
         // New event started
         activeEvent = evt;
         lastEventId = evt.id;
      }

      await updateNotif(raw, evt?.eventName ?? "No event");

      service.invoke("update", {
        "steps": raw,
        "total": prefs.getInt("total_steps") ?? 0,
        "event": evt?.eventName ?? "No event",
      });
    });
  }
}
