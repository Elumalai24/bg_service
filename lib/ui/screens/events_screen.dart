// lib/events_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/events_controller.dart';
import 'event_details_screen.dart';

class EventsListScreen extends StatelessWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EventsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events List'),
        actions: [
          Obx(() => controller.isLoading.value
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => controller.loadEvents(),
                )),
        ],
      ),
      body: Obx(() {
        // Show loading indicator on first load
        if (controller.isLoading.value && controller.events.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        // Show error if no events and there's an error message
        if (controller.events.isEmpty && controller.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => controller.loadEvents(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Show empty state
        if (controller.events.isEmpty) {
          return const Center(child: Text('No events found'));
        }

        // Show events list with pull-to-refresh
        return RefreshIndicator(
          onRefresh: () => controller.refreshEvents(),
          child: ListView.builder(
            itemCount: controller.events.length,
            itemBuilder: (context, index) {
              final e = controller.events[index];

              final subtitle =
                  'Start: ${e.eventFromDate.toIso8601String().split("T").first} ${e.eventFromTime}  •  End: ${e.eventToDate.toIso8601String().split("T").first} ${e.eventToTime}';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(
                    e.eventName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventStatsScreen(
                          eventId: e.id,
                          eventName: e.eventName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
