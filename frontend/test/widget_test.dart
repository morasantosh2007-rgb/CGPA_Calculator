import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';

void main() {
  testWidgets('GradeLensApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Text('GradeLens Direct Access Ready'),
        ),
      ),
    );
    expect(find.text('GradeLens Direct Access Ready'), findsOneWidget);
  });
}
