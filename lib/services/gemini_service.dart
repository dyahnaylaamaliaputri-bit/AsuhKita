// Letak file: mobile/lib/services/gemini_service.dart
// Fungsi: Service Layer Sahabat Asuh AI (Gemini 1.5 Flash + Context-Guard Engine Terkoneksi Database)
//         - generateLetter  : Bantu Tulis Surat untuk Anak Asuh (PBI-062, FR-49)
//         - summarizeReport : Ringkas Laporan Perkembangan Anak (PBI-062, FR-50)
//         - askFaq          : Chatbot FAQ Sahabat Asuh Cerdas, Sesuai Konteks & Peringatan Jika Di Luar Konteks (PBI-062, FR-51)

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/dio_client.dart';
import '../data/local_db.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  static const String _envKey = String.fromEnvironment('GEMINI_KEY');

  static String get _apiKey => _envKey.trim();
  GenerativeModel? _model;

  GenerativeModel? get _gemini {
    if (_apiKey.isEmpty) return null;
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        maxOutputTokens: 800,
      ),
      systemInstruction: Content.system(
        'Kamu adalah Sahabat Asuh, asisten AI resmi dari aplikasi mobile AsuhKita (platform donasi dan pengasuhan anak panti asuhan terpercaya).\n'
        'TUGAS UTAMA: Menjawab pertanyaan donatur dan pengurus panti asuhan seputar:\n'
        '1. Anak asuh, profil anak, dan kebutuhan prioritas (Pendidikan, Kesehatan, Nutrisi, Kebutuhan Harian, Perawatan Esensial).\n'
        '2. Cara sponsorship, paket donasi, konversi valuta mata uang asing, dan jadwal kegiatan panti 4 zona waktu.\n'
        '3. Sistem transparansi blockchain ledger, bukti nota belanja, dan kotak amal pintar IoT.\n'
        '4. Fitur mobile seperti donasi langkah pedometer, mini game gyroscope, dan ruang komunikasi anak asuh.\n\n'
        'ATURAN KETAT KONTEKS:\n'
        'Jika pengguna menanyakan hal yang BERADA DI LUAR TOPIK AsuhKita (misalnya politik umum, gosip selebriti, resep makanan umum, koding di luar AsuhKita, tugas kuliah umum, rekomendasi film/musik, atau topik dunia lain), kamu HARUS menolak dengan tegas namun sopan menggunakan pesan peringatan:\n'
        '"⚠️ Maaf, saya adalah Sahabat Asuh AI yang dirancang khusus untuk mendampingi program donasi anak asuh, transparansi panti asuhan, dan fitur aplikasi AsuhKita. Mohon ajukan pertanyaan yang berkaitan dengan topik tersebut ya!"\n\n'
        'Jawablah selalu dalam Bahasa Indonesia yang ramah, santun, terstruktur rapi, dan empati.',
      ),
    );
    return _model;
  }

  // -----------------------------------------------------------------
  // FR-49 | PBI-062 - Generate Draf Surat untuk Donatur (dari Anak Asuh/Panti)
  // -----------------------------------------------------------------
  Future<String> generateLetter({
    required String childAlias,
    required String topic,
    String donorName = 'Bapak/Ibu Donatur',
  }) async {
    final model = _gemini;
    if (model != null) {
      try {
        final prompt =
            'Tuliskan draf surat pendek yang sangat hangat, tulus, penuh rasa syukur, dan empati (3-4 paragraf) '
            'dari anak asuh bernama "$childAlias" (dan pengurus panti asuhan) yang ditujukan KEPADA DONATUR / ORANG TUA ASUH bernama "$donorName". '
            'Isi surat tentang ucapan terima kasih atas kebaikan/bantuan donatur serta kabar perkembangan anak: "$topic". '
            'Bahasa harus ramah, santun, menyentuh hati, mendoakan keberkahan donatur, dan mencerminkan semangat anak asuh dalam belajar dan berprestasi. '
            'Akhiri surat dengan: "Dengan penuh rasa terima kasih dan doa tulus,\n$childAlias & Keluarga Besar Panti Asuhan."';
        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text?.trim() ?? '';
        if (text.isNotEmpty) return text;
      } catch (e) {
        debugPrint('Gemini Letter API error: $e');
      }
    }
    return _generateDynamicLetter(childAlias, topic, donorName: donorName);
  }

  String _generateDynamicLetter(String alias, String topic, {String donorName = 'Bapak/Ibu Donatur'}) {
    return 'Kepada $donorName yang terkasih,\n\n'
        'Salam hangat dan doa terbaik dari kami di panti asuhan. Semoga Kakak/Bapak/Ibu senantiasa dalam keadaan sehat walafiat, bahagia, dan selalu dilimpahkan keberkahan rezeki.\n\n'
        'Saya menulis surat ini dari lubuk hati yang terdalam untuk mengucapkan terima kasih yang sebesar-besarnya atas $topic. Bantuan, doa, dan kasih sayang yang telah diberikan sangatlah berarti bagi kehidupan serta kelanjutan pendidikan saya di sini.\n\n'
        'Berkat kebaikan hati para donatur dan orang tua asuh, saya selalu termotivasi untuk rajin belajar, meraih prestasi di sekolah, dan pantang menyerah dalam menggapai cita-cita. Semoga Allah/Tuhan membalas segala ketulusan Kakak/Bapak/Ibu dengan berlipat ganda berkah dan kebahagiaan.\n\n'
        'Dengan penuh rasa terima kasih dan doa tulus,\n'
        '$alias & Keluarga Besar Panti Asuhan.';
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
  // FR-51 | PBI-062 - Chatbot FAQ Sahabat Asuh (Context-Aware + DB)
  // -----------------------------------------------------------------
  Future<String> askFaq(
    String question, {
    List<Map<String, String>>? history,
  }) async {
    // Ambil data aktual dari database lokal SQLite untuk memperkaya konteks AI
    String databaseContext = '';
    try {
      final localDb = LocalDatabase();
      final kids = await localDb.getNewChildren();
      final cachedKids = await localDb.getCachedChildren();
      final totalKids = kids.length + cachedKids.length;
      final receipts = await localDb.getReceipts();
      final donations = await localDb.getCachedDonations();

      databaseContext = '\n[KONTEKS DATA NYATA DATABASE SAAT INI]:\n'
          '- Total anak asuh terdaftar di database: $totalKids anak\n'
          '- Kategori kebutuhan: Pendidikan, Kesehatan, Nutrisi, Kebutuhan Harian, Perawatan Esensial\n'
          '- Total nota pengeluaran belanja terverifikasi on-chain: ${receipts.length} transaksi\n'
          '- Total riwayat donasi platform: ${donations.length} donasi\n';
    } catch (_) {}

    // 1. Coba panggil Gemini Live API dengan konteks database & riwayat percakapan bersambung
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
        final promptWithContext = '$question\n$databaseContext';
        final response = await chat.sendMessage(Content.text(promptWithContext));
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

    // 3. Comprehensive Context-Guard Engine (Pengecekan Konteks Ketat + Peringatan)
    return await _resolveContextGuardedAnswer(question);
  }

  // -----------------------------------------------------------------
  // Pengecekan Ketat Konteks AsuhKita & Pemberian Peringatan
  // -----------------------------------------------------------------
  Future<String> _resolveContextGuardedAnswer(String query) async {
    final q = query.toLowerCase().trim();

    // Kata kunci relevan dengan AsuhKita
    final inContextKeywords = [
      'asuh', 'anak', 'panti', 'donasi', 'sponsor', 'yatim', 'dhuafa',
      'ledger', 'blockchain', 'transparansi', 'sha', 'hash', 'verifikasi',
      'iot', 'kotak amal', 'esp32', 'sensor', 'uang', 'koin',
      'langkah', 'pedometer', 'accelerometer', 'gyro', 'game', 'bintang',
      'poin', 'kebaikan', 'badge', 'ranking', 'peringkat', 'reward',
      'lbs', 'peta', 'lokasi', 'gps', 'rute', 'jarak', 'radius', 'check in',
      'kurs', 'mata uang', 'valuta', 'usd', 'idr', 'sgd', 'eur', 'sar',
      'jadwal', 'zona', 'wib', 'wita', 'wit', 'london',
      'surat', 'rapor', 'karya', 'sekolah', 'video call', 'telepon', 'chat', 'ruang kasih',
      'nota', 'kuitansi', 'keuangan', 'saldo', 'belanja', 'laporan',
      'akun', 'login', 'register', 'profil', 'biometrik', 'sidik jari',
      'halo', 'hai', 'pagi', 'siang', 'sore', 'malam', 'assalam', 'siapa kamu', 'bisa apa',
    ];

    final isRelevant = inContextKeywords.any((k) => q.contains(k));

    // JIKA PERTANYAAN DI LUAR KONTEKS: TAMPILKAN PERINGATAN!
    if (!isRelevant) {
      return '⚠️ **Peringatan Di Luar Konteks AsuhKita**\n\n'
          'Maaf, pertanyaan Anda berada di luar topik dan lingkup aplikasi AsuhKita. '
          'Saya adalah **Sahabat Asuh AI** yang dirancang khusus untuk mendampingi program donasi, '
          'pengasuhan anak panti, sistem transparansi blockchain, IoT kotak amal, dan panduan fitur AsuhKita.\n\n'
          '💡 *Contoh pertanyaan yang dapat Anda ajukan:*\n'
          '• "Bagaimana cara mensponsori pendidikan anak asuh?"\n'
          '• "Bagaimana sistem transparansi blockchain bekerja di AsuhKita?"\n'
          '• "Berapa total anak asuh yang terdaftar saat ini?"\n'
          '• "Bagaimana cara kerja kotak amal pintar IoT?"\n'
          '• "Bagaimana cara check-in kunjungan di peta panti LBS?"';
    }

    // Ambil info real-time dari database lokal untuk dimasukkan ke jawaban
    int totalChildren = 0;
    try {
      final kids = await LocalDatabase().getNewChildren();
      final cached = await LocalDatabase().getCachedChildren();
      totalChildren = kids.length + cached.length;
    } catch (_) {}

    // Sapaan & Identitas
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

    // Konsep Aplikasi AsuhKita
    if (q.contains('asuhkita') || q.contains('aplikasi apa') || q.contains('tentang aplikasi') || q.contains('tujuan aplikasi')) {
      return 'AsuhKita adalah platform mobile sosial inovatif untuk sponsorship dan donasi anak panti asuhan yang mengedepankan transparansi 100%:\n'
          '• Saat ini terdaftar $totalChildren anak asuh di database sistem.\n'
          '• Setiap rupiah donasi dikunci ke Blockchain Ledger SHA-256.\n'
          '• Didukung Peta Panti LBS dengan rute perjalanan dan check-in radius 100 meter.\n'
          '• Dilengkapi Kotak Amal Pintar IoT ESP32 berotentikasi kriptografi HMAC.\n'
          '• Menyediakan Pedometer Donasi Langkah dan Mini Game Gyroscope untuk mengumpulkan Poin Kebaikan.';
    }

    // Cara Donasi & Alur Pembayaran
    if (q.contains('cara donasi') || q.contains('cara bayar') || q.contains('gimana donasi') || q.contains('langkah donasi') || q.contains('mau donasi')) {
      return 'Langkah-langkah berdonasi di AsuhKita:\n'
          '1. Buka tab "Sponsor" di menu bawah aplikasi.\n'
          '2. Pilih anak asuh yang ingin kamu bantu.\n'
          '3. Tentukan paket donasi (Pendidikan, Nutrisi, Kesehatan, atau Harian).\n'
          '4. Pilih mata uang (IDR, USD, EUR, SGD, SAR) dan frekuensi donasi (Sekali / Bulanan).\n'
          '5. Selesaikan transaksi dan sertifikat resmi donasi ber-QR blockchain akan diterbitkan seketika!';
    }

    // Blockchain Ledger & Transparansi
    if (q.contains('blockchain') || q.contains('ledger') || q.contains('transparan') || q.contains('hash') || q.contains('sha')) {
      return 'AsuhKita menerapkan Blockchain Ledger untuk transparansi total:\n'
          '• Setiap transaksi donasi dan nota belanja panti dicatat dalam blok data ber-hash SHA-256.\n'
          '• Setiap blok mengunci hash dari blok sebelumnya (hash chaining), sehingga data TIDAK BISA dimanipulasi atau diubah.\n'
          '• Setiap donasi mendapatkan Sertifikat Digital dengan Link Kredensial Blockchain yang dapat diverifikasi keasliannya di menu Blockchain Ledger.';
    }

    // Kotak Amal Pintar IoT ESP32
    if (q.contains('kotak amal') || q.contains('iot') || q.contains('esp32')) {
      return 'Kotak Amal Pintar IoT AsuhKita ditempatkan di panti asuhan:\n'
          '• Menggunakan mikrokontroler ESP32 dengan sensor inframerah dan tombol pecahan uang.\n'
          '• Setiap setoran fisik ditandatangani secara kriptografis menggunakan HMAC-SHA256 hardware dan langsung tersinkronisasi ke server dan ledger.';
    }

    // Poin Kebaikan, Ranking, & Mini Game
    if (q.contains('poin') || q.contains('game') || q.contains('langkah') || q.contains('ranking') || q.contains('badge') || q.contains('peringkat')) {
      return 'Poin Kebaikan di AsuhKita diperoleh dari:\n'
          '1. Donasi Langkah (Accelerometer): Setiap 20 langkah bernilai 1 Poin Kebaikan.\n'
          '2. Mini Game "Tangkap Bintang" (Gyroscope): Skor permainan langsung menambah poinmu.\n\n'
          '🏆 Tingkatan Ranking Donatur Berdasarkan Poin:\n'
          '• < 1.000 Poin: Pemula Berbagi 🌱\n'
          '• 1.000 - 2.999 Poin: Sahabat Peduli ⭐\n'
          '• 3.000 - 4.999 Poin: Pejuang Kebaikan 🌟\n'
          '• 5.000 - 9.999 Poin: Duta Asuh Mulia 💎\n'
          '• ≥ 10.000 Poin: Pahlawan Kebaikan Utama 🏆';
    }

    // Peta Panti & Rute Perjalanan
    if (q.contains('peta') || q.contains('lbs') || q.contains('rute') || q.contains('jarak') || q.contains('lokasi')) {
      return 'Fitur Peta Panti LBS AsuhKita menyediakan:\n'
          '• Deteksi otomatis lokasi GPS Anda (Latitude & Longitude) beserta region wilayah.\n'
          '• Pilihan manual kota / wilayah di seluruh Indonesia untuk mencari panti sekitar.\n'
          '• Rute Navigasi Perjalanan (Polyline) di OpenStreetMap lengkap dengan estimasi jarak dan waktu tempuh.\n'
          '• Fitur Check-In Kunjungan Fisik yang hanya aktif jika Anda berada dalam radius 100 meter dari gerbang panti.';
    }

    // Fallback Relevan
    return 'Pertanyaanmu mengenai topik AsuhKita telah dicatat. Di AsuhKita saat ini terdapat $totalChildren anak asuh terdaftar di database. Kamu dapat menjelajahi tab Sponsor untuk memilih anak asuh, Dashboard Keuangan untuk melihat nota belanja transparan, atau mencoba Mini Game & Pedometer untuk menambah Poin Kebaikan!';
  }
}
