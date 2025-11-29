import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../models/event_model.dart';
import '../../utils/db_helper.dart';

class EventsRepository {
  final ApiService _api;
  EventsRepository(this._api);

  /// Fetch events from API and sync to local database
  Future<ApiResponse<List<EventModel>>> fetchAndSyncEvents() async {
    try {
      final response = await _api.get<List<dynamic>>(
        AppConstants.eventsEndpoint,
        fromJson: (data) => List<dynamic>.from(data),
      );

      if (response.success && response.data != null) {
        // Parse events from API response
        final events = response.data!
            .map((json) => EventModel.fromApi(json as Map<String, dynamic>))
            .toList();

        // Clear old events and insert new ones
        await DBHelper.instance.clearAndInsertEvents(events);

        return ApiResponse.success(events);
      }

      return ApiResponse.error(response.message);
    } catch (e) {
      return ApiResponse.error('Failed to fetch events: $e');
    }
  }

  /// Get events from local database
  Future<List<EventModel>> getLocalEvents() async {
    return await DBHelper.instance.getEvents();
  }

  /// Get single event by ID from local database
  Future<EventModel?> getEventById(int id) async {
    return await DBHelper.instance.getEventById(id);
  }
}
