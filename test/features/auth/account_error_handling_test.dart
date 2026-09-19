import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:srs_app/features/auth/providers/auth_provider.dart';
import 'package:srs_app/features/auth/services/auth_service.dart';

Future<String?> _register({
  String phone = '+60 12-345 6789',
  String password = ' password ',
}) => AuthService().registerPatroller(
  fullName: 'TEST MEMBER',
  icNumber: '900101-04-5678',
  phoneNumber: phone,
  stateId: 'state',
  districtId: 'district',
  zoneId: 'zone',
  email: 'validation@example.invalid',
  password: password,
  verificationToken: 'test-token',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'registration normalizes numbers and preserves the exact password',
    () async {
      await http.runWithClient(
        () async {
          expect(await _register(), isNull);
        },
        () => MockClient((request) async {
          expect(request.bodyFields['phone_number'], '0123456789');
          expect(request.bodyFields['ic_number'], '900101045678');
          expect(request.bodyFields['password'], ' password ');
          return http.Response('{"status":"success"}', 200);
        }),
      );
    },
  );

  test('invalid fields stop registration before any network request', () async {
    var requests = 0;
    await http.runWithClient(
      () async {
        expect(await _register(phone: 'abc'), isNotNull);
        expect(await _register(password: 'short'), isNotNull);
      },
      () => MockClient((_) async {
        requests++;
        return http.Response('{"status":"success"}', 200);
      }),
    );
    expect(requests, 0);
  });

  test(
    'structured validation errors are preserved for registration and password changes',
    () async {
      const message = 'Current password is incorrect.';
      await http.runWithClient(
        () async {
          expect(await _register(), message);
          final auth = AuthProvider();
          expect(
            await auth.changePassword(
              currentPassword: 'current',
              newPassword: 'new password',
            ),
            isFalse,
          );
          expect(auth.errorMessage, message);
          expect(auth.isLoading, isFalse);
          auth.dispose();
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({'status': 'error', 'message': message}),
            422,
          ),
        ),
      );
    },
  );

  test(
    'failed registration without a message is never treated as success',
    () async {
      await http.runWithClient(
        () async {
          expect(await _register(), 'Pendaftaran gagal. Sila cuba lagi.');
        },
        () => MockClient((_) async => http.Response('{"status":"error"}', 200)),
      );
    },
  );

  for (final response in [
    http.Response('<html>proxy failure</html>', 400),
    http.Response('{"message":"database internal details"}', 500),
  ]) {
    test(
      'unusable server response ${response.statusCode} stays user friendly',
      () async {
        await http.runWithClient(() async {
          expect(
            await _register(),
            'Tidak dapat menghubungi pelayan. Sila cuba lagi.',
          );
        }, () => MockClient((_) async => response));
      },
    );
  }

  test(
    'password change preserves spaces and clears the forced-change flag',
    () async {
      SharedPreferences.setMockInitialValues({'must_change_password': true});
      await http.runWithClient(
        () async {
          final auth = AuthProvider();
          expect(
            await auth.changePassword(
              currentPassword: ' current ',
              newPassword: ' new pass ',
            ),
            isTrue,
          );
          expect(auth.mustChangePassword, isFalse);
          expect(auth.isLoading, isFalse);
          auth.dispose();
        },
        () => MockClient((request) async {
          expect(request.bodyFields['current_password'], ' current ');
          expect(request.bodyFields['new_password'], ' new pass ');
          return http.Response('{"status":"success"}', 200);
        }),
      );
    },
  );
}
