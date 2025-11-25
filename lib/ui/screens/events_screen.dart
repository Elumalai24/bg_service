// lib/events_screen.dart
import 'package:flutter/material.dart';
import '../../utils/db_helper.dart';
import 'event_details_screen.dart';
import '../../models/event_model.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({Key? key}) : super(key: key);

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  late Future<List<EventModel>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = DBHelper.instance.getEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events List')),
      body: FutureBuilder<List<EventModel>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data!;
          if (events.isEmpty) {
            return const Center(child: Text('No events found'));
          }

          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final e = events[index];

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
          );
        },
      ),
    );
  }
}
