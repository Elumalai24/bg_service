import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'events_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
