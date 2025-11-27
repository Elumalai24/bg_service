import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../models/client_model.dart';

class AuthRepository {
  final ApiService _api;
  AuthRepository(this._api);

  Future<ApiResponse<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) => _api.post(
    AppConstants.loginEndpoint,
    data: {'email': email, 'password': password},
    fromJson: (data) => data as Map<String, dynamic>,
  );

  Future<ApiResponse<Map<String, dynamic>>> signup({
    required String name,
    required String email,
    required String password,
    required String mobileNumber,
    required int clientId,
  }) => _api.post(
    AppConstants.signupEndpoint,
    data: {
      'name': name,
      'email': email,
      'mobile_number': mobileNumber,
      'password': password,
      'password_confirmation': password,
      'client_id': clientId,
    },
    fromJson: (data) => data as Map<String, dynamic>,
  );

  Future<ApiResponse<List<ClientModel>>> getClients() async {
    final response = await _api.get<List<dynamic>>(
      AppConstants.clientsEndpoint,
      fromJson: (data) => List<dynamic>.from(data),
    );

    if (response.success && response.data != null) {
      final clients = response.data!
          .map((json) => ClientModel.fromJson(json as Map<String, dynamic>))
          .where((c) => c.isActive)
          .toList();
      return ApiResponse.success(clients);
    }
    return ApiResponse.error(response.message);
  }

  Future<ApiResponse<Map<String, dynamic>>> getProfile(String userId) => _api.get(
    '${AppConstants.profileEndpoint}/$userId',
    fromJson: (data) => data as Map<String, dynamic>,
  );
}
