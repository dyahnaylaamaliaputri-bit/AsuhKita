


import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('AsuhKita App smoke test', (WidgetTester tester) async {

    await tester.pumpWidget(const AsuhKitaApp());

    expect(find.byType(AsuhKitaApp), findsOneWidget);
  });
}
