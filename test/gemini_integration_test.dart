// TEST-05 | Integration Test: GeminiService (letter + summary + FAQ)
// Menguji: FR-49, FR-50, FR-51 (PBI-062)
// Mode : Tanpa API key nyata ? memverifikasi fallback berjalan sempurna
//         Untuk tes dengan API key nyata: jalankan dengan
//         flutter test --dart-define=GEMINI_KEY=AIzaSy...

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/gemini_service.dart';

void main() {
  final gemini = GeminiService();

  group('FR-49 | GeminiService.generateLetter (Fallback Mode)', () {
    test('Mengembalikan string tidak kosong untuk nama dan topik valid', () async {
      final result = await gemini.generateLetter(
        childAlias: 'Bintang',
        topic: 'semangat belajar untuk ujian',
      );
      expect(result.isNotEmpty, isTrue,
          reason: 'generateLetter harus mengembalikan teks (fallback atau Gemini)');
    });

    test('Surat mengandung nama alias anak', () async {
      final result = await gemini.generateLetter(
        childAlias: 'Langit',
        topic: 'dukungan cita-cita',
      );
      expect(result.contains('Langit'), isTrue,
          reason: 'Fallback letter harus menyebut nama alias anak');
    });

    test('Surat selalu diakhiri tanda tangan orang tua asuh', () async {
      final result = await gemini.generateLetter(
        childAlias: 'Rizki',
        topic: 'prestasi akademik',
      );
      expect(result.toLowerCase().contains('orang tua asuh'), isTrue,
          reason: 'Surat harus mengandung tanda tangan standar');
    });
  });

  group('FR-50 | GeminiService.summarizeReport (Fallback Mode)', () {
    test('Mengembalikan ringkasan tidak kosong', () async {
      const rawReport =
          'Selama semester ganjil, Bintang menunjukkan peningkatan signifikan pada pelajaran IPA dengan nilai 90.';
      final result = await gemini.summarizeReport(rawReport);
      expect(result.isNotEmpty, isTrue);
    });

    test('Ringkasan fallback mengandung kata "Ringkasan"', () async {
      final result = await gemini.summarizeReport('Laporan singkat anak asuh.');
      expect(
        result.toLowerCase().contains('ringkasan') || result.contains('-'),
        isTrue,
        reason: 'Fallback summary harus terformat sebagai poin ringkasan',
      );
    });

    test('Teks kosong tidak menyebabkan crash', () async {
      final result = await gemini.summarizeReport('');
      expect(result.isNotEmpty, isTrue);
    });
  });

  group('FR-51 | GeminiService.askFaq (Fallback Mode)', () {
    test('Mengembalikan jawaban tidak kosong', () async {
      final result = await gemini.askFaq('Bagaimana cara berdonasi?');
      expect(result.isNotEmpty, isTrue);
    });

    test('Jawaban fallback mengandung nama "AsuhKita"', () async {
      final result = await gemini.askFaq('Apa itu AsuhKita?');
      expect(result.toLowerCase().contains('asuhkita'), isTrue,
          reason: 'Fallback FAQ harus menyebut nama aplikasi');
    });

    test('FAQ dengan riwayat chat tidak crash', () async {
      final history = [
        {'role': 'user', 'text': 'Halo'},
        {'role': 'model', 'text': 'Halo juga! Ada yang bisa saya bantu?'},
      ];
      final result = await gemini.askFaq('Berapa nominal donasi minimum?',
          history: history);
      expect(result.isNotEmpty, isTrue);
    });

    test('Pertanyaan kosong tidak menyebabkan crash', () async {
      // Meski string kosong dikirim, service harus mengembalikan string
      final result = await gemini.askFaq('');
      expect(result, isA<String>());
    });
  });
}
