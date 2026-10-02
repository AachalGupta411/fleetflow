class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.phone,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final bool isActive;

  String get roleLabel {
    switch (role) {
      case 'FLEET_MANAGER':
        return 'Fleet Manager';
      case 'ADMIN':
        return 'Admin';
      case 'DRIVER':
        return 'Driver';
      case 'CUSTOMER':
        return 'Customer';
      default:
        return role;
    }
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'is_active': isActive,
    };
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AppUser user;
}
