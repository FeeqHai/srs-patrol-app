import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:srs_app/core/providers/settings_provider.dart';
import 'package:srs_app/features/auth/models/user_model.dart';
import 'package:srs_app/features/post/widgets/edit_member_profile_dialog.dart';

final _member = UserModel(
  id: 'dialog-test-member',
  fullName: 'OCR TEST MEMBER',
  icNumber: '900101000000',
  phoneNumber: '0100000000',
  email: 'dialog.test@example.invalid',
  role: 'peronda',
);

Future<void> _showEditor(
  WidgetTester tester,
  List<MemberProfileEditResult?> results, {
  String language = 'en',
}) async {
  SharedPreferences.setMockInitialValues({'languageCode': language});
  final settings = SettingsProvider();
  await settings.setLanguage(language);
  addTearDown(settings.dispose);
  addTearDown(tester.view.resetViewInsets);

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final result = await showDialog<MemberProfileEditResult>(
                    context: context,
                    builder: (_) => EditMemberProfileDialog(member: _member),
                  );
                  results.add(result);
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['ms', 'en']) {
    testWidgets(
      '$language invalid numbers keep the editor open with field errors',
      (tester) async {
        final results = <MemberProfileEditResult?>[];
        await _showEditor(tester, results, language: language);
        await tester.enterText(find.byType(TextField).at(1), '010229045678');
        await tester.enterText(find.byType(TextField).at(2), '012abc3456789');
        await tester.tap(find.text(language == 'ms' ? 'Simpan' : 'Save'));
        await tester.pumpAndSettle();
        expect(results, isEmpty);
        expect(find.byType(EditMemberProfileDialog), findsOneWidget);
        expect(
          find.text(
            language == 'ms'
                ? 'Tarikh lahir dalam nombor MyKad tidak sah.'
                : 'The birth date in the MyKad number is invalid.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            language == 'ms'
                ? 'Masukkan nombor telefon'
                : 'Enter a valid phone number',
          ),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextField).at(1), '900101-04-5678');
        await tester.enterText(find.byType(TextField).at(2), '+60 12-345 6789');
        await tester.tap(find.text(language == 'ms' ? 'Simpan' : 'Save'));
        await tester.pumpAndSettle();
        expect(results.single!.icNumber, '900101045678');
        expect(results.single!.phoneNumber, '0123456789');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['ms', 'en']) {
    testWidgets('$language labels and complete member values are preserved', (
      tester,
    ) async {
      await _showEditor(tester, [], language: language);
      final expectedLabels = language == 'ms'
          ? [
              'Edit Profil Ahli',
              'Nama Penuh',
              'No. Kad Pengenalan',
              'No. Telefon',
              'E-mel',
              'Batal',
              'Simpan',
            ]
          : [
              'Edit Member Profile',
              'Full Name',
              'IC Number',
              'Phone Number',
              'Email',
              'Cancel',
              'Save',
            ];
      for (final label in expectedLabels) {
        expect(find.text(label), findsOneWidget);
      }
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.map((field) => field.controller!.text), [
        _member.fullName,
        _member.icNumber,
        _member.phoneNumber,
        _member.email,
      ]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Save returns one immutable snapshot with trimmed field values', (
    tester,
  ) async {
    final results = <MemberProfileEditResult?>[];
    await _showEditor(tester, results);
    final values = [
      '  UPDATED TEST MEMBER  ',
      '  900101000001  ',
      '  0100000001  ',
      '  updated.test@example.invalid  ',
    ];
    for (var index = 0; index < values.length; index++) {
      await tester.enterText(find.byType(TextField).at(index), values[index]);
    }

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    final result = results.single!;
    expect(result.fullName, 'UPDATED TEST MEMBER');
    expect(result.icNumber, '900101000001');
    expect(result.phoneNumber, '0100000001');
    expect(result.email, 'updated.test@example.invalid');
    expect(_member.fullName, 'OCR TEST MEMBER');
    expect(tester.takeException(), isNull);
  });

  for (final action in ['Save', 'Cancel', 'Back']) {
    testWidgets(
      '$action keeps controllers alive through keyboard and exit animation',
      (tester) async {
        final results = <MemberProfileEditResult?>[];
        await _showEditor(tester, results);
        final controllers = tester
            .widgetList<TextField>(find.byType(TextField))
            .map((field) => field.controller!)
            .toList();
        await tester.enterText(find.byType(TextField).at(2), '0100000002');
        expect(tester.testTextInput.isVisible, isTrue);
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();

        if (action == 'Back') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.text(action));
        }
        await tester.pump();

        // The result is already available, but the dialog is still animating.
        expect(results, hasLength(1));
        expect(find.byType(EditMemberProfileDialog), findsOneWidget);
        void listener() {}
        for (final controller in controllers) {
          expect(() => controller.addListener(listener), returnsNormally);
          controller.removeListener(listener);
        }

        // Rebuild the closing dialog while the keyboard's insets are changing,
        // reproducing the timing that previously used a disposed controller.
        tester.view.viewInsets = const FakeViewPadding(bottom: 60);
        await tester.pump(const Duration(milliseconds: 30));
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();

        expect(find.byType(EditMemberProfileDialog), findsNothing);
        expect(tester.takeException(), isNull);
        for (final controller in controllers) {
          expect(() => controller.addListener(listener), throwsFlutterError);
        }
        if (action == 'Save') {
          expect(results.single!.phoneNumber, '0100000002');
        } else {
          expect(results.single, isNull);
        }
      },
    );
  }

  testWidgets('tapping outside the dialog cancels without returning changes', (
    tester,
  ) async {
    final results = <MemberProfileEditResult?>[];
    await _showEditor(tester, results);
    await tester.enterText(find.byType(TextField).at(0), 'UNSAVED TEST NAME');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(results, [null]);
    expect(find.byType(EditMemberProfileDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reopening after Save Cancel and Back creates fresh controllers',
    (tester) async {
      final results = <MemberProfileEditResult?>[];
      await _showEditor(tester, results);
      TextEditingController? previousPhone;
      for (final action in ['Save', 'Cancel', 'Back', 'Save']) {
        final phone = tester
            .widget<TextField>(find.byType(TextField).at(2))
            .controller!;
        expect(identical(phone, previousPhone), isFalse);
        expect(phone.text, _member.phoneNumber);
        await tester.enterText(find.byType(TextField).at(2), '0100000003');
        if (action == 'Back') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.text(action));
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        previousPhone = phone;
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
      }
      expect(results, hasLength(4));
      expect(results[0]!.phoneNumber, '0100000003');
      expect(results[1], isNull);
      expect(results[2], isNull);
      expect(results[3]!.phoneNumber, '0100000003');
      expect(tester.takeException(), isNull);
    },
  );
}
