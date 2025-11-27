import 'package:get/get.dart';
import '../core/services/api_service.dart';
import '../data/repositories/auth_repository.dart';
import '../controllers/auth_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Services
    Get.put(ApiService(), permanent: true);

    // Repositories
    Get.lazyPut(() => AuthRepository(Get.find<ApiService>()), fenix: true);

    // Controllers
    Get.lazyPut(() => AuthController(Get.find<AuthRepository>()), fenix: true);
  }
}
