/// Profile model for nested profile data
class UserProfile {
  final int id;
  final String userId;
  final String name;
  final String mobileNumber;
  final String whatsappNumber;
  final String dateOfBirth;
  final String gender;
  final String address;
  final String? profileType;

  UserProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.mobileNumber,
    required this.whatsappNumber,
    required this.dateOfBirth,
    required this.gender,
    required this.address,
    this.profileType,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id']?.toInt() ?? 0,
    userId: json['user_id']?.toString() ?? '',
    name: json['name'] ?? '',
    mobileNumber: json['mobile_number'] ?? '',
    whatsappNumber: json['whatsapp_number'] ?? '',
    dateOfBirth: json['date_of_birth'] ?? '',
    gender: json['gender'] ?? '',
    address: json['address'] ?? '',
    profileType: json['profile_type'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'mobile_number': mobileNumber,
    'whatsapp_number': whatsappNumber,
    'date_of_birth': dateOfBirth,
    'gender': gender,
    'address': address,
    'profile_type': profileType,
  };
}

/// User model for managing user data
class UserModel {
  final int id;
  final String name;
  final String email;
  final String? clientId;
  final UserProfile? profile;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.clientId,
    this.profile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id']?.toInt() ?? 0,
    name: json['name'] ?? '',
    email: json['email'] ?? '',
    clientId: json['client_id']?.toString(),
    profile: json['profile'] != null ? UserProfile.fromJson(json['profile']) : null,
  );

  factory UserModel.fromLogin({required String id, required String email}) => UserModel(
    id: int.tryParse(id) ?? 0,
    name: '',
    email: email,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'client_id': clientId,
    'profile': profile?.toJson(),
  };

  /// Get display name (from profile if available, otherwise from user)
  String get displayName => profile?.name.isNotEmpty == true ? profile!.name : name;

  /// Get mobile number from profile
  String? get mobileNumber => profile?.mobileNumber;

  /// Get whatsapp number from profile
  String? get whatsappNumber => profile?.whatsappNumber;

  /// Get date of birth from profile
  String? get dateOfBirth => profile?.dateOfBirth;

  /// Get gender from profile
  String? get gender => profile?.gender;

  /// Get address from profile
  String? get address => profile?.address;
}
