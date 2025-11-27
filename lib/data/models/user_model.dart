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

  String get displayName => profile?.name.isNotEmpty == true ? profile!.name : name;
}

class UserProfile {
  final int id;
  final String name;
  final String mobileNumber;
  final String gender;
  final String dateOfBirth;

  UserProfile({
    required this.id,
    required this.name,
    required this.mobileNumber,
    required this.gender,
    required this.dateOfBirth,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id']?.toInt() ?? 0,
    name: json['name'] ?? '',
    mobileNumber: json['mobile_number'] ?? '',
    gender: json['gender'] ?? '',
    dateOfBirth: json['date_of_birth'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mobile_number': mobileNumber,
    'gender': gender,
    'date_of_birth': dateOfBirth,
  };
}
