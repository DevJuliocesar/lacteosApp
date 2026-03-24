import 'package:flutter_test/flutter_test.dart';
import 'package:lacteos_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LacteosApp());
    expect(find.text('Lácteos App'), findsOneWidget);
  });
}
