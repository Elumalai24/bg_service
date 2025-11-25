import 'dart:async';
import 'dart:ui';
import 'package:bg_service/utils/background_service.dart';
import 'package:bg_service/utils/permission_service.dart';
import 'package:bg_service/ui/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/db_helper.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Permissions
  final ok = await PermissionsService.requestAllPermissions();
  if (!ok) debugPrint("⚠ Some permissions NOT granted!");

  // DB + mock events
  await DBHelper.instance.init();
  await DBHelper.instance.insertMockEventsIfEmpty();

  // Program start date
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey('program_start_date')) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    await prefs.setString('program_start_date', start.toIso8601String());
  }

  // Start background service
  await BackgroundService.initialize();

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomeScreen(),
  ));
}


