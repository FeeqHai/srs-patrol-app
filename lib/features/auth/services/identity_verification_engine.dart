import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'image_quality_analyzer.dart';
import 'mykad_capture_validator.dart';
import 'mykad_parser.dart';
import '../../../core/utils/logger.dart';

class MyKadAnalysis {
  const MyKadAnalysis({
    required this.data,
    required this.quality,
    required this.issues,
  });

  final MyKadData? data;
  final ImageQualityResult quality;
  final List<String> issues;

  bool get isAcceptable => data != null && issues.isEmpty;
}

class IdentityVerificationEngine {
  IdentityVerificationEngine()
    : _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static const String ocrVersion = 'mlkit-latin-ocr-prototype';

  final TextRecognizer _textRecognizer;
  final MyKadParser _parser = MyKadParser();
  final ImageQualityAnalyzer _qualityAnalyzer = const ImageQualityAnalyzer();

  Future<MyKadAnalysis> analyzeMyKad(XFile file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Fail imej MyKad tidak dapat dibaca.');
    }

    final quality = _qualityAnalyzer.analyzeMyKad(decoded);
    final recognizedText = await _textRecognizer.processImage(
      InputImage.fromFilePath(file.path),
    );
    final data = _parser.parse(recognizedText.text);
    final issues = <String>[
      ...quality.issues,
      ...MyKadCaptureValidator.contentIssues(hasRequiredFields: data != null),
    ];

    return MyKadAnalysis(data: data, quality: quality, issues: issues);
  }

  Future<void> deleteTemporaryImages(Iterable<XFile?> files) async {
    for (final file in files.whereType<XFile>()) {
      try {
        final temporary = File(file.path);
        if (await temporary.exists()) await temporary.delete();
      } catch (error, stackTrace) {
        // Best-effort cleanup: image_picker owns the cache directory and the OS
        // will also clear it. Raw MyKad images are never uploaded or copied.
        // Do not log the path because it may identify a sensitive temporary
        // document file.
        appLogger.w(
          'Temporary MyKad image cleanup could not be completed.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> dispose() => _textRecognizer.close();
}
