// lib/models/event_model.dart

class EventModel {
  final int id;
  final String eventName;

  final DateTime eventDate;
  final DateTime eventFromDate;
  final DateTime eventToDate;

  final String eventFromTime; // HH:mm
  final String eventToTime; // HH:mm

  final String eventLocation;
  final String eventDesc;
  final String? eventStyle;
  final String eventType;
  final String status;

  final DateTime createdAt;
  final DateTime updatedAt;

  final String eventVenueType;
  final String eventBanner;

  final String eventGoal;
  final String eventGoalType;

  final String eventCompletionMedal;
  final String eventPrizeDesc;
  final String client;

  final int eventDurationMinutes;

  EventModel({
    required this.id,
    required this.eventName,
    required this.eventDate,
    required this.eventFromDate,
    required this.eventToDate,
    required this.eventFromTime,
    required this.eventToTime,
    required this.eventLocation,
    required this.eventDesc,
    required this.eventStyle,
    required this.eventType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.eventVenueType,
    required this.eventBanner,
    required this.eventGoal,
    required this.eventGoalType,
    required this.eventCompletionMedal,
    required this.eventPrizeDesc,
    required this.client,
    required this.eventDurationMinutes,
  });

  /// Create models from API JSON (dynamic map)
  factory EventModel.fromApi(Map<String, dynamic> json) {
    return EventModel(
      id: _parseInt(json['id']),
      eventName: json['event_name']?.toString() ?? '',
      eventDate: DateTime.parse(json['event_date'].toString()),
      eventFromDate: DateTime.parse(json['event_from_date'].toString()),
      eventToDate: DateTime.parse(json['event_to_date'].toString()),
      eventFromTime: json['event_from_time']?.toString() ?? '00:00',
      eventToTime: json['event_to_time']?.toString() ?? '00:00',
      eventLocation: json['event_location']?.toString() ?? '',
      eventDesc: json['event_desc']?.toString() ?? '',
      eventStyle: json['event_style']?.toString(),
      eventType: json['event_type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
      eventVenueType: json['event_venue_type']?.toString() ?? '',
      eventBanner: json['event_banner']?.toString() ?? '',
      eventGoal: json['event_goal']?.toString() ?? '',
      eventGoalType: json['event_goal_type']?.toString() ?? '',
      eventCompletionMedal: json['event_completion_medal']?.toString() ?? '',
      eventPrizeDesc: json['event_prize_desc']?.toString() ?? '',
      client: json['client']?.toString() ?? '',
      eventDurationMinutes:
      int.tryParse(json['event_duration_minutes']?.toString() ?? '') ?? 0,
    );
  }

  /// Create models from DB map (same shape as toMap). Use this when reading from SQLite.
  factory EventModel.fromDb(Map<String, dynamic> m) {
    return EventModel(
      id: _parseInt(m['id']),
      eventName: m['event_name']?.toString() ?? '',
      eventDate: DateTime.parse(m['event_date'].toString()),
      eventFromDate: DateTime.parse(m['event_from_date'].toString()),
      eventToDate: DateTime.parse(m['event_to_date'].toString()),
      eventFromTime: m['event_from_time']?.toString() ?? '00:00',
      eventToTime: m['event_to_time']?.toString() ?? '00:00',
      eventLocation: m['event_location']?.toString() ?? '',
      eventDesc: m['event_desc']?.toString() ?? '',
      eventStyle: m['event_style']?.toString(),
      eventType: m['event_type']?.toString() ?? '',
      status: m['status']?.toString() ?? '',
      createdAt: DateTime.parse(m['created_at'].toString()),
      updatedAt: DateTime.parse(m['updated_at'].toString()),
      eventVenueType: m['event_venue_type']?.toString() ?? '',
      eventBanner: m['event_banner']?.toString() ?? '',
      eventGoal: m['event_goal']?.toString() ?? '',
      eventGoalType: m['event_goal_type']?.toString() ?? '',
      eventCompletionMedal: m['event_completion_medal']?.toString() ?? '',
      eventPrizeDesc: m['event_prize_desc']?.toString() ?? '',
      client: m['client']?.toString() ?? '',
      eventDurationMinutes: _parseInt(m['event_duration_minutes']),
    );
  }

  /// Alias expected by DBHelper: fromMap -> fromDb
  factory EventModel.fromMap(Map<String, dynamic> m) => EventModel.fromDb(m);

  /// Convert to map for SQLite insert/update
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_name': eventName,
      'event_date': _dateOnlyString(eventDate),
      'event_from_date': _dateOnlyString(eventFromDate),
      'event_to_date': _dateOnlyString(eventToDate),
      'event_from_time': eventFromTime,
      'event_to_time': eventToTime,
      'event_location': eventLocation,
      'event_desc': eventDesc,
      'event_style': eventStyle,
      'event_type': eventType,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'event_venue_type': eventVenueType,
      'event_banner': eventBanner,
      'event_goal': eventGoal,
      'event_goal_type': eventGoalType,
      'event_completion_medal': eventCompletionMedal,
      'event_prize_desc': eventPrizeDesc,
      'client': client,
      'event_duration_minutes': eventDurationMinutes,
    };
  }

  // -----------------------
  // Helpers & utils
  // -----------------------

  /// Combine eventDate + eventFromTime (HH:mm) to a DateTime
  DateTime slotStartDateTimeForDate(DateTime date) {
    final parts = eventFromTime.split(':');
    final hh = int.tryParse(parts[0]) ?? 0;
    final mm = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return DateTime(date.year, date.month, date.day, hh, mm);
  }

  /// Combine eventDate + eventToTime (HH:mm) to a DateTime
  DateTime slotEndDateTimeForDate(DateTime date) {
    final parts = eventToTime.split(':');
    final hh = int.tryParse(parts[0]) ?? 0;
    final mm = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return DateTime(date.year, date.month, date.day, hh, mm);
  }

  /// If eventDate contains only date portion (yyyy-MM-dd), return DateTime date-only string
  static String _dateOnlyString(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  String toString() {
    return 'EventModel{id: $id, name: $eventName, date: ${eventDate.toIso8601String()}}';
  }
}
