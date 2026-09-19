class MyKadCaptureValidator {
  const MyKadCaptureValidator._();

  static List<String> contentIssues({required bool hasRequiredFields}) {
    if (hasRequiredFields) return const [];
    return const ['Nama atau nombor MyKad tidak dapat dibaca dengan yakin.'];
  }
}
