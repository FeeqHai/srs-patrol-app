import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:srs_app/core/constants/api_constants.dart';
import 'package:srs_app/features/auth/services/identity_verification_api.dart';
import 'package:srs_app/features/auth/services/identity_verification_engine.dart';

void main() {
  test('temporary MyKad image is deleted after local processing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ironda_mykad_cleanup_test_',
    );
    final temporaryImage = File('${directory.path}/temporary_mykad.jpg');
    await temporaryImage.writeAsBytes(const [1, 2, 3, 4]);
    final engine = IdentityVerificationEngine();

    await engine.deleteTemporaryImages([XFile(temporaryImage.path)]);

    expect(await temporaryImage.exists(), isFalse);
    await directory.delete(recursive: true);
  });

  test('verification API sends text metadata without image data', () async {
    SharedPreferences.setMockInitialValues({
      'identity_verification_installation_id': 'privacy-test-device',
    });
    final requests = <({String endpoint, Map<String, String> body})>[];
    final api = IdentityVerificationApi(
      postData: (endpoint, body) async {
        requests.add((endpoint: endpoint, body: Map.of(body)));
        if (endpoint == ApiConstants.verificationStartEndpoint) {
          return {
            'status': 'success',
            'data': {
              'session_id': '11111111-1111-4111-8111-111111111111',
              'verification_token': 'a' * 64,
              'expires_at': '2026-09-02T12:15:00+08:00',
            },
          };
        }
        return {
          'status': 'success',
          'data': {
            'verification_token': 'a' * 64,
            'expires_at': '2026-09-02T12:15:00+08:00',
          },
        };
      },
    );

    final session = await api.start(icNumber: '900101000000');
    await api.complete(
      session: session,
      fullName: 'PRIVACY TEST USER',
      qualityPassed: true,
      ocrVersion: 'privacy-test-ocr',
    );

    expect(requests, hasLength(2));
    expect(requests[0].body.keys, {'ic_number', 'device_id', 'consent'});
    expect(requests[1].body.keys, {
      'session_id',
      'verification_token',
      'full_name',
      'quality_passed',
      'model_version',
      'verification_method',
    });
    const forbiddenTerms = {
      'image',
      'file',
      'path',
      'bytes',
      'selfie',
      'face',
      'biometric',
      'embedding',
    };
    for (final request in requests) {
      for (final key in request.body.keys) {
        final normalized = key.toLowerCase();
        expect(
          forbiddenTerms.any(normalized.contains),
          isFalse,
          reason: 'Sensitive image or biometric field was sent: $key',
        );
      }
    }
  });
}
