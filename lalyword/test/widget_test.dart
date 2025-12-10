import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lalyword/main.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: LalyApp()));

    // Verify that we start with some UI (e.g. settings or title)
    // Since settings are empty by default, it should be SettingsScreen
    // But since this is a unit test, SharedPrefs might be mocked or empty.
    
    // Just verify it doesn't crash on start
    expect(find.byType(LalyApp), findsOneWidget);
  });
}
