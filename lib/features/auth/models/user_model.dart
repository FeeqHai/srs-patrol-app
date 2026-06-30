/// The three values of the `users.account_status` ENUM column in `srs_db`.
///
/// Wire values are the lowercase strings stored in the database / exchanged
/// with the PHP API. The legacy alias `'approved'` (treated as `active`) is
/// tolerated on read so we don't break against older rows.
enum AccountStatus {
  pending,
  active,
  inactive;

  /// Parse a raw value coming from the API. Returns `null` for null/blank
  /// input so callers can fall back to a sensible default (registration
  /// defaults to `pending`).
  static AccountStatus? fromWire(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    switch (raw.trim().toLowerCase()) {
      case 'active':
      case 'approved':
        return AccountStatus.active;
      case 'pending':
        return AccountStatus.pending;
      case 'inactive':
        return AccountStatus.inactive;
      default:
        return null;
    }
  }

  /// The canonical string the backend expects in `update_user.php`.
  String get wireValue => name;
}

class UserModel {
  final String id;
  final String fullName;
  final String? icNumber;
  final String? phoneNumber;
  final String? email;
  final String? profileImageUrl;
  final String? profileImagePath;
  final String? districtZone;
  final String? stateId;
  final String? districtId;
  final String? zoneId;
  final String? stateName;
  final String? districtName;
  final String? zoneName;
  final String? squadName;
  final String role;
  final String? accountStatus;
  final bool mustChangePassword;

  UserModel({
    required this.id,
    required this.fullName,
    this.icNumber,
    this.phoneNumber,
    this.email,
    this.profileImageUrl,
    this.profileImagePath,
    this.districtZone,
    this.stateId,
    this.districtId,
    this.zoneId,
    this.stateName,
    this.districtName,
    this.zoneName,
    this.squadName,
    required this.role,
    this.accountStatus,
    this.mustChangePassword = false,
  });

  /// Typed view of [accountStatus]. Falls back to `pending` when the value
  /// is missing/unrecognised, mirroring the registration default.
  AccountStatus get accountStatusEnum =>
      AccountStatus.fromWire(accountStatus) ?? AccountStatus.pending;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      icNumber: json['ic_number'] as String?,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
      profileImageUrl:
          (json['profile_image_url'] ?? json['profileImageUrl']) as String?,
      profileImagePath: json['profile_image_path'] as String?,
      districtZone: json['district_zone'] as String?,
      stateId: json['state_id'] as String?,
      districtId: json['district_id'] as String?,
      zoneId: json['zone_id'] as String?,
      stateName: json['state_name'] as String?,
      districtName: json['district_name'] as String?,
      zoneName: json['zone_name'] as String?,
      squadName: json['squad_name'] as String?,
      role: json['role'] as String? ?? 'peronda',
      // `account_status` is the canonical key; legacy `get_patrollers.php`
      // responses once used `status`, so tolerate both on read.
      accountStatus: (json['account_status'] ?? json['status']) as String?,
      mustChangePassword: _parseBool(json['must_change_password']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'ic_number': icNumber,
      'phone_number': phoneNumber,
      'email': email,
      'profile_image_url': profileImageUrl,
      'profileImageUrl': profileImageUrl,
      'profile_image_path': profileImagePath,
      'district_zone': districtZone,
      'state_id': stateId,
      'district_id': districtId,
      'zone_id': zoneId,
      'state_name': stateName,
      'district_name': districtName,
      'zone_name': zoneName,
      'squad_name': squadName,
      'role': role,
      'account_status': accountStatus,
      'must_change_password': mustChangePassword,
    };
  }

  String? get effectiveProfileImageUrl => profileImageUrl ?? profileImagePath;

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' ||
          normalized == 'true' ||
          normalized == 'yes' ||
          normalized == 'y';
    }
    return false;
  }

  UserModel copyWith({
    String? id,
    String? fullName,
    String? icNumber,
    String? phoneNumber,
    String? email,
    String? profileImageUrl,
    String? profileImagePath,
    String? districtZone,
    String? stateId,
    String? districtId,
    String? zoneId,
    String? stateName,
    String? districtName,
    String? zoneName,
    String? squadName,
    String? role,
    String? accountStatus,
    bool? mustChangePassword,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      icNumber: icNumber ?? this.icNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      districtZone: districtZone ?? this.districtZone,
      stateId: stateId ?? this.stateId,
      districtId: districtId ?? this.districtId,
      zoneId: zoneId ?? this.zoneId,
      stateName: stateName ?? this.stateName,
      districtName: districtName ?? this.districtName,
      zoneName: zoneName ?? this.zoneName,
      squadName: squadName ?? this.squadName,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }
}
