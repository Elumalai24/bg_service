import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../core/constants/app_constants.dart';
import '../data/models/user_model.dart';
import '../data/models/client_model.dart';
import '../data/repositories/auth_repository.dart';
import '../routes/app_routes.dart';

class AuthController extends GetxController {
  final AuthRepository _authRepo;
  final _storage = GetStorage();

  AuthController(this._authRepo);

  // Form controllers
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  // Form keys
  final loginFormKey = GlobalKey<FormState>();
  final signupFormKey = GlobalKey<FormState>();

  // Observables
  final isLoading = false.obs;
  final obscurePassword = true.obs;
  final isLoadingClients = false.obs;
  final acceptedTerms = false.obs;
  final clients = <ClientModel>[].obs;
  final selectedClient = Rxn<ClientModel>();
  final currentUser = Rxn<UserModel>();

  @override
  void onInit() {
    super.onInit();
    _loadUserFromStorage();
  }

  /// Load user from storage on app start
  void _loadUserFromStorage() {
    final userData = _storage.read(AppConstants.userKey);
    if (userData != null) {
      try {
        currentUser.value = UserModel.fromJson(Map<String, dynamic>.from(userData));
      } catch (e) {
        debugPrint('Error loading user from storage: $e');
      }
    }
  }

  /// Refresh user profile from API
  Future<void> refreshProfile() async {
    final userId = _storage.read(AppConstants.userIdKey)?.toString();
    if (userId == null) return;

    final profileRes = await _authRepo.getProfile(userId);
    if (profileRes.success && profileRes.data != null) {
      final user = UserModel.fromJson(profileRes.data!);
      await _storage.write(AppConstants.userKey, user.toJson());
      currentUser.value = user;
    }
  }

  @override
  void onClose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    super.onClose();
  }

  // Validation
  String? validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email is required';
    if (!GetUtils.isEmail(v)) return 'Enter a valid email';
    return null;
  }

  String? validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? validateRequired(String? v, String field) {
    if (v == null || v.isEmpty) return '$field is required';
    return null;
  }

  // Actions
  void togglePasswordVisibility() => obscurePassword.toggle();
  void toggleTerms(bool? v) => acceptedTerms.value = v ?? false;

  Future<void> loadClients() async {
    isLoadingClients.value = true;
    final response = await _authRepo.getClients();
    if (response.success && response.data != null) {
      clients.value = response.data!;
      if (clients.isNotEmpty) selectedClient.value = clients.first;
    }
    isLoadingClients.value = false;
  }

  void selectClient(ClientModel client) => selectedClient.value = client;

  Future<void> login() async {
    if (!loginFormKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final response = await _authRepo.login(
        email: emailCtrl.text,
        password: passwordCtrl.text,
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        final token = data['token'];
        final userId = data['id']?.toString();

        if (token != null && userId != null) {
          await _storage.write(AppConstants.tokenKey, token);
          await _storage.write(AppConstants.userIdKey, userId);

          // Update Background Service with new auth info
          FlutterBackgroundService().invoke("update_auth", {
            "token": token,
            "user_id": userId,
          });

          // Try to fetch full profile
          final profileRes = await _authRepo.getProfile(userId);
          if (profileRes.success && profileRes.data != null) {
            final user = UserModel.fromJson(profileRes.data!);
            await _storage.write(AppConstants.userKey, user.toJson());
            currentUser.value = user;
          } else {
            final user = UserModel.fromLogin(id: userId, email: emailCtrl.text);
            await _storage.write(AppConstants.userKey, user.toJson());
            currentUser.value = user;
          }

          _clearLoginForm();
          _showSuccess('Login successful!');
          Get.offAllNamed(AppRoutes.home);
        }
      } else {
        _showError(response.message);
      }
    } catch (e) {
      _showError('Something went wrong');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signup() async {
    if (!signupFormKey.currentState!.validate()) return;

    if (selectedClient.value == null) {
      _showError('Please select a company');
      return;
    }

    if (!acceptedTerms.value) {
      _showError('You must accept the Terms & Conditions');
      return;
    }

    isLoading.value = true;
    try {
      final response = await _authRepo.signup(
        name: nameCtrl.text,
        email: emailCtrl.text,
        password: passwordCtrl.text,
        mobileNumber: phoneCtrl.text,
        clientId: selectedClient.value!.id,
      );

      if (response.success) {
        _clearSignupForm();
        _showSuccess('Account created! Please login.');
        Get.offAllNamed(AppRoutes.login);
      } else {
        _showError(response.message);
      }
    } catch (e) {
      _showError('Something went wrong');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await _storage.remove(AppConstants.tokenKey);
    await _storage.remove(AppConstants.userIdKey);
    await _storage.remove(AppConstants.userKey);
    currentUser.value = null;
    _clearLoginForm();
    Get.offAllNamed(AppRoutes.login);
  }

  void goToSignup() {
    if (clients.isEmpty) loadClients();
    Get.toNamed(AppRoutes.signup);
  }

  void goToLogin() => Get.back();

  void _clearLoginForm() {
    emailCtrl.clear();
    passwordCtrl.clear();
  }

  void _clearSignupForm() {
    nameCtrl.clear();
    emailCtrl.clear();
    passwordCtrl.clear();
    phoneCtrl.clear();
    selectedClient.value = clients.isNotEmpty ? clients.first : null;
    acceptedTerms.value = false;
  }

  void _showSuccess(String msg) => Get.snackbar(
    'Success', msg,
    backgroundColor: AppConstants.primaryColor,
    colorText: Colors.white,
    snackPosition: SnackPosition.TOP,
  );

  void _showError(String msg) => Get.snackbar(
    'Error', msg,
    backgroundColor: Colors.red,
    colorText: Colors.white,
    snackPosition: SnackPosition.TOP,
  );
}
