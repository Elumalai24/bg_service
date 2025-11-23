import 'dart:async';
import 'dart:ui';

import 'package:bg_service/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_helper.dart';
import 'events_screen.dart';
import 'services/background_service.dart';  // <-- FIXED

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
    home: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

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
    _loadInitial();
    _listenUpdates();
  }

  Future<void> _loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      rawSteps = (prefs.getInt('last_raw') ?? 0).toString();
      totalSteps = (prefs.getInt('total_steps') ?? 0).toString();
    });
  }

  void _listenUpdates() {
    FlutterBackgroundService().on('steps_update').listen((data) {
      if (data == null) return;

      setState(() {
        rawSteps = data['raw_steps'].toString();
        totalSteps = data['total_steps'].toString();
      });
    });

    FlutterBackgroundService().on('update').listen((data) {
      if (data == null) return;

      setState(() {
        eventName = (data['event'] ?? "No event").toString();
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
            const Text("Raw Steps", style: TextStyle(fontSize: 22)),
            Text(rawSteps, style: const TextStyle(fontSize: 38)),

            const SizedBox(height: 20),

            const Text("Total Steps", style: TextStyle(fontSize: 22)),
            Text(
              totalSteps,
              style:
              const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            const Text("Active Event", style: TextStyle(fontSize: 22)),
            Text(eventName,
                style: const TextStyle(fontSize: 26, color: Colors.blue)),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EventsListScreen()),
                );
              },
              child: const Text("Show Events"),
            ),
          ],
        ),
      ),
    );
  }
}
