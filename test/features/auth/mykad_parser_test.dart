import 'package:flutter_test/flutter_test.dart';
import 'package:srs_app/features/auth/services/mykad_parser.dart';

void main() {
  group('MyKadParser', () {
    final parser = MyKadParser();

    test('extracts verified fields from typical OCR text', () {
      const ocr = '''
MALAYSIA
KAD PENGENALAN
900101-04-5678
NUR AISYAH BINTI ALI
NO 12 JALAN BUKIT
75450 MELAKA
WARGANEGARA
''';

      final result = parser.parse(ocr);

      expect(result, isNotNull);
      expect(result!.fullName, 'Nur Aisyah Binti Ali');
      expect(result.icNumber, '900101045678');
    });

    test('accepts OCR spacing without using the address state', () {
      const ocr = '''
IDENTITY CARD
991231 01 1234
AHMAD BIN ABDULLAH
AYER KEROH MALACCA
''';

      final result = parser.parse(ocr);

      expect(result, isNotNull);
      expect(result!.fullName, 'Ahmad Bin Abdullah');
    });

    test('combines a two-line long name and stops before the address', () {
      const ocr = '''
KAD PENGENALAN MALAYSIA
980317-13-5131
NUR AINAA AMALIN BINTI
SHAMSUDIN
BLOK C 101-U14
PARCEL 5R3 PRESINT 5
62200 PUTRAJAYA
WARGANEGARA
''';

      final result = parser.parse(ocr);

      expect(result, isNotNull);
      expect(result!.fullName, 'Nur Ainaa Amalin Binti Shamsudin');
      expect(result.icNumber, '980317135131');
    });

    test('does not append a word-only location to a one-line name', () {
      const ocr = '''
IDENTITY CARD
991231-01-1234
AHMAD BIN ABDULLAH
AYER KEROH MALACCA
MELAKA
''';

      final result = parser.parse(ocr);

      expect(result, isNotNull);
      expect(result!.fullName, 'Ahmad Bin Abdullah');
    });

    test('preserves A/L in a name split across two lines', () {
      const ocr = '''
900101-01-1234
RAVI A/L
MUTHUSAMY
NO 12 JALAN BUKIT
''';

      final result = parser.parse(ocr);

      expect(result, isNotNull);
      expect(result!.fullName, 'Ravi A/L Muthusamy');
    });

    test('rejects an impossible birth month', () {
      const ocr = '''
901301-01-1234
AHMAD BIN ABDULLAH
JOHOR
''';

      expect(parser.parse(ocr), isNull);
    });

    test('accepts OCR without an address state', () {
      const ocr = '''
900101-01-1234
AHMAD BIN ABDULLAH
MALAYSIA
''';

      final result = parser.parse(ocr);

      expect(result, isNotNull);
      expect(result!.fullName, 'Ahmad Bin Abdullah');
      expect(result.icNumber, '900101011234');
    });
  });
}
