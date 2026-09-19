import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:srs_app/core/providers/settings_provider.dart';

void main() {
  test('registration labels are consistently translated to English', () async {
    SharedPreferences.setMockInitialValues({'languageCode': 'en'});
    final settings = SettingsProvider();
    await settings.setLanguage('en');

    expect(settings.t('Pendaftaran'), 'Registration');
    expect(settings.t('Daftar Peronda Baru'), 'Register New Patroller');
    expect(settings.t('Pendaftaran Peronda'), 'Patroller Registration');
    expect(settings.t('Maklumat Identiti'), 'Identity Information');
    expect(settings.t('Maklumat Operasi'), 'Operation Information');
    expect(settings.t('Memuatkan negeri...'), 'Loading states...');
    expect(settings.t('Pilih Negeri'), 'Select State');
    expect(settings.t('Pilih Daerah'), 'Select District');
    expect(settings.t('Pilih Zon Rondaan'), 'Select Patrol Zone');
    expect(settings.t('Sila pilih negeri'), 'Please select a state');
    expect(settings.t('Sila pilih daerah'), 'Please select a district');
    expect(settings.t('Sila pilih zon'), 'Please select a zone');
    expect(
      settings.t(
        'Nama dan nombor MyKad dikunci berdasarkan keputusan pengesahan. Pilih sendiri negeri, daerah dan zon rondaan anda.',
      ),
      'The name and MyKad number are locked based on the verification result. Select your operating state, district, and patrol zone.',
    );
    expect(settings.t('Cuba lagi'), 'Try again');
  });

  test('registration labels remain in Bahasa Melayu when selected', () async {
    SharedPreferences.setMockInitialValues({'languageCode': 'ms'});
    final settings = SettingsProvider();
    await settings.setLanguage('ms');

    expect(settings.t('Pendaftaran'), 'Pendaftaran');
    expect(settings.t('Pilih Negeri'), 'Pilih Negeri');
    expect(settings.t('Pilih Daerah'), 'Pilih Daerah');
    expect(settings.t('Pilih Zon Rondaan'), 'Pilih Zon Rondaan');
    expect(
      settings.t(
        'Nama dan nombor MyKad dikunci berdasarkan keputusan pengesahan. Pilih sendiri negeri, daerah dan zon rondaan anda.',
      ),
      'Nama dan nombor MyKad dikunci berdasarkan keputusan pengesahan. Pilih sendiri negeri, daerah dan zon rondaan anda.',
    );
  });
}
