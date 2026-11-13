class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
  });

  final String id;
  final String email;
  final String fullName;
  final bool isActive;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
