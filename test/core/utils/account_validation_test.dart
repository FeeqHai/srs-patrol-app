import 'package:flutter_test/flutter_test.dart';
import 'package:srs_app/core/utils/account_validation.dart';

void main() {
  group('password', () {
    test('requires a value and at least eight characters', () {
      for (final value in [null, '', '        ', 'short', 'éééé']) {
        expect(AccountValidation.password(value), isNotNull);
      }
      for (final value in [
        'abcdefgh',
        'P@ssword1',
        ' pass word ',
        'éééééééé',
      ]) {
        expect(AccountValidation.password(value), isNull);
      }
    });
    test('rejects control characters and bcrypt truncation', () {
      expect(AccountValidation.password('a' * 72), isNull);
      expect(AccountValidation.password('a' * 73), isNotNull);
      expect(AccountValidation.password('é' * 36), isNull);
      expect(AccountValidation.password('é' * 37), isNotNull);
      for (final value in ['password\n', 'password\u0000', 'password\t']) {
        expect(AccountValidation.password(value), isNotNull);
      }
    });
    test('confirmation compares the exact password including spaces', () {
      expect(AccountValidation.confirmPassword('', ''), isNotNull);
      expect(
        AccountValidation.confirmPassword('password', ' password'),
        isNotNull,
      );
      expect(
        AccountValidation.confirmPassword(' password ', ' password '),
        isNull,
      );
    });
  });
  group('phone number', () {
    test('accepts and normalizes supported local and country-code formats', () {
      const values = {
        '0123456789': '0123456789',
        '01112345678': '01112345678',
        '03-1234 5678': '0312345678',
        '04-1234567': '041234567',
        ' +60 12-345 6789 ': '0123456789',
        '60123456789': '0123456789',
      };
      for (final entry in values.entries) {
        expect(AccountValidation.phone(entry.key), isNull, reason: entry.key);
        expect(AccountValidation.normalizePhone(entry.key), entry.value);
      }
    });
    test('rejects missing, malformed and out-of-range numbers', () {
      for (final value in [
        null,
        '',
        '01234',
        '012345678901',
        '012abc3456789',
        '0012345678',
        '+600123456789',
        '1234567890',
        '+6512345678',
        '012.3456789',
        '0123456789\n0',
        '٠١٢٣٤٥٦٧٨٩',
      ]) {
        expect(AccountValidation.phone(value), isNotNull, reason: value);
      }
    });
  });
  group('MyKad', () {
    test('accepts 12 digits with standard separators', () {
      for (final value in [
        '900101045678',
        '900101-04-5678',
        ' 900101 04 5678 ',
      ]) {
        expect(AccountValidation.icNumber(value), isNull);
        expect(AccountValidation.normalizeIc(value), '900101045678');
      }
    });
    test('rejects garbage, wrong lengths and impossible calendar dates', () {
      for (final value in [
        null,
        '',
        '90010104567',
        '9001010456789',
        'IC900101045678',
        '900101x04x5678',
        '90010-104-5678',
        '901301045678',
        '900100045678',
        '900431045678',
        '010229045678',
        '000000000000',
      ]) {
        expect(AccountValidation.icNumber(value), isNotNull, reason: value);
      }
      expect(AccountValidation.icNumber('000229045678'), isNull);
      expect(AccountValidation.icNumber('040229045678'), isNull);
    });
  });
}
