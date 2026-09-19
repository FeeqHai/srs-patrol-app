class VerifiedIdentity {
  const VerifiedIdentity({
    required this.fullName,
    required this.icNumber,
    required this.verificationToken,
    required this.verifiedAt,
    required this.expiresAt,
  });

  final String fullName;
  final String icNumber;
  final String verificationToken;
  final DateTime verifiedAt;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime time) => !expiresAt.isAfter(time);
}

class VerificationSession {
  const VerificationSession({
    required this.id,
    required this.token,
    required this.expiresAt,
  });

  final String id;
  final String token;
  final DateTime expiresAt;
}
