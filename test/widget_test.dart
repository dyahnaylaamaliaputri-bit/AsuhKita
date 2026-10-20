// Letak file: mobile/test/widget_test.dart
// Fungsi: Smoke test dasar aplikasi AsuhKita

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('AsuhKita App smoke test', (WidgetTester tester) async {
    // Bangun widget aplikasi utama AsuhKita
    await tester.pumpWidget(const AsuhKitaApp());
    // Pastikan widget ter-render
    expect(find.byType(AsuhKitaApp), findsOneWidget);
  });
}
