import '../../../core/utils/account_validation.dart';

class MyKadData {
  const MyKadData({required this.fullName, required this.icNumber});

  final String fullName;
  final String icNumber;
}

class MyKadParser {
  static final RegExp _icPattern = RegExp(
    r'(?<!\d)(\d{6})[\s-]?(\d{2})[\s-]?(\d{4})(?!\d)',
  );

  static const Set<String> _excludedNameWords = {
    'MALAYSIA',
    'KAD PENGENALAN',
    'IDENTITY CARD',
    'MYKAD',
    'WARGANEGARA',
    'LELAKI',
    'PEREMPUAN',
    'ISLAM',
  };

  static const Set<String> _placeWords = {
    'JOHOR',
    'KEDAH',
    'KELANTAN',
    'MELAKA',
    'MALACCA',
    'NEGERI SEMBILAN',
    'PAHANG',
    'PENANG',
    'PERAK',
    'PERLIS',
    'PULAU PINANG',
    'SABAH',
    'SARAWAK',
    'SELANGOR',
    'TERENGGANU',
    'KUALA LUMPUR',
    'PUTRAJAYA',
    'LABUAN',
    'AYER KEROH',
  };

  MyKadData? parse(String recognizedText) {
    final normalized = recognizedText
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r"[^A-Za-z0-9@/.,'\-\s]"), ' ')
        .toUpperCase();
    final lines = normalized
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final compact = lines.join('\n');
    final icMatch = _icPattern.firstMatch(compact);
    if (icMatch == null) return null;
    final icNumber =
        '${icMatch.group(1)}${icMatch.group(2)}${icMatch.group(3)}';
    if (!isValidIcNumber(icNumber)) return null;

    final fullName = _extractName(lines, icNumber);
    if (fullName == null) return null;

    return MyKadData(fullName: _titleCaseName(fullName), icNumber: icNumber);
  }

  static bool isValidIcNumber(String value) {
    return AccountValidation.icNumber(value) == null;
  }

  String? _extractName(List<String> lines, String icNumber) {
    var icLineIndex = -1;
    for (var index = 0; index < lines.length; index++) {
      final digits = lines[index].replaceAll(RegExp(r'\D'), '');
      if (digits.contains(icNumber)) {
        icLineIndex = index;
        break;
      }
    }

    if (icLineIndex >= 0) {
      final anchoredName = _extractNameAfterIc(lines, icLineIndex);
      if (anchoredName != null) return anchoredName;
    }

    return _bestSingleLineName(lines, icLineIndex);
  }

  String? _extractNameAfterIc(List<String> lines, int icLineIndex) {
    final nameLines = <String>[];
    final end = (icLineIndex + 5).clamp(0, lines.length);

    for (var index = icLineIndex + 1; index < end; index++) {
      final original = lines[index];
      final line = _normalizeNameLine(original);

      if (nameLines.isNotEmpty && _mustStopName(original, line)) break;
      if (!_isNameLine(original, line)) {
        if (nameLines.isNotEmpty) break;
        continue;
      }

      if (nameLines.isNotEmpty &&
          !_looksLikeNameContinuation(nameLines.last, line)) {
        break;
      }

      nameLines.add(line);
      // MyKad names normally occupy one or two printed lines. Limiting the
      // collection prevents a word-only address from being appended.
      if (nameLines.length == 2) break;
    }

    return nameLines.isEmpty ? null : nameLines.join(' ');
  }

  bool _looksLikeNameContinuation(String previousLine, String nextLine) {
    const continuationEndings = <String>{
      'BIN',
      'BINTI',
      'BT',
      'A/L',
      'A/P',
      'S/O',
      'D/O',
      'ANAK',
    };
    final previousParts = previousLine.split(' ');
    final endsWithConnector =
        previousParts.isNotEmpty &&
        continuationEndings.contains(previousParts.last);
    final nextPartCount = nextLine.split(' ').length;
    return endsWithConnector ||
        (previousLine.length >= 20 && nextPartCount <= 4);
  }

  String? _bestSingleLineName(List<String> lines, int icLineIndex) {
    final candidates = <({String value, int score})>[];

    for (var index = 0; index < lines.length; index++) {
      final line = _normalizeNameLine(lines[index]);
      if (!_isNameLine(lines[index], line)) continue;
      final letterCount = RegExp(r'[A-Z]').allMatches(line).length;

      var score = letterCount;
      if (icLineIndex >= 0 && index == icLineIndex + 1) {
        score += 200;
      } else if (icLineIndex >= 0 &&
          index > icLineIndex &&
          index <= icLineIndex + 4) {
        score += 100;
      }
      if (line.split(' ').length >= 2) score += 20;
      candidates.add((value: line, score: score));
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.isEmpty ? null : candidates.first.value;
  }

  String _normalizeNameLine(String line) {
    return line
        .replaceAll(RegExp("[^A-Z @/'.-]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isNameLine(String original, String line) {
    if (line.length < 3 || line.length > 100) return false;
    if (RegExp(r'\d').hasMatch(original)) return false;
    if (_excludedNameWords.any((word) => line == word || line.contains(word))) {
      return false;
    }
    if (_looksLikeAddress(line)) return false;
    return RegExp(r'[A-Z]').allMatches(line).length >= 3;
  }

  bool _mustStopName(String original, String line) {
    return RegExp(r'\d').hasMatch(original) ||
        _excludedNameWords.any((word) => line == word || line.contains(word)) ||
        _looksLikeAddress(line);
  }

  bool _looksLikeAddress(String line) {
    const markers = <String>{
      'BLOK',
      'BLOCK',
      'JALAN',
      'JLN',
      'LORONG',
      'LRG',
      'TAMAN',
      'KAMPUNG',
      'KG',
      'BANDAR',
      'PERSIARAN',
      'LEBUH',
      'PARCEL',
      'APARTMENT',
      'PANGSAPURI',
      'FLAT',
      'TINGKAT',
      'POS',
      'NO ',
    };
    if (markers.any(
      (marker) => line == marker || line.startsWith('$marker '),
    )) {
      return true;
    }
    return _placeWords.any(
      (place) =>
          line == place ||
          line.startsWith('$place ') ||
          line.endsWith(' $place'),
    );
  }

  String _titleCaseName(String name) {
    return name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => const {'A/L', 'A/P', 'S/O', 'D/O'}.contains(part)
              ? part
              : part.length == 1
              ? part
              : '${part[0]}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
