import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:srs_app/core/providers/settings_provider.dart';
import 'package:srs_app/features/auth/views/mykad_camera_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'languageCode': 'ms'});
  });

  test('alignment frame uses the ID-1 card aspect ratio', () {
    expect(MyKadCameraOverlayPainter.cardAspectRatio, closeTo(1.586, 0.001));
  });

  testWidgets('Malay guide explains how to align the complete MyKad', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    final settings = await _settingsFor('ms');
    try {
      await tester.pumpWidget(_guideApp(settings));
      await tester.pump();

      expect(
        find.byKey(const Key('mykad-camera-alignment-frame')),
        findsOneWidget,
      );
      expect(find.text('Selaraskan MyKad di dalam bingkai'), findsOneWidget);
      expect(
        find.textContaining('Pastikan keempat-empat penjuru kelihatan'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('English guide translates the alignment instructions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    final settings = await _settingsFor('en');
    try {
      await tester.pumpWidget(_guideApp(settings));
      await tester.pump();

      expect(find.text('Align the MyKad inside the frame'), findsOneWidget);
      expect(
        find.textContaining('Make sure all four corners are visible'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('alignment guide remains usable in landscape orientation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 360));
    final settings = await _settingsFor('ms');
    try {
      await tester.pumpWidget(_guideApp(settings));
      await tester.pump();

      expect(
        find.byKey(const Key('mykad-camera-alignment-frame')),
        findsOneWidget,
      );
      expect(find.text('Selaraskan MyKad di dalam bingkai'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.binding.setSurfaceSize(null);
    }
  });
}

Future<SettingsProvider> _settingsFor(String languageCode) async {
  SharedPreferences.setMockInitialValues({'languageCode': languageCode});
  final settings = SettingsProvider();
  await settings.setLanguage(languageCode);
  return settings;
}

Widget _guideApp(SettingsProvider settings) {
  return ChangeNotifierProvider<SettingsProvider>.value(
    value: settings,
    child: const MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: MyKadCameraAlignmentGuide(),
      ),
    ),
  );
}
