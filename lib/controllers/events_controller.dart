import 'package:get/get.dart';
import '../data/repositories/events_repository.dart';
import '../models/event_model.dart';

class EventsController extends GetxController {
  final EventsRepository _eventsRepo;

  EventsController(this._eventsRepo);

  // Observables
  final events = <EventModel>[].obs;
  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadEvents();
  }

  /// Load events - try API first, fallback to local database
  Future<void> loadEvents() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      // Try to fetch from API and sync to database
      final response = await _eventsRepo.fetchAndSyncEvents();

      if (response.success && response.data != null) {
        events.value = response.data!;
      } else {
        // API failed, load from local database
        final localEvents = await _eventsRepo.getLocalEvents();
        events.value = localEvents;

        if (localEvents.isEmpty) {
          errorMessage.value = response.message;
        }
      }
    } catch (e) {
      // On error, try to load from local database
      try {
        final localEvents = await _eventsRepo.getLocalEvents();
        events.value = localEvents;

        if (localEvents.isEmpty) {
          errorMessage.value = 'Failed to load events';
        }
      } catch (dbError) {
        errorMessage.value = 'Failed to load events: $dbError';
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh events (for pull-to-refresh)
  Future<void> refreshEvents() async {
    isRefreshing.value = true;
    errorMessage.value = '';

    try {
      final response = await _eventsRepo.fetchAndSyncEvents();

      if (response.success && response.data != null) {
        events.value = response.data!;
      } else {
        // Keep existing events on refresh failure
        errorMessage.value = response.message;
      }
    } catch (e) {
      errorMessage.value = 'Failed to refresh events';
    } finally {
      isRefreshing.value = false;
    }
  }

  /// Get event by ID
  Future<EventModel?> getEventById(int id) async {
    return await _eventsRepo.getEventById(id);
  }
}
