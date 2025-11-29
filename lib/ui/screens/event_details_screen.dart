// lib/event_details_screen.dart

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/db_helper.dart';

class EventStatsScreen extends StatefulWidget {
  final int eventId;
  final String eventName;

  const EventStatsScreen({Key? key, required this.eventId, required this.eventName}) : super(key: key);

  @override
  State<EventStatsScreen> createState() => _EventStatsScreenState();
}

class _EventStatsScreenState extends State<EventStatsScreen> {
  Map<String, dynamic>? stats;
  List<Map<String, dynamic>> dailyStats = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<void> loadStats() async {
    // Get the actual logged-in user ID
    final storage = GetStorage();
    final userId = storage.read(AppConstants.userIdKey)?.toString() ?? 'user1';
    
    final event = await DBHelper.instance.getEventById(widget.eventId);
    final data = await DBHelper.instance.getEventStats(userId, widget.eventId);
    final daily = await DBHelper.instance.getDailyStatsForEvent(userId, widget.eventId);

    if (event == null) {
      setState(() {
        loading = false;
      });
      return;
    }

    // Create a map of existing stats for quick lookup
    final statsMap = {
      for (var item in daily) item['date']: item
    };

    List<Map<String, dynamic>> fullDailyStats = [];
    
    // Iterate from start date to end date
    DateTime current = event.eventFromDate;
    // Ensure we don't go past eventToDate. 
    // If eventToDate is "2025-12-10", we want to include it.
    // We'll strip time components just to be safe, though eventFromDate/ToDate should be date only from model.
    final end = DateTime(event.eventToDate.year, event.eventToDate.month, event.eventToDate.day);
    
    while (!current.isAfter(end)) {
      final dateStr = "${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}";
      
      if (statsMap.containsKey(dateStr)) {
        fullDailyStats.add(statsMap[dateStr]!);
      } else {
        // Add zero stats
        fullDailyStats.add({
          'date': dateStr,
          'steps': 0,
          'distance': 0.0,
          'calories': 0.0,
        });
      }
      
      current = current.add(const Duration(days: 1));
    }
    
    setState(() {
      stats = data;
      dailyStats = fullDailyStats;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.eventName} Stats')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TOTAL STATS
                  if (stats != null) ...[
                    const Text('Total Stats', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _buildStatRow('Steps', '${stats!['steps']}'),
                    _buildStatRow('Distance', '${(stats!['distance'] / 1000).toStringAsFixed(2)} km'),
                    _buildStatRow('Calories', '${stats!['calories'].toStringAsFixed(2)} kcal'),
                    const Divider(height: 40),
                  ] else
                    const Text('No stats available for this event'),

                  // DAILY STATS
                  if (dailyStats.isNotEmpty) ...[
                    const Text('Daily Breakdown', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: dailyStats.length,
                      itemBuilder: (context, index) {
                        final day = dailyStats[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(day['date']),
                            subtitle: Text(
                              'Steps: ${day['steps']} | Dist: ${(day['distance'] / 1000).toStringAsFixed(2)}km | Cal: ${day['calories'].toStringAsFixed(1)}',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
