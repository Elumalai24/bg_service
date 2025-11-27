import 'package:get/get.dart';
import '../ui/screens/splash_screen.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/signup_screen.dart';
import '../ui/screens/home_screen.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.login, page: () => LoginScreen()),
    GetPage(name: AppRoutes.signup, page: () => SignupScreen()),
    GetPage(name: AppRoutes.home, page: () => const HomeScreen()),
  ];
}
