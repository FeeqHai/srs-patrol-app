import 'package:flutter_test/flutter_test.dart';
import 'package:srs_app/features/auth/services/mykad_capture_validator.dart';

void main() {
  test('accepts a capture when name and IC number were extracted', () {
    final issues = MyKadCaptureValidator.contentIssues(hasRequiredFields: true);

    expect(issues, isEmpty);
  });

  test('reports missing required MyKad fields', () {
    final issues = MyKadCaptureValidator.contentIssues(
      hasRequiredFields: false,
    );

    expect(
      issues,
      contains('Nama atau nombor MyKad tidak dapat dibaca dengan yakin.'),
    );
  });
}
