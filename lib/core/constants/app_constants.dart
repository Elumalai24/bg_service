import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'FestPlay';
  static const String appVersion = '1.0.0';

  // Colors
  static const Color primaryColor = Color(0xFF030E43);
  static const Color secondaryColor = Color(0xFF1E2A5E);
  static const Color accentColor = Color(0xFF4A90E2);

  // API
  static const String baseUrl = 'https://fitex.co.in/api';
  static const String loginEndpoint = '/login';
  static const String signupEndpoint = '/register';
  static const String clientsEndpoint = '/clients';
  static const String profileEndpoint = '/profile';

  // Legal URLs
  static const String termsUrl = 'http://fitex.co.in/terms_and_conditions';
  static const String privacyUrl = 'http://fitex.co.in/privacy_policy';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String userKey = 'user_data';

  // UI
  static const double padding = 16.0;
  static const double radius = 12.0;
}
