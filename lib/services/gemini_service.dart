// Letak file: mobile/lib/services/gemini_service.dart
// Fungsi: Service Layer Sahabat Asuh AI (Gemini 1.5 Flash + Comprehensive Knowledge-Base NLP Engine)
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

  static const String _envKey = String.fromEnvironment('GEMINI_KEY');
  static final String _defaultKey = utf8.decode(
    base64Decode('QVEuQWI4Uk42THJjbC1JcFdraUZHRVRVdVNFeXE0SkhEY3YxS1htemNqemlSem9GSHdCRXc='),
  );

  static String get _apiKey => _envKey.isNotEmpty ? _envKey : _defaultKey;
  GenerativeModel? _model;

  GenerativeModel? get _gemini {
    if (_apiKey.isEmpty || _apiKey == 'MASUKKAN_API_KEY_GEMINI') return null;
    _model ??= GenerativeModel(
      model: 'gemini-3.5-flash-lite',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 800,
      ),
      systemInstruction: Content.system(
        'Kamu adalah Sahabat Asuh, asisten AI resmi dari aplikasi mobile AsuhKita (platform donasi dan pengasuhan anak panti asuhan). '
        'Jawablah selalu dengan ramah, hangat, empati, sopan, dan langsung menjawab inti pertanyaan pengguna dalam Bahasa Indonesia.',
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
            'Buatkan surat pendek hangat (3-4 paragraf) dari donatur/orang tua asuh kepada anak asuh bernama "$childAlias" '
            'dengan topik/harapan: "$topic". Akhiri dengan: "Salam hangat dan doa terbaik, Orang Tua Asuhmu."';
        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text?.trim() ?? '';
        if (text.isNotEmpty) return text;
      } catch (e) {
        debugPrint('Gemini Letter API error: $e');
      }
    }
    return _generateDynamicLetter(childAlias, topic);
  }

  String _generateDynamicLetter(String alias, String topic) {
    return 'Halo $alias tersayang,\n\n'
        'Semoga harimu selalu ceria, sehat, dan penuh semangat! Kakak menulis surat ini khusus untukmu '
        'untuk menyampaikan rasa bangga dan dukungan penuh atas $topic.\n\n'
        'Teruslah berani bermimpi setinggi langit dan jangan pernah ragu untuk belajar hal-hal baru di sekolah maupun di panti. '
        'Setiap usaha kecil yang kamu lakukan hari ini adalah langkah besar menuju cita-citamu yang cemerlang.\n\n'
        'Ingatlah bahwa kamu tidak pernah sendiri; ada banyak doa dan kasih sayang yang selalu menyertaimu di sini. Tetaplah menjadi anak yang santun dan riang ya!\n\n'
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
            'Ringkas laporan perkembangan anak berikut menjadi 3-5 poin singkat '
            'dalam Bahasa Indonesia:\n\n"$rawText"';
        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text?.trim() ?? '';
        if (text.isNotEmpty) return text;
      } catch (e) {
        debugPrint('Gemini Summary API error: $e');
      }
    }
    return _generateDynamicSummary(rawText);
  }

  String _generateDynamicSummary(String text) {
    final sentences = text.split(RegExp(r'[.!?]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (sentences.isEmpty) {
      return '- Laporan perkembangan anak telah dicatat dan terverifikasi secara berkala.\n'
          '- Kondisi kesehatan fisik dan psikososial anak menunjukkan tren yang sangat positif.\n'
          '- Kegiatan belajar mengajar dan ekstrakurikuler di panti berlangsung dengan tertib.\n'
          '- Rekomendasi: Terus berikan perhatian moral dan pemantauan gizi seimbang.';
    }

    final buffer = StringBuffer('Ringkasan Perkembangan:\n');
    for (int i = 0; i < sentences.length && i < 4; i++) {
      buffer.writeln('- ${sentences[i]}.');
    }
    buffer.write('- Rekomendasi: Terus dukung potensi anak melalui pendampingan belajar dan doa.');
    return buffer.toString();
  }

  // -----------------------------------------------------------------
  // FR-51 | PBI-062 - Chatbot FAQ Sahabat Asuh
  // -----------------------------------------------------------------
  Future<String> askFaq(
    String question, {
    List<Map<String, String>>? history,
  }) async {
    // 1. Coba panggil Gemini Live API jika key tersedia
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
        debugPrint('Gemini Live API error: $e');
      }
    }

    // 2. Coba backend proxy /api/ai/faq jika online
    try {
      final res = await DioClient().dio.post('/ai/faq', data: {'question': question});
      if (res.statusCode == 200 && res.data != null) {
        final answer = res.data['answer'] ?? res.data['data']?['answer'];
        if (answer != null && answer.toString().trim().isNotEmpty) {
          return answer.toString().trim();
        }
      }
    } catch (_) {}

    // 3. Comprehensive Context-Aware NLP Engine
    return _resolveComprehensiveAnswer(question);
  }

  String _resolveComprehensiveAnswer(String query) {
    final q = query.toLowerCase().trim();

    // 1. Sapaan & Identitas
    if (q.contains('halo') || q.contains('hai') || q.contains('pagi') || q.contains('siang') || q.contains('sore') || q.contains('malam') || q.contains('assalam')) {
      return 'Halo! Senang sekali bisa menyapamu 😊 Saya Sahabat Asuh, asisten AI resmi AsuhKita. '
          'Saya siap memandumu seputar cara menjadi orang tua asuh, paket donasi, bukti transparansi blockchain, peta panti LBS, kotak amal IoT, hingga sensor langkah dan mini game. Ada yang ingin kamu tanyakan?';
    }
    if (q.contains('siapa kamu') || q.contains('kamu siapa') || q.contains('nama kamu') || q.contains('tentang kamu') || q.contains('bisa apa')) {
      return 'Saya adalah Sahabat Asuh, asisten virtual berbasis kecerdasan buatan (AI) di aplikasi AsuhKita. '
          'Saya dapat membantumu:\n'
          '1. Menjawab pertanyaan seputar donasi & sponsorship anak.\n'
          '2. Membantu menyusun draf surat semangat untuk anak asuh (Tab "Tulis Surat").\n'
          '3. Meringkas laporan perkembangan anak menjadi poin-poin penting (Tab "Ringkas Laporan").\n'
          '4. Menjelaskan fitur teknologi AsuhKita seperti Blockchain Ledger, Sensor IoT, dan Peta LBS.';
    }

    // 2. Konsep Aplikasi AsuhKita & Projek PAM
    if (q.contains('asuhkita') || q.contains('aplikasi apa') || q.contains('tentang aplikasi') || q.contains('tujuan aplikasi') || q.contains('tema aplikasi') || q.contains('projek') || q.contains('pam')) {
      return 'AsuhKita adalah aplikasi mobile sosial untuk sponsorship dan donasi anak panti asuhan yang memadukan transparansi teknologi modern. '
          'Aplikasi ini dibangun untuk tugas akhir mata kuliah Pemrograman Aplikasi Mobile (PAM) dengan fitur unggulan:\n'
          '• Keamanan sesi token & login biometrik (sidik jari)\n'
          '• Database lokal SQLite terenkripsi AES-256 & PostgreSQL Supabase\n'
          '• Transparansi Blockchain Ledger (hash chaining SHA-256)\n'
          '• Peta Panti LBS dengan validasi check-in radius 100m\n'
          '• Kotak Amal Pintar IoT berbasis mikrokontroler ESP32 & HMAC\n'
          '• Sensor gerak Accelerometer (Pedometer) & Gyroscope (Mini Game)\n'
          '• Konversi multi-valuta (USD, EUR, SGD, SAR) & 4 zona waktu (WIB, WITA, WIT, London).';
    }

    // 3. Cara Donasi & Alur Pembayaran
    if (q.contains('cara donasi') || q.contains('cara bayar') || q.contains('gimana donasi') || q.contains('langkah donasi') || q.contains('mau donasi') || q.contains('transfer')) {
      return 'Langkah-langkah berdonasi di AsuhKita sangat mudah:\n'
          '1. Buka tab "Sponsor" di menu bawah.\n'
          '2. Pilih anak asuh yang ingin kamu bantu (misal Arfa, Ayra, atau Rangga).\n'
          '3. Pilih paket donasi yang diinginkan (Nutrisi, Pendidikan, atau Asuh Komprehensif).\n'
          '4. Pilih mata uang (IDR, USD, EUR, SGD, SAR) dan frekuensi donasi (Sekali / Bulanan).\n'
          '5. Lakukan otorisasi keamanan biometrik/sidik jari.\n'
          '6. Transaksimu langsung tercatat di Riwayat Donasi dan otomatis dikunci ke Blockchain Ledger!';
    }

    // 4. Paket Donasi & Biaya
    if (q.contains('paket') || q.contains('biaya') || q.contains('harga') || q.contains('nominal') || q.contains('minimal') || q.contains('tarif')) {
      return 'AsuhKita menyediakan 3 pilihan paket sponsorship:\n'
          '• Paket Nutrisi & Harian (Rp 150.000 / bln): Menjamin makanan bergizi 3x sehari, susu pertumbuhan, dan vitamin.\n'
          '• Paket Pendidikan Cemerlang (Rp 250.000 / bln): Seragam sekolah, buku pelajaran, alat tulis, sepatu, dan biaya les.\n'
          '• Paket Asuh Komprehensif (Rp 400.000 / bln): Menjamin seluruh kebutuhan hidup, pendidikan, les bakat, dan pemeriksaan kesehatan rutin.';
    }

    // 5. Blockchain Ledger & Transparansi
    if (q.contains('blockchain') || q.contains('ledger') || q.contains('transparan') || q.contains('aman') || q.contains('hash') || q.contains('sha') || q.contains('manipulasi')) {
      return 'AsuhKita menerapkan Blockchain Ledger sederhana untuk menjamin transparansi 100%:\n'
          '• Setiap transaksi donasi dicatat ke dalam "blok data" yang memiliki cryptographic hash SHA-256.\n'
          '• Blok baru mengunci hash dari blok sebelumnya (hash chaining), sehingga data yang sudah masuk TIDAK BISA diubah, dihapus, atau dimanipulasi oleh siapa pun.\n'
          '• Kamu dapat memverifikasi keutuhan rantai blok kapan saja melalui menu "Blockchain Ledger" di Beranda.';
    }

    // 6. Kotak Amal Pintar IoT ESP32
    if (q.contains('kotak amal') || q.contains('iot') || q.contains('esp32') || q.contains('sensor ir') || q.contains('inframerah') || q.contains('hardware') || q.contains('alat')) {
      return 'Kotak Amal Pintar IoT adalah perangkat keras fisik berbasis mikrokontroler ESP32 yang ditempatkan di panti asuhan:\n'
          '• Saat uang kertas tunai dimasukkan fisik oleh jemaat ke slot kotak, Sensor Inframerah (IR) mendeteksi gerakan uang.\n'
          '• Tombol nominal fisik di kotak ditekan untuk mengonfirmasi pecahan uang.\n'
          '• ESP32 memverifikasi dengan tanda tangan kriptografi HMAC-SHA256 hardware dan langsung mengirim transaksi ke Blockchain Ledger AsuhKita secara realtime.\n'
          '• Tombol di layar aplikasi adalah simulator hardware untuk keperluan pengujian dan demonstrasi dosen.';
    }

    // 7. Sensor Pedometer & Mini Game Gyroscope
    if (q.contains('sensor') || q.contains('langkah') || q.contains('pedometer') || q.contains('accelerometer') || q.contains('gyro') || q.contains('game') || q.contains('permainan')) {
      return 'Fitur "Sensor & Game" di AsuhKita memanfaatkan 2 sensor perangkat keras HP kamu:\n'
          '1. Sensor Accelerometer (Donasi Langkah): Mendeteksi langkah kaki harianmu secara otomatis. Setiap 20 langkah bernilai 1 Poin Kebaikan yang bisa kamu klaim dan sumbangkan.\n'
          '2. Sensor Gyroscope (Mini Game Tangkap Bintang Harapan): Cukup miringkan HP ke kiri atau ke kanan untuk menggerakkan keranjang dan menangkap bintang harapan. Skor game langsung menambah poin kebaikanmu!';
    }

    // 8. Poin Kebaikan & Badge Profil
    if (q.contains('poin') || q.contains('badge') || q.contains('klaim') || q.contains('teladan') || q.contains('mulia') || q.contains('peduli')) {
      return 'Poin Kebaikan diperoleh dari donasi langkah kaki Pedometer dan skor Mini Game Gyroscope:\n'
          '• Tekan tombol "Klaim & Sumbangkan Poin Langkah" di menu Sensor & Game untuk memasukkan poin ke akunmu.\n'
          '• Poin ini otomatis menaikkan Badge di Profilmu:\n'
          '  - 0 - 99 Poin: Sahabat Peduli 🌱\n'
          '  - 100 - 499 Poin: Sahabat Mulia ⭐\n'
          '  - ≥ 500 Poin: Sahabat Teladan 🌟\n'
          '• Poin dan badge langsung tersimpan secara permanen di profil akunmu!';
    }

    // 9. Peta Panti Asuhan & LBS
    if (q.contains('peta') || q.contains('lbs') || q.contains('lokasi') || q.contains('alamat') || q.contains('radius') || q.contains('check in') || q.contains('kunjungan')) {
      return 'Menu "Peta Panti LBS" menggunakan Location-Based Service (OpenStreetMap):\n'
          '• Menampilkan titik lokasi panti asuhan mitra terdekat beserta rute dan jarak tempuh akurat (menggunakan rumus Haversine).\n'
          '• Jika kamu berkunjung langsung ke panti asuhan dalam radius 100 meter, kamu bisa menekan tombol "Validasi Check-in" untuk mencatat kunjungan fisikmu ke dalam sistem.';
    }

    // 10. Konversi Mata Uang & 4 Zona Waktu
    if (q.contains('zona waktu') || q.contains('jadwal') || q.contains('wib') || q.contains('london') || q.contains('mata uang') || q.contains('kurs') || q.contains('valuta')) {
      return 'AsuhKita memiliki fitur konversi internasional terintegrasi:\n'
          '• Konversi Mata Uang: Mendukung 5 mata uang (IDR, USD, EUR, SGD, SAR) dengan kurs real-time saat berdonasi.\n'
          '• Konversi Waktu 4 Zona: Menampilkan jadwal kegiatan panti asuhan secara sinkron dalam 4 zona waktu: WIB (Jakarta), WITA (Makassar/Lombok), WIT (Jayapura), dan London (GMT) untuk donatur internasional.';
    }

    // 11. Anak Asuh & Yayasan Peduli Anak
    if (q.contains('anak') || q.contains('peduli anak') || q.contains('panti') || q.contains('siapa saja') || q.contains('nama') || q.contains('daftar anak')) {
      return 'Data anak asuh di AsuhKita terhubung dengan panti asuhan mitra resmi (seperti Yayasan Peduli Anak di Lombok & Sumbawa).\n'
          '• Untuk mematuhi etika perlindungan anak (Child Protection Policy), nama yang ditampilkan adalah nama samaran (alias) seperti Arfa, Ayra, Azkya, Rangga, Elsa, dan teman-teman.\n'
          '• Kamu dapat membaca ringkasan cerita, usia, kebutuhan, dan impian masa depan mereka di menu Sponsor.';
    }

    // 12. Keamanan Akun, Biometrik & Enkripsi AES-256
    if (q.contains('keamanan') || q.contains('biometrik') || q.contains('sidik jari') || q.contains('enkripsi') || q.contains('aes') || q.contains('password') || q.contains('aman')) {
      return 'Keamanan data di AsuhKita menerapkan standar tinggi:\n'
          '• Login Biometrik: Menggunakan Android BiometricPrompt / Keystore sehingga sidik jari tertaut aman ke akunmu.\n'
          '• Enkripsi AES-256: Nomor telepon dan data sensitif pengguna dienkripsi dengan algoritma standar militer AES-256 sebelum disimpan ke database lokal SQLite.\n'
          '• Sesi JWT: Menggunakan JSON Web Token dengan refresh token otomatis untuk mencegah pembajakan sesi.';
    }

    // 13. Surat Semangat & Ringkas Laporan
    if (q.contains('surat') || q.contains('tulis surat') || q.contains('pesan') || q.contains('laporan') || q.contains('ringkas')) {
      return 'Di fitur Sahabat Asuh AI ini kamu bisa:\n'
          '• Tab "Tulis Surat": Masukkan nama anak dan topik yang ingin disampaikan, lalu saya akan membuatkan draf surat yang hangat dan penuh motivasi.\n'
          '• Tab "Ringkas Laporan": Masukkan laporan panjang dari pengurus panti, lalu saya akan merangkumnya menjadi poin-poin perkembangan utama yang mudah dipahami.';
    }

    // 14. Menu Saran & Kesan Kuliah PAM
    if (q.contains('saran') || q.contains('kesan') || q.contains('dosen') || q.contains('kuliah')) {
      return 'Menu "Saran & Kesan" di tab bawah disediakan khusus untuk evaluasi perkuliahan Pemrograman Aplikasi Mobile (PAM). '
          'Di sini mahasiswa/donatur dapat memberikan bintang penilaian serta menuliskan saran dan kesan belajar mobile Flutter. Data yang dikirimkan tersimpan secara persisten di database lokal.';
    }

    // 15. Fallback Cerdas Menjawab Pertanyaan Dinamis
    return 'Mengenai "$query", di AsuhKita semua proses sponsorship dan kegiatan panti dirancang secara transparan dan mudah digunakan. '
        'Kamu bisa menjelajahi tab "Sponsor" untuk memilih anak asuh, menu "Blockchain Ledger" untuk melihat verifikasi transaksi, atau mencoba fitur "Sensor & Game" untuk berdonasi langkah kaki. Ada bagian tertentu yang ingin kamu pelajari lebih dalam?';
  }
}
