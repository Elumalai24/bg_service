import 'package:bg_service/utils/background_service.dart';
import 'package:bg_service/utils/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/db_helper.dart';
import 'bindings/initial_binding.dart';
import 'routes/app_routes.dart';
import 'routes/app_pages.dart';
import 'core/constants/app_constants.dart';

Future<void> main() async {
  print("🎬 App starting...");
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize GetStorage
  await GetStorage.init();
  print("✓ GetStorage initialized");

  // Permissions
  final ok = await PermissionsService.requestAllPermissions();
  if (!ok) debugPrint("Some permissions NOT granted!");
  print("✓ Permissions checked");

  // DB + mock events
  await DBHelper.instance.init();
  await DBHelper.instance.insertMockEventsIfEmpty();
  print("✓ Database initialized");

  // Program start date
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey('program_start_date')) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    await prefs.setString('program_start_date', start.toIso8601String());
  }
  print("✓ Program start date set");

  // Start background service
  await BackgroundService.initialize();
  print("✓ Background service initialized");

  print("🚀 Launching app UI...");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: ThemeData(
        primaryColor: AppConstants.primaryColor,
        colorScheme: ColorScheme.fromSeed(seedColor: AppConstants.primaryColor),
        useMaterial3: true,
      ),
      initialBinding: InitialBinding(),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
    );
  }
}


