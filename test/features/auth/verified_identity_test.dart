import 'package:flutter_test/flutter_test.dart';
import 'package:srs_app/features/auth/models/verified_identity.dart';

void main() {
  test('MyKad extraction token expires at the server expiry time', () {
    final expiresAt = DateTime.utc(2026, 9, 2, 10, 15);
    final identity = VerifiedIdentity(
      fullName: 'TOKEN TEST USER',
      icNumber: '900101000000',
      verificationToken: 'a' * 64,
      verifiedAt: DateTime.utc(2026, 9, 2, 10),
      expiresAt: expiresAt,
    );

    expect(
      identity.isExpiredAt(expiresAt.subtract(const Duration(seconds: 1))),
      isFalse,
    );
    expect(identity.isExpiredAt(expiresAt), isTrue);
    expect(
      identity.isExpiredAt(expiresAt.add(const Duration(seconds: 1))),
      isTrue,
    );
  });
}
