class UserModel {
  final String id;
  final String username;
  final String role; // "user" | "admin"
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.createdAt,
    this.role = 'user',
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      role: (json['role'] as String?) ?? 'user',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
