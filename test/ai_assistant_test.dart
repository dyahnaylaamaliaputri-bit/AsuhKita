




import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_assistant/ai_assistant_screen.dart';

void main() {
  group('FR-49, FR-50, FR-51 | AI Assistant Screen Widget Tests', () {
    Widget makeTestable({FaqAnswerProvider? faqAnswerProvider}) => MaterialApp(
      home: AiAssistantScreen(faqAnswerProvider: faqAnswerProvider),
    );

    testWidgets('Tampil AppBar "Sahabat Asuh (Asisten AI)"', (tester) async {
      await tester.pumpWidget(makeTestable());
      expect(find.text('Sahabat Asuh (Asisten AI)'), findsOneWidget);
    });

    testWidgets('Tampil badge "Powered by Gemini 1.5 Flash"', (tester) async {
      await tester.pumpWidget(makeTestable());
      expect(find.textContaining('Gemini'), findsWidgets);
    });

    testWidgets('FR-49 | Tab "Bantu Tulis Surat" ada dan bisa di-tap', (tester) async {
      await tester.pumpWidget(makeTestable());
      expect(find.text('Bantu Tulis Surat'), findsOneWidget);
      await tester.tap(find.text('Bantu Tulis Surat'));
      await tester.pump();
    });

    testWidgets('FR-49 | Input nama anak dan topik surat ada', (tester) async {
      await tester.pumpWidget(makeTestable());
      expect(find.text('Nama Anak / Pengirim di Panti'), findsOneWidget);
      expect(
        find.text('Kabar Perkembangan / Ungkapan Terima Kasih'),
        findsOneWidget,
      );
    });

    testWidgets('FR-49 | Tombol "Buat Draf Surat dengan Gemini" ada', (tester) async {
      await tester.pumpWidget(makeTestable());
      expect(find.textContaining('Buat Draf Surat'), findsOneWidget);
    });

    testWidgets('FR-50 | Tab "Ringkas Laporan" bisa diklik', (tester) async {
      await tester.pumpWidget(makeTestable());
      await tester.tap(find.text('Ringkas Laporan'));
      await tester.pumpAndSettle();
      expect(find.text('Ringkas Laporan Perkembangan Anak'), findsOneWidget);
    });

    testWidgets('FR-50 | Input teks laporan ada di tab Ringkas', (tester) async {
      await tester.pumpWidget(makeTestable());
      await tester.tap(find.text('Ringkas Laporan'));
      await tester.pumpAndSettle();
      expect(find.text('Teks Laporan dari Pengurus Panti'), findsOneWidget);
    });

    testWidgets('FR-51 | Tab "Tanya FAQ" ada', (tester) async {
      await tester.pumpWidget(makeTestable());
      expect(find.text('Tanya FAQ'), findsOneWidget);
      await tester.tap(find.text('Tanya FAQ'));
      await tester.pumpAndSettle();
    });

    testWidgets('FR-51 | Pesan welcome dari Sahabat Asuh muncul', (tester) async {
      await tester.pumpWidget(makeTestable());
      await tester.tap(find.text('Tanya FAQ'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sahabat Asuh'), findsWidgets);
    });

    testWidgets('FR-51 | TextField input FAQ dan tombol kirim ada', (tester) async {
      await tester.pumpWidget(makeTestable());
      await tester.tap(find.text('Tanya FAQ'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('FR-51 | Input teks FAQ dan tap send menambah bubble user', (tester) async {
      await tester.pumpWidget(
        makeTestable(
          faqAnswerProvider: (question, {history}) async =>
              'Jawaban uji untuk $question.',
        ),
      );
      await tester.tap(find.text('Tanya FAQ'));
      await tester.pumpAndSettle();


      final inputField = find.byType(TextField).last;
      await tester.enterText(inputField, 'Bagaimana cara donasi?');
      await tester.pump();


      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();


      expect(find.text('Bagaimana cara donasi?'), findsOneWidget);
    });
  });
}
