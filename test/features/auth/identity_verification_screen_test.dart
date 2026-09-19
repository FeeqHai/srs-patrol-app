import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:srs_app/core/providers/settings_provider.dart';
import 'package:srs_app/features/auth/views/identity_verification_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'languageCode': 'ms'});
  });

  test(
    'rescan repeats capture until the extracted data is confirmed',
    () async {
      final captures = <String>[];
      final confirmations = <String>[];
      final pendingCaptures = <String>['first extraction', 'second extraction'];

      final result = await repeatMyKadCaptureUntilConfirmed<String>(
        capture: () async {
          final value = pendingCaptures.removeAt(0);
          captures.add(value);
          return value;
        },
        confirm: (value) async {
          confirmations.add(value);
          return value == 'second extraction';
        },
      );

      expect(result, 'second extraction');
      expect(captures, ['first extraction', 'second extraction']);
      expect(confirmations, ['first extraction', 'second extraction']);
    },
  );

  test('cancelling the reopened camera ends the rescan loop', () async {
    var captureCount = 0;
    final result = await repeatMyKadCaptureUntilConfirmed<String>(
      capture: () async {
        captureCount += 1;
        return captureCount == 1 ? 'first extraction' : null;
      },
      confirm: (_) async => false,
    );

    expect(result, isNull);
    expect(captureCount, 2);
  });

  testWidgets(
    'Malay Android flow allows portrait and landscape capture guidance',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      final settings = await _settingsFor('ms');
      try {
        await tester.pumpWidget(_testApp(settings));
        await tester.pump();

        final title = tester.widget<Text>(
          find.text('Pengekstrakan prototaip — bukan pengesahan pemilik MyKad'),
        );
        expect(title.style?.color, Colors.white);
        expect(find.textContaining('Tiada swafoto'), findsOneWidget);
        expect(find.text('Swafoto neutral'), findsNothing);
        expect(find.text('Cabaran rawak'), findsNothing);
        expect(
          find.textContaining('Pegang telefon secara menegak atau melintang'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('identity-consent-checkbox')),
          findsOneWidget,
        );

        var startButton = tester.widget<FilledButton>(
          find.byKey(const Key('identity-start-button')),
        );
        expect(startButton.onPressed, isNull);

        await tester.tap(find.byKey(const Key('identity-consent-checkbox')));
        await tester.pump();

        startButton = tester.widget<FilledButton>(
          find.byKey(const Key('identity-start-button')),
        );
        expect(startButton.onPressed, isNotNull);

        await tester.tap(find.byKey(const Key('identity-start-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Sediakan MyKad'), findsOneWidget);
        expect(
          find.textContaining(
            'Anda boleh memegang telefon secara menegak atau melintang',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('open-mykad-camera-button')),
          findsOneWidget,
        );

        await tester.tap(find.text('BATAL'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Sediakan MyKad'), findsNothing);
      } finally {
        await tester.binding.setSurfaceSize(null);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('English Android flow translates consent and camera guidance', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    final settings = await _settingsFor('en');
    try {
      await tester.pumpWidget(_testApp(settings));
      await tester.pump();

      expect(
        find.text('Prototype extraction — not MyKad holder verification'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'I consent to the temporary processing of my MyKad',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('No selfie'), findsOneWidget);
      expect(find.text('Neutral selfie'), findsNothing);
      expect(find.text('Random challenge'), findsNothing);
      expect(find.text('SCAN MYKAD'), findsOneWidget);

      await tester.tap(find.byKey(const Key('identity-consent-checkbox')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('identity-start-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Prepare your MyKad'), findsOneWidget);
      expect(
        find.textContaining(
          'You may hold your phone in portrait or landscape orientation',
        ),
        findsOneWidget,
      );
      expect(find.text('OPEN CAMERA'), findsOneWidget);

      await tester.tap(find.text('CANCEL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      await tester.binding.setSurfaceSize(null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('non-Android platforms cannot start identity verification', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final settings = await _settingsFor('ms');
    try {
      await tester.pumpWidget(_testApp(settings));
      await tester.pump();

      expect(
        find.textContaining(
          'Pengekstrakan data MyKad hanya tersedia melalui aplikasi Android',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('identity-consent-checkbox')), findsNothing);
      expect(find.byKey(const Key('identity-start-button')), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Malay extraction review formats data and supports rescan', (
    tester,
  ) async {
    final settings = await _settingsFor('ms');
    bool? decision;
    await tester.pumpWidget(
      _reviewTestApp(settings, (value) => decision = value),
    );

    await tester.tap(find.byKey(const Key('open-extraction-review')));
    await tester.pumpAndSettle();

    expect(find.text('Semak Maklumat Diekstrak'), findsOneWidget);
    expect(find.text('Nur Ainaa Amalin Binti Shamsudin'), findsOneWidget);
    expect(find.text('900101-00-0000'), findsOneWidget);
    expect(
      find.textContaining(
        'Tiada maklumat dihantar ke pelayan sehingga anda memilih BETUL',
      ),
      findsOneWidget,
    );
    expect(find.text('IMBAS SEMULA'), findsOneWidget);
    expect(find.text('BETUL'), findsOneWidget);
    final rescanTransform = tester
        .widget<Transform>(find.byKey(const Key('mykad-review-rescan-scale')))
        .transform
        .storage;
    final confirmTransform = tester
        .widget<Transform>(find.byKey(const Key('mykad-review-confirm-scale')))
        .transform
        .storage;
    expect(rescanTransform[0], closeTo(0.9, 0.001));
    expect(rescanTransform[5], closeTo(0.9, 0.001));
    expect(confirmTransform[0], closeTo(0.9, 0.001));
    expect(confirmTransform[5], closeTo(0.9, 0.001));
    expect(find.byKey(const Key('mykad-review-actions-row')), findsOneWidget);
    final rescanTop = tester.getTopLeft(
      find.byKey(const Key('mykad-review-rescan-button')),
    );
    final confirmTop = tester.getTopLeft(
      find.byKey(const Key('mykad-review-confirm-button')),
    );
    expect(rescanTop.dy, closeTo(confirmTop.dy, 0.001));
    expect(rescanTop.dx, lessThan(confirmTop.dx));

    await tester.tap(find.byKey(const Key('mykad-review-rescan-button')));
    await tester.pumpAndSettle();
    expect(decision, isFalse);
  });

  testWidgets('English extraction review supports confirmation', (
    tester,
  ) async {
    final settings = await _settingsFor('en');
    bool? decision;
    await tester.pumpWidget(
      _reviewTestApp(settings, (value) => decision = value),
    );

    await tester.tap(find.byKey(const Key('open-extraction-review')));
    await tester.pumpAndSettle();

    expect(find.text('Review Extracted Information'), findsOneWidget);
    expect(find.text('Full Name (As on MyKad)'), findsOneWidget);
    expect(find.text('MyKad Number'), findsOneWidget);
    expect(
      find.textContaining(
        'No information is sent to the server until you select CORRECT',
      ),
      findsOneWidget,
    );
    expect(find.text('RESCAN'), findsOneWidget);
    expect(find.text('CORRECT'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mykad-review-confirm-button')));
    await tester.pumpAndSettle();
    expect(decision, isTrue);
  });
}

Future<SettingsProvider> _settingsFor(String languageCode) async {
  SharedPreferences.setMockInitialValues({'languageCode': languageCode});
  final settings = SettingsProvider();
  await settings.setLanguage(languageCode);
  return settings;
}

Widget _testApp(SettingsProvider settings) {
  return ChangeNotifierProvider<SettingsProvider>.value(
    value: settings,
    child: const MaterialApp(home: IdentityVerificationScreen()),
  );
}

Widget _reviewTestApp(
  SettingsProvider settings,
  ValueChanged<bool> onDecision,
) {
  return ChangeNotifierProvider<SettingsProvider>.value(
    value: settings,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            key: const Key('open-extraction-review'),
            onPressed: () async {
              final decision = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const MyKadExtractionReviewDialog(
                  fullName: 'Nur Ainaa Amalin Binti Shamsudin',
                  icNumber: '900101000000',
                ),
              );
              if (decision != null) onDecision(decision);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}
