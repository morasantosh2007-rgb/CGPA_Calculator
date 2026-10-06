import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('GradeLensApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GradeLensApp(isLoggedIn: false));
    expect(find.text('GradeLens'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
