import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_helper.dart';
import '../models/event_model.dart';
import '../core/constants/app_constants.dart';

class BackgroundSyncHelper {
  /// Queue a sync with random delay (0-30 minutes)
  static Future<void> queueEventSync({
    required EventModel event,
    required SharedPreferences prefs,
  }) async {
    try {
      print("📋 Queuing sync for event: ${event.eventName}");

      // Get user ID from SharedPreferences
      String? userIdStr = prefs.getString("bg_auth_user_id");

      // Fallback to GetStorage if Prefs empty
      if (userIdStr == null) {
        final storage = GetStorage();
        userIdStr = storage.read(AppConstants.userIdKey)?.toString();
      }

      if (userIdStr == null) {
        print("❌ Cannot queue sync: Missing user ID");
        return;
      }

      final today = DateTime.now();
      final dateStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      // Add to pending syncs with random delay (0-5 minutes)
      await DBHelper.instance.addPendingSync(
        userId: userIdStr,
        eventId: event.id,
        date: dateStr,
      );

      print("✅ Sync queued successfully for event ${event.id}");
    } catch (e) {
      print("❌ Error queuing sync: $e");
    }
  }

  /// Process all pending syncs that are due
  static Future<void> processPendingSyncs({
    required SharedPreferences prefs,
    required FlutterLocalNotificationsPlugin notifications,
  }) async {
    try {
      final dueSyncs = await DBHelper.instance.getDuePendingSyncs();

      if (dueSyncs.isEmpty) return;

      print("🔄 Processing ${dueSyncs.length} due syncs...");

      for (final sync in dueSyncs) {
        final syncId = sync['id'] as int;
        final userId = sync['userId'] as String;
        final eventId = sync['eventId'] as int;
        final date = sync['date'] as String;

        try {
          // Get auth token
          String? token = prefs.getString("bg_auth_token");
          if (token == null) {
            final storage = GetStorage();
            token = storage.read(AppConstants.tokenKey)?.toString();
          }

          if (token == null) {
            print("❌ Cannot sync: Missing auth token");
            await DBHelper.instance.markSyncFailed(syncId);
            continue;
          }

          // Get stats for the date
          final db = await DBHelper.instance.getDailyStatsForEvent(userId, eventId);
          final dayStat = db.firstWhere(
            (element) => element['date'] == date,
            orElse: () => {},
          );

          if (dayStat.isEmpty || (dayStat['steps'] as int? ?? 0) == 0) {
            print("⚠️ No steps to sync for event $eventId on $date");
            await DBHelper.instance.markSyncCompleted(syncId);
            continue;
          }

          final steps = dayStat['steps'] as int;
          final distance = dayStat['distance'] as double;
          final calories = dayStat['calories'] as double;
          final distanceKm = distance / 1000;

          print("📤 Syncing: $steps steps, ${distanceKm.toStringAsFixed(2)} km, $calories kcal");

          final dio = Dio();
          dio.options.headers['Authorization'] = 'Bearer $token';
          dio.options.headers['Accept'] = 'application/json';
          dio.options.headers['Content-Type'] = 'application/json';

          final userIdInt = int.tryParse(userId) ?? 0;

          final response = await dio.post(
            '${AppConstants.baseUrl}${AppConstants.movesEndpoint}',
            data: {
              "user_id": userIdInt,
              "event_id": eventId,
              "activity_date": date,
              "steps_count": steps,
              "distance_km": distanceKm,
              "calories": calories
            },
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            print("✅ Sync successful for event $eventId!");
            await _showAlert(notifications, "Sync Success", "Uploaded steps for event $eventId");

            await DBHelper.instance.markSyncCompleted(syncId);
            await DBHelper.instance.logSync(
              userId: userId,
              eventId: eventId,
              date: date,
              status: "SUCCESS",
              message: "Steps: $steps",
            );
          } else {
            print("❌ Sync failed: ${response.statusCode}");
            await _showAlert(notifications, "Sync Failed", "Error ${response.statusCode}");

            await DBHelper.instance.markSyncFailed(syncId);
            await DBHelper.instance.logSync(
              userId: userId,
              eventId: eventId,
              date: date,
              status: "FAILED",
              message: "Error: ${response.statusCode}",
            );
          }
        } catch (e) {
          print("❌ Error processing sync $syncId: $e");
          await DBHelper.instance.markSyncFailed(syncId);
          await DBHelper.instance.logSync(
            userId: userId,
            eventId: eventId,
            date: date,
            status: "ERROR",
            message: e.toString(),
          );
        }
      }
    } catch (e) {
      print("❌ Error processing pending syncs: $e");
    }
  }

