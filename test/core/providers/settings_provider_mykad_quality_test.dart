import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:srs_app/core/providers/settings_provider.dart';

void main() {
  const messages = <String, String>{
    'Resolusi imej terlalu rendah.': 'The image resolution is too low.',
    'Keseluruhan kad perlu kelihatan di dalam bingkai.':
        'The entire card must be visible inside the frame.',
    'Imej kabur. Pegang telefon dengan stabil dan cuba semula.':
        'The image is blurry. Hold the phone steady and try again.',
    'Pantulan cahaya terlalu kuat pada MyKad.':
        'There is too much glare on the MyKad.',
    'Nama atau nombor MyKad tidak dapat dibaca dengan yakin.':
        'The name or MyKad number could not be read reliably.',
    'Pastikan potret utama MyKad jelas dan tiada wajah lain kelihatan di luar kad.':
        'Ensure the main MyKad portrait is clear and no other face is visible outside the card.',
  };

  test('MyKad quality failures are translated to English', () async {
    SharedPreferences.setMockInitialValues({'languageCode': 'en'});
    final settings = SettingsProvider();
    await settings.setLanguage('en');

    for (final entry in messages.entries) {
      expect(settings.t(entry.key), entry.value);
    }
  });

  test('MyKad quality failures remain in Bahasa Melayu', () async {
    SharedPreferences.setMockInitialValues({'languageCode': 'ms'});
    final settings = SettingsProvider();
    await settings.setLanguage('ms');

    for (final message in messages.keys) {
      expect(settings.t(message), message);
    }
  });
}
