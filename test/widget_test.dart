import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srs_app/main.dart';

void main() {
  testWidgets('iRonda application boots through its splash sequence', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SRSPatrolApp());
    expect(find.byType(MaterialApp), findsOneWidget);

    // Complete both delayed splash stages so the test leaves no pending timer.
    await tester.pump(const Duration(milliseconds: 4800));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
