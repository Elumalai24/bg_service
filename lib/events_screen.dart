import 'package:flutter/material.dart';

import 'db_helper.dart';
import 'event_details_screen.dart';



class EventsListScreen extends StatefulWidget {
  const EventsListScreen({Key? key}) : super(key: key);


  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}


class _EventsListScreenState extends State<EventsListScreen> {
  late Future<List<Map<String, dynamic>>> _eventsFuture;


  @override
  void initState() {
    super.initState();
    _eventsFuture = DBHelper.instance.getEvents();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Events List')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
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


                    return Card(
                        child: ListTile(
                          title: Text(e['name']),
                          subtitle: Text(
                              'Start: ${e['startDateTime']} End: ${e['endDateTime']}',
                          ),

                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventStatsScreen(
                                  eventId: e['id'],
                                  eventName: e['name'],
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