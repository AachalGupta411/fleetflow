class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.licenseNumber,
    required this.licenseExpiry,
    required this.status,
    required this.isActive,
    this.phone,
  });

  final String id;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String licenseNumber;
  final String licenseExpiry;
  final String status;
  final bool isActive;

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      licenseNumber: json['license_number'] as String,
      licenseExpiry: json['license_expiry'] as String,
      status: json['status'] as String,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
