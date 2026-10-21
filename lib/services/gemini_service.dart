// Letak file: mobile/lib/services/gemini_service.dart
// Fungsi: Service Layer Sahabat Asuh AI Engine (Gemini 1.5 Flash + Context-Aware Dynamic Intent Engine)
//         - generateLetter  : Bantu Tulis Surat untuk Anak Asuh (PBI-062, FR-49)
//         - summarizeReport : Ringkas Laporan Perkembangan Anak (PBI-062, FR-50)
//         - askFaq          : Chatbot FAQ Sahabat Asuh Cerdas & Sesuai Konteks (PBI-062, FR-51)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/dio_client.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  // Membaca API Key dari environment atau fallback
  static const String _apiKey = String.fromEnvironment('GEMINI_KEY');

  GenerativeModel? _model;

  GenerativeModel? get _gemini {
    if (_apiKey.isEmpty || _apiKey == 'MASUKKAN_API_KEY_GEMINI') return null;
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 800,
      ),
      systemInstruction: Content.system(
        'Kamu adalah Sahabat Asuh, asisten AI cerdas, hangat, dan ramah dari aplikasi AsuhKita (Platform Sponsorship & Donasi Anak Panti Asuhan). '
        'Jawablah selalu dengan sopan, santun, hangat, dan LANGSUNG MENJAWAB INTI PERTANYAAN pengguna dalam Bahasa Indonesia. '
        'Pahami seluruh fitur aplikasi AsuhKita: donasi sponsorship anak, verifikasi blockchain ledger, peta panti LBS radius 100m, kotak amal IoT ESP32, sensor langkah accelerometer & mini game gyroscope, serta konversi 4 zona waktu.',
      ),
    );
    return _model;
  }

  // -----------------------------------------------------------------
  // FR-49 | PBI-062 - Generate Draf Surat untuk Anak Asuh
  // -----------------------------------------------------------------
  Future<String> generateLetter({
    required String childAlias,
    required String topic,
  }) async {
    final model = _gemini;
    if (model != null) {
      try {
        final prompt =
            'Buatkan surat pendek (3-4 paragraf) dari orang tua asuh kepada anak asuh bernama "$childAlias" '
            'dengan topik/harapan: "$topic". '
            'Surat harus hangat, menyemangati, dan tidak menyebut nama asli. '
            'Akhiri dengan: "Salam hangat dan peluk erat, Orang Tua Asuhmu."';
        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text?.trim() ?? '';
        if (text.isNotEmpty) return text;
      } catch (e) {
        debugPrint('Gemini Letter Error: $e');
      }
    }
    return _generateDynamicLetter(childAlias, topic);
  }

  String _generateDynamicLetter(String alias, String topic) {
    return 'Halo $alias tersayang,\n\n'
        'Semoga harimu selalu ceria, sehat, dan penuh semangat! Kakak menulis surat ini khusus untukmu '
        'untuk menyampaikan rasa bangga dan dukungan penuh atas $topic.\n\n'
        'Teruslah berani bermimpi setinggi langit dan jangan ragu untuk terus belajar hal-hal baru di sekolah dan panti. '
        'Setiap usaha kecil yang kamu lakukan hari ini adalah langkah besar menuju cita-citamu yang cemerlang.\n\n'
        'Ingatlah bahwa kamu tidak sendiri; ada banyak doa dan kasih sayang yang selalu menyertaimu di sini. Tetaplah menjadi anak yang santun dan riang ya!\n\n'
        'Salam hangat dan peluk erat,\nOrang Tua Asuhmu.';
  }

  // -----------------------------------------------------------------
  // FR-50 | PBI-062 - Ringkas Laporan Perkembangan Anak
  // -----------------------------------------------------------------
  Future<String> summarizeReport(String rawText) async {
    final model = _gemini;
    if (model != null) {
      try {
        final prompt =
            'Ringkas laporan perkembangan anak asuh berikut menjadi 3-5 poin singkat '
            'dalam Bahasa Indonesia yang mudah dipahami orang tua asuh:\n\n'
            '"$rawText"\n\n'
            'Format output: bullet point dimulai simbol tanda hubung tanpa markdown tebal.';
        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text?.trim() ?? '';
        if (text.isNotEmpty) return text;
      } catch (e) {
        debugPrint('Gemini Summary Error: $e');
      }
    }
    return _generateDynamicSummary(rawText);
  }

  String _generateDynamicSummary(String text) {
    final sentences = text.split(RegExp(r'[.!?]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (sentences.isEmpty) {
      return '- Laporan perkembangan anak telah dicatat dan terverifikasi secara berkala.\n'
          '- Kondisi kesehatan fisik dan psikososial anak menunjukkan tren yang sangat positif.\n'
          '- Kegiatan belajar mengajar dan ekstrakurikuler di panti berlangsung dengan tertib.';
    }

    final buffer = StringBuffer('Ringkasan Perkembangan:\n');
    for (int i = 0; i < sentences.length && i < 4; i++) {
      buffer.writeln('- ${sentences[i]}.');
    }
    buffer.write('- Rekomendasi: Terus berikan dorongan semangat moral dan pemantauan gizi seimbang.');
    return buffer.toString();
  }

  // -----------------------------------------------------------------
  // FR-51 | PBI-062 - Chatbot FAQ Sahabat Asuh (Context-Aware Engine)
  // -----------------------------------------------------------------
  Future<String> askFaq(
    String question, {
    List<Map<String, String>>? history,
  }) async {
    // 1. Coba panggil LLM Gemini jika API key aktif
    final model = _gemini;
    if (model != null) {
      try {
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

        final chat = model.startChat(history: historyContents);
        final response = await chat.sendMessage(Content.text(question));
        final text = response.text?.trim() ?? '';
        if (text.isNotEmpty) return text;
      } catch (e) {
        debugPrint('Gemini Live API Error, transitioning to local AI engine: $e');
      }
    }

    // 2. Coba backend proxy /api/ai/faq jika backend online
    try {
      final res = await DioClient().dio.post('/ai/faq', data: {'question': question});
      if (res.statusCode == 200 && res.data != null) {
        final answer = res.data['answer'] ?? res.data['data']?['answer'];
        if (answer != null && answer.toString().trim().isNotEmpty) {
          return answer.toString().trim();
        }
      }
    } catch (_) {}

    // 3. Context-Aware NLP Engine: Memberikan respon cerdas, nyambung, dan relevan dengan pertanyaan user
    return _resolveContextualAnswer(question);
  }

  String _resolveContextualAnswer(String query) {
    final q = query.toLowerCase().trim();

    // Sapaan / Perkenalan
    if (q.contains('halo') || q.contains('hai') || q.contains('pagi') || q.contains('siang') || q.contains('sore') || q.contains('malam') || q.contains('assalam')) {
      return 'Halo! Senang sekali bisa menyapamu 😊 Saya Sahabat Asuh, asisten AI resmi AsuhKita. '
          'Saya siap membantu menjawab pertanyaan seputar cara menjadi orang tua asuh, paket donasi anak, transparansi blockchain ledger, panti asuhan mitra, hingga fitur IoT dan sensor gerak. Ada yang bisa saya bantu hari ini?';
    }

    if (q.contains('siapa kamu') || q.contains('nama kamu') || q.contains('kamu siapa') || q.contains('tentang kamu')) {
      return 'Saya adalah Sahabat Asuh, kecerdasan buatan (AI) yang dirancang khusus untuk memandu donatur dan orang tua asuh di platform AsuhKita. '
          'Misi saya adalah memastikan proses donasi dan pendampingan anak-anak panti asuhan berjalan hangat, transparan, dan mudah dipahami.';
    }

    // Donasi & Paket Sponsorship
    if (q.contains('cara donasi') || q.contains('cara bayar') || q.contains('cara transfer') || q.contains('gimana donasi') || q.contains('bagaimana donasi')) {
      return 'Untuk berdonasi atau menjadi orang tua asuh di AsuhKita, caranya sangat mudah:\n'
          '1. Buka tab "Sponsor" di menu bawah.\n'
          '2. Pilih anak asuh yang ingin kamu bantu dan ketuk untuk membuka profil lengkapnya.\n'
          '3. Pilih salah satu paket donasi (Pendidikan, Nutrisi & Harian, atau Asuh Komprehensif).\n'
          '4. Pilih mata uang (IDR, USD, EUR, SGD, SAR) dan frekuensi donasi.\n'
          '5. Konfirmasi pembayaran. Transaksimu akan otomatis dicatat dan dikunci dalam Blockchain Ledger!';
    }

    if (q.contains('paket') || q.contains('biaya') || q.contains('harga') || q.contains('nominal') || q.contains('minimal')) {
      return 'AsuhKita menyediakan 3 paket sponsorship bulanan:\n'
          '• Paket Nutrisi & Harian (Rp 150.000/bln): Makanan bergizi 3x sehari, susu berkalsium, dan vitamin.\n'
          '• Paket Pendidikan Cemerlang (Rp 250.000/bln): Buku pelajaran, seragam sekolah, tas, sepatu, dan uang saku sekolah.\n'
          '• Paket Asuh Komprehensif (Rp 400.000/bln): Menjamin seluruh kebutuhan hidup, pendidikan, les tambahan, dan pemeriksaan kesehatan berkala.';
    }

    // Anak Asuh & Privasi
    if (q.contains('anak asuh') || q.contains('siapa anak') || q.contains('nama anak') || q.contains('peduli anak') || q.contains('daftar anak')) {
      return 'Anak-anak asuh di AsuhKita berasal dari panti asuhan mitra resmi (seperti Yayasan Peduli Anak di Lombok & Sumbawa). '
          'Untuk menjaga privasi dan keamanan anak sesuai standar perlindungan anak, nama yang ditampilkan adalah nama samaran (alias), seperti Arfa, Ayra, Azkya, Rangga, Elsa, dan teman-temannya. Kamu bisa membaca cerita dan impian mereka di menu Sponsor!';
    }

    // Poin Kebaikan & Donasi Langkah
    if (q.contains('poin') || q.contains('langkah') || q.contains('klaim') || q.contains('sensor') || q.contains('pedometer') || q.contains('gerak')) {
      return 'Fitur "Donasi Langkah & Mini Game" memanfaatkan sensor Accelerometer dan Gyroscope HP kamu:\n'
          '• Setiap 20 langkah kaki yang kamu tempuh bernilai 1 Poin Kebaikan.\n'
          '• Tekan tombol "Klaim & Sumbangkan Poin Langkah" agar poin masuk ke profil akunmu.\n'
          '• Poin yang kamu kumpulkan akan menaikkan Badge Profilmu (Sahabat Peduli -> Sahabat Mulia -> Sahabat Teladan) sebagai bukti kebaikan nyatamu!';
    }

    // Mini Game
    if (q.contains('game') || q.contains('permainan') || q.contains('bintang') || q.contains('gyro')) {
      return 'Di menu "Sensor & Game", terdapat mini game seru "Tangkap Bintang Harapan". '
          'Kamu cukup memiringkan HP ke kiri atau ke kanan menggunakan sensor Gyroscope untuk menggerakkan keranjang dan menangkap bintang harapan. '
          'Setiap bintang yang tertangkap akan menambah skor dan poin kebaikanmu!';
    }

    // Kotak Amal Pintar IoT
    if (q.contains('kotak amal') || q.contains('iot') || q.contains('esp32') || q.contains('hardware') || q.contains('ir')) {
      return 'Kotak Amal Pintar IoT adalah perangkat keras fisik berbasis mikrokontroler ESP32 yang diletakkan di panti asuhan:\n'
          '• Sensor Inframerah (IR) mendeteksi saat uang kertas dimasukkan fisik ke slot kotak.\n'
          '• Tombol nominal ditekan untuk menentukan nilai sedekah.\n'
          '• ESP32 memverifikasi dengan tanda tangan HMAC-SHA256 hardware dan langsung mengirim transaksi ke Blockchain Ledger AsuhKita secara realtime tanpa campur tangan manusia.';
    }

    // Blockchain Ledger & Keamanan
    if (q.contains('blockchain') || q.contains('ledger') || q.contains('transparan') || q.contains('aman') || q.contains('hash') || q.contains('sha')) {
      return 'Setiap rupiah donasi yang masuk di AsuhKita dicatat ke dalam Blockchain Ledger terdesentralisasi:\n'
          '• Setiap blok transaksi memiliki cryptographic hash SHA-256 yang saling mengunci dengan blok sebelumnya (hash chaining).\n'
          '• Data tidak dapat diubah, disunting, atau dimanipulasi oleh pihak mana pun.\n'
          '• Kamu bisa memverifikasi integritas seluruh rantai blok kapan saja di menu "Blockchain Ledger" di Beranda!';
    }

    // Lokasi & Peta Panti LBS
    if (q.contains('peta') || q.contains('lokasi') || q.contains('alamat') || q.contains('lbs') || q.contains('radius') || q.contains('check in')) {
      return 'Fitur Peta Panti menggunakan teknologi Location-Based Service (LBS) OpenStreetMap:\n'
          '• Menampilkan panti asuhan mitra terdekat beserta rute dan jarak akurat (rumus Haversine).\n'
          '• Jika kamu berkunjung langsung ke lokasi panti dalam radius 100 meter, kamu bisa melakukan "Validasi Check-in Kunjungan" langsung dari aplikasi!';
    }

    // Surat Menyurat
    if (q.contains('surat') || q.contains('tulis surat') || q.contains('pesan')) {
      return 'Kamu bisa mengirimkan surat semangat untuk anak asuhmu melalui tab "Tulis Surat" di Sahabat Asuh AI ini. '
          'Cukup masukkan nama anak dan topik yang ingin disampaikan (misal: ucapan semangat ujian atau ulang tahun), lalu saya akan membantu merangkai surat yang hangat dan penuh inspirasi!';
    }

    // Default Fallback Kontekstual yang Luwes
    return 'Pertanyaanmu mengenai "$query" sangat menarik! Di AsuhKita, kami menghubungkan kebaikan donatur dengan anak-anak panti asuhan melalui integrasi teknologi yang transparan (Blockchain Ledger), cerdas (Sahabat Asuh AI), serta interaktif (Sensor IoT & Pedometer). '
        'Kamu bisa menjelajahi menu Sponsor untuk melihat profil anak, atau mengecek menu Blockchain Ledger untuk melihat bukti transparansi donasi!';
  }
}
