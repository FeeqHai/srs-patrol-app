import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:srs_app/core/providers/settings_provider.dart';
import 'package:srs_app/features/auth/providers/auth_provider.dart';
import 'package:srs_app/features/auth/views/change_password_screen.dart';
import 'package:srs_app/features/auth/views/register_screen.dart';

class _RecordingAuth extends AuthProvider {
  String? current;
  String? next;
  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    current = currentPassword;
    next = newPassword;
    return true;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'languageCode': 'en'}));

  testWidgets(
    'password change blocks short and mismatched passwords, then preserves spaces',
    (tester) async {
      final settings = SettingsProvider();
      await settings.setLanguage('en');
      final auth = _RecordingAuth();
      addTearDown(settings.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(home: ChangePasswordScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), ' current ');
      await tester.enterText(find.byType(TextFormField).at(1), 'short');
      await tester.enterText(find.byType(TextFormField).at(2), 'short');
      await tester.ensureVisible(find.text('Save Password'));
      await tester.tap(find.text('Save Password'));
      await tester.pumpAndSettle();
      expect(auth.next, isNull);
      expect(
        find.text('Password must be at least 8 characters.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField).at(1), ' new pass ');
      await tester.enterText(find.byType(TextFormField).at(2), 'new pass');
      await tester.ensureVisible(find.text('Save Password'));
      await tester.tap(find.text('Save Password'));
      await tester.pumpAndSettle();
      expect(auth.next, isNull);
      expect(find.text('Passwords do not match'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(2), ' new pass ');
      await tester.ensureVisible(find.text('Save Password'));
      await tester.tap(find.text('Save Password'));
      await tester.pumpAndSettle();
      expect(auth.current, ' current ');
      expect(auth.next, ' new pass ');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registration shows phone, password and confirmation errors inline',
    (tester) async {
      final settings = SettingsProvider();
      await settings.setLanguage('en');
      addTearDown(settings.dispose);
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settings,
              child: const MaterialApp(home: RegisterScreen()),
            ),
          );
          await tester.pumpAndSettle();
          Finder field(String hint) => find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.hintText == hint,
          );
          await tester.enterText(field('Phone Number (Emergency)'), 'letters');
          await tester.enterText(field('Password'), 'short');
          await tester.enterText(field('Confirm Password'), 'different');
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Enter a valid phone number'),
            findsOneWidget,
          );
          // The minimum length is also displayed as a hint.
          expect(
            find.text('Password must be at least 8 characters.'),
            findsWidgets,
          );
          expect(find.text('Passwords do not match'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (_) async => http.Response('{"status":"success","data":[]}', 200),
        ),
      );
    },
  );
}
