class ClientModel {
  final int id;
  final String name;
  final String status;

  ClientModel({required this.id, required this.name, required this.status});

  factory ClientModel.fromJson(Map<String, dynamic> json) => ClientModel(
    id: json['id'] ?? 0,
    name: json['name'] ?? '',
    status: json['status'] ?? '0',
  );

  bool get isActive => status == '1';

  @override
  bool operator ==(Object other) => other is ClientModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
