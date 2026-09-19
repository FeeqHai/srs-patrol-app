import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/verified_identity.dart';

typedef VerificationPostData =
    Future<Map<String, dynamic>> Function(
      String endpoint,
      Map<String, String> body,
    );

class VerificationApiException implements Exception {
  const VerificationApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class IdentityVerificationApi {
  IdentityVerificationApi({VerificationPostData? postData})
    : _postData = postData ?? ApiClient.postData;

  final VerificationPostData _postData;

  Future<VerificationSession> start({required String icNumber}) async {
    final response = await _postData(ApiConstants.verificationStartEndpoint, {
      'ic_number': icNumber,
      'device_id': await _installationId(),
      'consent': 'true',
    });
    _throwIfRejected(response);
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const VerificationApiException(
        'Respons sesi pengesahan tidak sah.',
      );
    }
    return VerificationSession(
      id: data['session_id'].toString(),
      token: data['verification_token'].toString(),
      expiresAt: DateTime.parse(data['expires_at'].toString()),
    );
  }

  Future<VerificationSession> complete({
    required VerificationSession session,
    required String fullName,
    required bool qualityPassed,
    required String ocrVersion,
  }) async {
    final response =
        await _postData(ApiConstants.verificationCompleteEndpoint, {
          'session_id': session.id,
          'verification_token': session.token,
          'full_name': fullName,
          'quality_passed': qualityPassed.toString(),
          'model_version': ocrVersion,
          'verification_method': 'on_device_mykad_ocr_prototype',
        });
    _throwIfRejected(response);
    final data = response['data'] as Map<String, dynamic>?;
    final token = data?['verification_token']?.toString() ?? '';
    final expiresAt = DateTime.tryParse(data?['expires_at']?.toString() ?? '');
    if (token.isEmpty || expiresAt == null) {
      throw const VerificationApiException('Token pengesahan tidak diterima.');
    }
    return VerificationSession(
      id: session.id,
      token: token,
      expiresAt: expiresAt,
    );
  }

  void _throwIfRejected(Map<String, dynamic> response) {
    if (response['status'] == 'success') return;
    throw VerificationApiException(
      response['message']?.toString() ?? 'Pengesahan identiti gagal.',
    );
  }

  Future<String> _installationId() async {
    const key = 'identity_verification_installation_id';
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = const Uuid().v4();
    await preferences.setString(key, created);
    return created;
  }
}
