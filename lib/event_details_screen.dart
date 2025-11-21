import 'package:flutter/material.dart';
import 'db_helper.dart';


class EventStatsScreen extends StatefulWidget {
  final int eventId;
  final String eventName;


  const EventStatsScreen({Key? key, required this.eventId, required this.eventName}) : super(key: key);


  @override
  State<EventStatsScreen> createState() => _EventStatsScreenState();
}


class _EventStatsScreenState extends State<EventStatsScreen> {
  Map<String, dynamic>? stats;
  bool loading = true;


  @override
  void initState() {
    super.initState();
    loadStats();
  }


  Future<void> loadStats() async {
    final data = await DBHelper.instance.getEventStats('user1', widget.eventId);
    setState(() {
      stats = data;
      loading = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.eventName} Stats')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : stats == null
          ? const Center(child: Text('No stats available for this event'))
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Steps: ${stats!['steps']}', style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 10),
            Text('Distance: ${stats!['distance']} m', style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 10),
            Text('Calories: ${stats!['calories']} kcal', style: const TextStyle(fontSize: 22)),
          ],
        ),
      ),
    );
  }
}