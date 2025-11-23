// lib/models/steps_post_model.dart

class StepsPostModel {
  final int userId;
  final int eventId;
  final String activityDate;
  final int stepsCount;
  final double distanceKm;
  final double calories;

  StepsPostModel({
    required this.userId,
    required this.eventId,
    required this.activityDate,
    required this.stepsCount,
    required this.distanceKm,
    required this.calories,
  });

  Map<String, dynamic> toJson() {
    return {
      "user_id": userId,
      "event_id": eventId,
      "activity_date": activityDate,
      "steps_count": stepsCount,
      "distance_km": distanceKm,
      "calories": calories,
    };
  }
}
