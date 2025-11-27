import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import 'package:get_storage/get_storage.dart';
import '../constants/app_constants.dart';

class ApiService extends getx.GetxService {
  late Dio _dio;
  static ApiService get instance => getx.Get.find<ApiService>();

  @override
  void onInit() {
    super.onInit();
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = GetStorage().read(AppConstants.tokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ));
  }

  Future<ApiResponse<T>> get<T>(String endpoint, {T Function(dynamic)? fromJson}) async {
    try {
      final response = await _dio.get(endpoint);
      return ApiResponse.success(fromJson != null ? fromJson(response.data) : response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  Future<ApiResponse<T>> post<T>(String endpoint, {dynamic data, T Function(dynamic)? fromJson}) async {
    try {
      final response = await _dio.post(endpoint, data: data);
      return ApiResponse.success(fromJson != null ? fromJson(response.data) : response.data);
    } on DioException catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  String _getErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout - please try again';
      case DioExceptionType.connectionError:
        return 'No internet connection';
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 401) return 'Invalid email or password';
        if (e.response?.statusCode == 422) return 'Invalid data - please check your input';
        return 'Server error - please try again';
      default:
        return 'Something went wrong';
    }
  }
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String message;

  ApiResponse._({required this.success, this.data, required this.message});

  factory ApiResponse.success(T data) => ApiResponse._(success: true, data: data, message: 'Success');
  factory ApiResponse.error(String message) => ApiResponse._(success: false, message: message);
}