  /// Immediate sync for ongoing events (App Open)
  /// Does NOT add to pending_syncs table (Status remains unchanged)
  static Future<void> syncImmediate({
    required EventModel event,
    required SharedPreferences prefs,
  }) async {
    try {
      print("🚀 Attempting immediate sync for ongoing event: ${event.eventName}");

      // Get user ID
      String? userIdStr = prefs.getString("bg_auth_user_id");
      if (userIdStr == null) {
        final storage = GetStorage();
        userIdStr = storage.read(AppConstants.userIdKey)?.toString();
      }

      if (userIdStr == null) {
        print("❌ Cannot sync: Missing user ID");
        return;
      }

      final today = DateTime.now();
      final dateStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      // CHECK: "check it is not sync"
      // If we already have a pending/completed sync record for today, it means the event ended (or force sync).
      // In that case, we respect that flow and do NOT do this intermediate sync.
      final hasSync = await DBHelper.instance.hasPendingSync(userIdStr, event.id, dateStr);
      if (hasSync) {
        print("⚠️ Sync already pending/completed for today. Skipping intermediate sync.");
        return;
      }

      // Get auth token
      String? token = prefs.getString("bg_auth_token");
      if (token == null) {
        final storage = GetStorage();
        token = storage.read(AppConstants.tokenKey)?.toString();
      }

      if (token == null) {
        print("❌ Cannot sync: Missing auth token");
        return;
      }

      // Get stats
      final db = await DBHelper.instance.getDailyStatsForEvent(userIdStr, event.id);
      final dayStat = db.firstWhere(
        (element) => element['date'] == dateStr,
        orElse: () => {},
      );

      if (dayStat.isEmpty || (dayStat['steps'] as int? ?? 0) == 0) {
        print("⚠️ No steps to sync for event ${event.id}");
        return;
      }

      final steps = dayStat['steps'] as int;
      final distance = dayStat['distance'] as double;
      final calories = dayStat['calories'] as double;
      final distanceKm = distance / 1000;

      print("📤 Immediate Syncing: $steps steps, ${distanceKm.toStringAsFixed(2)} km");

      final dio = Dio();
      dio.options.headers['Authorization'] = 'Bearer $token';
      dio.options.headers['Accept'] = 'application/json';
      dio.options.headers['Content-Type'] = 'application/json';

      final userIdInt = int.tryParse(userIdStr) ?? 0;

      final response = await dio.post(
        '${AppConstants.baseUrl}${AppConstants.movesEndpoint}',
        data: {
          "user_id": userIdInt,
          "event_id": event.id,
          "activity_date": dateStr,
          "steps_count": steps,
          "distance_km": distanceKm,
          "calories": calories
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Immediate sync successful!");
        // We do NOT update pending_syncs status.
        // We only log to history for debugging.
        await DBHelper.instance.logSync(
          userId: userIdStr,
          eventId: event.id,
          date: dateStr,
          status: "INTERMEDIATE_SUCCESS",
          message: "App Open Sync: $steps",
        );
      } else {
        print("❌ Immediate sync failed: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error in immediate sync: $e");
    }
  }

  static Future<void> _showAlert(
    FlutterLocalNotificationsPlugin notifications,
    String title,
    String body,
  ) async {
    await notifications.show(
      999, // Distinct ID for alerts
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sync_alerts',
          'Sync Alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_bg_service_small',
        ),
      ),
    );
  }
}
