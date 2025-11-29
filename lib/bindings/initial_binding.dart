import 'package:get/get.dart';
import '../core/services/api_service.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/events_repository.dart';
import '../data/repositories/steps_repository.dart';
import '../controllers/auth_controller.dart';
import '../controllers/events_controller.dart';
import '../controllers/sync_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    print("🔧 Setting up dependencies...");
    
    // Services
    Get.put(ApiService(), permanent: true);
    print("✓ ApiService registered");

    // Repositories
    Get.lazyPut(() => AuthRepository(Get.find<ApiService>()), fenix: true);
    Get.lazyPut(() => EventsRepository(Get.find<ApiService>()), fenix: true);
    Get.put(StepsRepository(Get.find<ApiService>()), permanent: true); // Eager init for SyncController
    print("✓ Repositories registered");

    // Controllers
    Get.lazyPut(() => AuthController(Get.find<AuthRepository>()), fenix: true);
    Get.lazyPut(() => EventsController(Get.find<EventsRepository>()), fenix: true);
    Get.put(SyncController(Get.find<StepsRepository>()), permanent: true); // Auto-start
    print("✓ Controllers registered (SyncController will auto-start)");
  }
}
