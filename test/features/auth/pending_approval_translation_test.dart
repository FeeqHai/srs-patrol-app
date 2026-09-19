import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:srs_app/core/providers/settings_provider.dart';

void main() {
  const pendingMessage = 'Akaun anda sedang menunggu kelulusan Pentadbir KRT.';
  const inactiveMessage =
      'Pendaftaran anda telah ditolak atau akaun telah dinyahaktifkan.';

  test('pending approval messages are translated to English', () async {
    SharedPreferences.setMockInitialValues({'languageCode': 'en'});
    final settings = SettingsProvider();
    await settings.setLanguage('en');

    expect(
      settings.t(pendingMessage),
      'Your account is awaiting KRT Administrator approval.',
    );
    expect(
      settings.t(inactiveMessage),
      'Your registration was rejected or the account has been deactivated.',
    );
    expect(settings.t('Invalid credentials.'), 'Invalid email or password.');
    expect(settings.t('Lulus Pendaftaran'), 'Approve Registration');
    expect(settings.t('Tolak Pendaftaran'), 'Reject Registration');
    expect(settings.t('Ya, Lulus'), 'Yes, Approve');
    expect(settings.t('Ya, Tolak'), 'Yes, Reject');
  });

  test('pending approval messages remain in Bahasa Melayu', () async {
    SharedPreferences.setMockInitialValues({'languageCode': 'ms'});
    final settings = SettingsProvider();
    await settings.setLanguage('ms');

    expect(settings.t(pendingMessage), pendingMessage);
    expect(settings.t(inactiveMessage), inactiveMessage);
    expect(
      settings.t('Invalid credentials.'),
      'E-mel atau kata laluan tidak sah.',
    );
    expect(settings.t('Lulus Pendaftaran'), 'Lulus Pendaftaran');
    expect(settings.t('Tolak Pendaftaran'), 'Tolak Pendaftaran');
    expect(settings.t('Ya, Lulus'), 'Ya, Lulus');
    expect(settings.t('Ya, Tolak'), 'Ya, Tolak');
  });
}
