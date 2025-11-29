import 'package:get/get.dart';
import '../core/services/api_service.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/events_repository.dart';
import '../controllers/auth_controller.dart';
import '../controllers/events_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Services
    Get.put(ApiService(), permanent: true);

    // Repositories
    Get.lazyPut(() => AuthRepository(Get.find<ApiService>()), fenix: true);
    Get.lazyPut(() => EventsRepository(Get.find<ApiService>()), fenix: true);

    // Controllers
    Get.lazyPut(() => AuthController(Get.find<AuthRepository>()), fenix: true);
    Get.lazyPut(() => EventsController(Get.find<EventsRepository>()), fenix: true);
  }
}
