class UserModel {
  final String id;
  final String fullName;
  final String? icNumber;
  final String? phoneNumber;
  final String? email;
  final String? districtZone;
  final String role;
  final String? accountStatus;

  UserModel({
    required this.id,
    required this.fullName,
    this.icNumber,
    this.phoneNumber,
    this.email,
    this.districtZone,
    required this.role,
    this.accountStatus,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      icNumber: json['ic_number'] as String?,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
      districtZone: json['district_zone'] as String?,
      role: json['role'] as String? ?? 'peronda',
      accountStatus: json['account_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'ic_number': icNumber,
      'phone_number': phoneNumber,
      'email': email,
      'district_zone': districtZone,
      'role': role,
      'account_status': accountStatus,
    };
  }
}
