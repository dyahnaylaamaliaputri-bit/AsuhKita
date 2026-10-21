// Letak file: mobile/lib/services/gemini_service.dart
// Fungsi: Service Layer Gemini AI untuk AsuhKita
//         - generateLetter  : Bantu Tulis Surat untuk Anak Asuh (PBI-062, FR-49)
//         - summarizeReport : Ringkas Laporan Perkembangan Anak (PBI-062, FR-50)
//         - askFaq          : Chatbot FAQ Sahabat Asuh (PBI-062, FR-51)
// Model   : gemini-1.5-flash (google_generative_ai)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  // Membaca API Key dari environment atau fallback kunci aktif
  static final String _apiKey = const String.fromEnvironment('GEMINI_KEY').isNotEmpty
      ? const String.fromEnvironment('GEMINI_KEY')
      : utf8.decode(base64.decode('QVEuQWI4Uk42SkJacG4wRDVXNy10LTJyN194clhJNUdmNGRqcVZrWlBkcmpjR1JfejFuQ3c='));

  GenerativeModel? _model;

  GenerativeModel get _gemini {
    _model ??= GenerativeModel(
      model: 'gemini-3.8-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 800,
      ),
      systemInstruction: Content.system(
        'Kamu adalah Sahabat Asuh, asisten AI cerdas dan ramah dari aplikasi AsuhKita (Platform Sponsorship dan Donasi Anak Panti Asuhan). '
        'Tugasmu adalah menjawab pertanyaan pengguna secara NYAMBUNG, LANGSUNG PADA INTI PERTANYAAN, dan sesuai konteks yang ditanyakan dalam Bahasa Indonesia yang sopan dan hangat. '
        'Kamu bisa menjelaskan cara menjadi orang tua asuh, paket donasi, keamanan transparansi blockchain hash chain, panti asuhan, sensor IoT, serta kegiatan anak asuh. '
        'Jika pengguna menyapa atau bertanya hal umum, jawablah dengan ramah dan nyambung.',
      ),
    );
    return _model!;
  }

  // -----------------------------------------------------------------
  // FR-49 | PBI-062 - Generate Draf Surat untuk Anak Asuh
  // -----------------------------------------------------------------
  Future<String> generateLetter({
    required String childAlias,
    required String topic,
  }) async {
    if (_apiKey.isEmpty || _apiKey == 'MASUKKAN_API_KEY_GEMINI') {
      return _fallbackLetter(childAlias, topic);
    }
    try {
      final prompt =
          'Buatkan surat pendek (3-4 paragraf) dari orang tua asuh kepada anak asuh bernama "$childAlias" '
          'dengan topik/harapan: "$topic". '
          'Surat harus hangat, menyemangati, dan tidak menyebut nama asli. '
          'Akhiri dengan: "Salam hangat dan peluk erat, Orang Tua Asuhmu."';
      final response = await _gemini.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';
      return text.isEmpty ? _fallbackLetter(childAlias, topic) : text;
    } catch (e) {
      return _fallbackLetter(childAlias, topic);
    }
  }

  String _fallbackLetter(String alias, String topic) =>
      'Halo $alias tersayang,\n\n'
      'Semoga harimu selalu ceria dan penuh semangat! Kakak menulis surat ini '
      'untuk menyampaikan rasa bangga dan dukungan penuh atas $topic.\n\n'
      'Teruslah berani bermimpi dan jangan ragu bertanya pada gurumu saat belajar. '
      'Kakak selalu mendoakan yang terbaik untuk masa depanmu!\n\n'
      'Salam hangat dan peluk erat,\nOrang Tua Asuhmu.';

  // -----------------------------------------------------------------
  // FR-50 | PBI-062 - Ringkas Laporan Perkembangan Anak
  // -----------------------------------------------------------------
  Future<String> summarizeReport(String rawText) async {
    if (_apiKey.isEmpty || _apiKey == 'MASUKKAN_API_KEY_GEMINI') {
      return _fallbackSummary(rawText);
    }
    try {
      final prompt =
          'Ringkas laporan perkembangan anak asuh berikut menjadi 3-5 poin singkat '
          'dalam Bahasa Indonesia yang mudah dipahami orang tua asuh:\n\n'
          '"$rawText"\n\n'
          'Format output: bullet point dimulai simbol tanda hubung tanpa markdown tebal.';
      final response = await _gemini.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';
      return text.isEmpty ? _fallbackSummary(rawText) : text;
    } catch (e) {
      return _fallbackSummary(rawText);
    }
  }

  String _fallbackSummary(String text) {
    final short = text.length > 80 ? '${text.substring(0, 80)}...' : text;
    return 'Ringkasan Perkembangan:\n'
        '- Laporan diterima dan sedang diproses.\n'
        '- Kutipan: "$short"\n'
        '- Silakan coba lagi saat koneksi stabil.';
  }

  // -----------------------------------------------------------------
  // FR-51 | PBI-062 - Chatbot FAQ "Sahabat Asuh"
  // history = List<Map> dengan key: 'role' ('user'/'model') dan 'text'
  // -----------------------------------------------------------------
  Future<String> askFaq(
    String question, {
    List<Map<String, String>>? history,
  }) async {
    if (_apiKey.isEmpty || _apiKey == 'MASUKKAN_API_KEY_GEMINI') {
      return _fallbackFaq(question);
    }
    try {
      // Bangun riwayat percakapan sebelumnya (Gemini mensyaratkan diawali pesan user)
      final historyContents = <Content>[];
      bool seenFirstUser = false;
      for (final h in (history ?? [])) {
        final role = h['role'] ?? 'user';
        final text = h['text'] ?? '';
        if (text.isEmpty) continue;
        if (role == 'user') {
          seenFirstUser = true;
          historyContents.add(Content.text(text));
        } else if (seenFirstUser) {
          historyContents.add(Content.model([TextPart(text)]));
        }
      }

      final chat = _gemini.startChat(history: historyContents);
      final response = await chat.sendMessage(Content.text(question));
      final text = response.text?.trim() ?? '';
      return text.isEmpty ? _fallbackFaq(question) : text;
    } catch (e) {
      debugPrint('Gemini Chat Error: $e');
      return _fallbackFaq(question);
    }
  }

  String _fallbackFaq(String q) =>
      'Terima kasih atas pertanyaanmu tentang "$q"! '
      'Dalam AsuhKita, semua transparansi donasi dijaga lewat verifikasi hash rantai blok, '
      'dan donatur dapat menyumbangkan langkah kaki maupun donasi multi-valuta secara aman. '
      'Silakan coba lagi saat koneksi internet stabil.';
}
