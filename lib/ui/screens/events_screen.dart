// lib/events_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/events_controller.dart';
import 'event_details_screen.dart';
import '../../models/event_model.dart';

class EventsListScreen extends StatelessWidget {
  const EventsListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EventsController(Get.find()));

    return Scaffold(
      appBar: AppBar(title: const Text('Events List')),
      body: Obx(() {
        // Show loading indicator on initial load
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
                  onPressed: controller.loadEvents,
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
          onRefresh: controller.refreshEvents,
          child: ListView.builder(
            itemCount: controller.events.length,
            itemBuilder: (context, index) {
              final e = controller.events[index];

              final subtitle =
                  'Start: ${e.eventFromDate.toIso8601String().split("T").first} ${e.eventFromTime}  •  End: ${e.eventToDate.toIso8601String().split("T").first} ${e.eventToTime}';

              return Card(
                child: ListTile(
                  title: Text(e.eventName),
                  subtitle: Text(subtitle),
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
