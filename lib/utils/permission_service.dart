import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  static Future<bool> requestAllPermissions() async {
    bool granted = true;

    // 1️⃣ Notification Permission (Android 13+)
    if (Platform.isAndroid) {
      final notif = await Permission.notification.status;
      if (!notif.isGranted) {
        final res = await Permission.notification.request();
        if (!res.isGranted) granted = false;
      }
    }

    // 2️⃣ Activity Recognition (Steps)
    final activityPerm = await Permission.activityRecognition.status;
    if (!activityPerm.isGranted) {
      final res = await Permission.activityRecognition.request();
      if (!res.isGranted) granted = false;
    }

    // 3️⃣ Ignore Battery Optimization (recommended)
    final batteryOpt = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryOpt.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
      // This can be denied by user; still allow app to run.
    }

    return granted;
  }
}
