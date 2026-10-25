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

  String _generateDynamicSummary(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return '• Anak menunjukkan perkembangan yang baik dan stabil dalam aktivitas harian.\n'
          '• Kehadiran di sekolah dan interaksi sosial dengan teman sebaya sangat positif.\n'
          '• Kesehatan fisik terpantau prima dengan asupan gizi yang terjaga.';
    }

    final buffer = StringBuffer('Ringkasan Perkembangan Anak:\n');
    int count = 0;
    for (final line in lines) {
      if (count >= 4) break;
      final clean = line.replaceAll(RegExp(r'^[0-9\.\-\*\•\s]+'), '');
      if (clean.length > 5) {
        buffer.writeln('• $clean');
        count++;
      }
    }
    if (count == 0) {
      buffer.writeln('• Perkembangan positif pada aspek akademik dan sosial.');
      buffer.writeln('• Kebutuhan dasar dan kesehatan terpenuhi dengan baik.');
    }
    return buffer.toString().trim();
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
          '- Kategori kebutuhan: Pendidikan, Kesehatan, Nutrisi & Gizi, Kebutuhan Sehari-hari\n'
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

    // 3. Comprehensive Context-Guard Engine (Pengecekan Konteks Cerdas & Luas)
    return await _resolveContextGuardedAnswer(question);
  }

  // -----------------------------------------------------------------
  // Pengecekan Cerdas Konteks AsuhKita & Jawaban Spesifik Relevan
  // -----------------------------------------------------------------
  Future<String> _resolveContextGuardedAnswer(String query) async {
    final q = query.toLowerCase().trim();

    // Kata kunci relevan dengan AsuhKita (Domain Khusus)
    final inContextKeywords = [
      'asuh', 'anak', 'panti', 'donasi', 'sponsor', 'yatim', 'dhuafa', 'bantu', 'sedekah',
      'ledger', 'blockchain', 'transparansi', 'sha', 'hash', 'verifikasi', 'kredensial', 'sertifikat',
      'iot', 'kotak amal', 'esp32', 'sensor', 'uang', 'koin', 'pecahan',
      'langkah', 'pedometer', 'accelerometer', 'gyro', 'game', 'bintang',
      'poin', 'kebaikan', 'badge', 'ranking', 'peringkat', 'reward',
      'lbs', 'peta', 'lokasi', 'gps', 'rute', 'jarak', 'radius', 'check in', 'kunjungan',
      'kurs', 'mata uang', 'valuta', 'usd', 'idr', 'sgd', 'eur', 'sar', 'rupiah', 'dollar',
      'jadwal', 'zona', 'wib', 'wita', 'wit', 'london', 'jam', 'waktu', 'pengingat',
      'surat', 'rapor', 'karya', 'sekolah', 'video call', 'telepon', 'chat', 'ruang kasih',
      'nota', 'kuitansi', 'keuangan', 'saldo', 'belanja', 'laporan', 'kas', 'audit', 'anggaran',
      'sepatu', 'seragam', 'tas', 'buku', 'spp', 'pendidikan', 'makanan', 'gizi', 'nutrisi', 'susu',
      'kesehatan', 'obat', 'dokter', 'perawatan', 'harian', 'sembako', 'pakaian',
      'akun', 'login', 'register', 'profil', 'biometrik', 'sidik jari', 'password', 'logout', 'masuk', 'daftar',
      'saran', 'kesan', 'feedback', 'ulasan', 'komentar',
      'halo', 'hai', 'pagi', 'siang', 'sore', 'malam', 'assalam', 'siapa kamu', 'bisa apa', 'fitur',
      'legalitas', 'resmi', 'izin', 'peduli anak', 'lombok', 'kontak', 'alamat', 'relawan',
    ];

    final isRelevant = inContextKeywords.any((k) => q.contains(k));

    // JIKA PERTANYAAN BENAR-BENAR DI LUAR KONTEKS: TAMPILKAN PERINGATAN!
    if (!isRelevant) {
      return '⚠️ **Peringatan Di Luar Konteks AsuhKita**\n\n'
          'Maaf, pertanyaan Anda berada di luar topik dan lingkup aplikasi AsuhKita. '
          'Saya adalah **Sahabat Asuh AI** yang dirancang khusus untuk mendampingi program donasi, '
          'pengasuhan anak panti, sistem transparansi blockchain, IoT kotak amal, dan panduan fitur AsuhKita.\n\n'
          '💡 *Contoh pertanyaan yang dapat Anda ajukan:*\n'
          '• "Apakah ada anak asuh yang membutuhkan perlengkapan sekolah atau sepatu?"\n'
          '• "Bagaimana cara kerja jadwal audit 4 zona waktu (WIB, WITA, WIT, London)?"\n'
          '• "Bagaimana cara melihat nota belanja dan transparansi laporan keuangan?"\n'
          '• "Bagaimana cara memverifikasi keaslian sertifikat donasi di Blockchain Ledger?"\n'
          '• "Bagaimana cara mengumpulkan Poin Kebaikan lewat langkah kaki atau game?"';
    }

    // Ambil info data real-time dari database lokal untuk dimasukkan ke jawaban
    int totalChildren = 20;
    try {
      final kids = await LocalDatabase().getNewChildren();
      final cached = await LocalDatabase().getCachedChildren();
      totalChildren = kids.isNotEmpty ? kids.length : (cached.isNotEmpty ? cached.length : 20);
    } catch (_) {}

    // 1. Sapaan & Identitas
    if (q.contains('halo') || q.contains('hai') || q.contains('pagi') || q.contains('siang') || q.contains('sore') || q.contains('malam') || q.contains('assalam')) {
      return 'Halo! Senang sekali bisa menyapamu 😊 Saya **Sahabat Asuh AI**, asisten resmi platform AsuhKita.\n\n'
          'Saya siap membantumu seputar profil 20 anak asuh, cara sponsorship, jadwal video call & audit 4 zona waktu, transparansi nota belanja blockchain, peta panti LBS, hingga kotak amal pintar IoT. Apa yang ingin kamu ketahui hari ini?';
    }
    if (q.contains('siapa kamu') || q.contains('kamu siapa') || q.contains('nama kamu') || q.contains('tentang kamu') || q.contains('bisa apa')) {
      return 'Saya adalah **Sahabat Asuh AI**, asisten cerdas yang terintegrasi langsung di aplikasi AsuhKita. Tugas saya meliputi:\n'
          '1. **Informasi Anak Asuh**: Memberikan rekomendasi anak asuh berdasarkan kebutuhan prioritas (Pendidikan, Nutrisi, Kesehatan, Harian).\n'
          '2. **Panduan Sponsorship & Donasi**: Menjelaskan paket bantuan, pembayaran, dan konversi 5 mata uang asing.\n'
          '3. **Asisten Kepenulisan**: Membantu menyusun draf surat hangat untuk anak asuh (Tab "Tulis Surat") dan meringkas laporan perkembangan (Tab "Ringkas Laporan").\n'
          '4. **Transparansi Blockchain & Sensor IoT**: Menjelaskan audit nota belanja, validasi sertifikat, sensor pedometer, dan kotak amal IoT.';
    }

    // 2. Kebutuhan Spesifik Barang (Sepatu, Seragam, Buku, SPP, Gizi, Kesehatan)
    if (q.contains('sepatu') || q.contains('seragam') || q.contains('buku') || q.contains('tas') || q.contains('spp') || q.contains('sekolah') || q.contains('pendidikan')) {
      return '📚 **Kebutuhan Pendidikan & Perlengkapan Sekolah Anak Asuh**\n\n'
          'Di panti asuhan Peduli Anak, beberapa anak asuh yang sangat membutuhkan perlengkapan sekolah saat ini antara lain:\n'
          '• **Arfa Pratama (8 th)**: Membutuhkan seragam baru dan buku matematika (Target: Rp 850.000).\n'
          '• **Azkya Rahma (9 th)**: Membutuhkan tas sekolah dan buku pelajaran (Target: Rp 750.000).\n'
          '• **Dimas Aditya (11 th)**: Membutuhkan sepatu olahraga dan perlengkapan latihan (Target: Rp 800.000).\n'
          '• **Jaka Satria (13 th)**: Membutuhkan sepatu tanding bulutangkis dan modul belajar (Target: Rp 1.000.000).\n'
          '• **Raditya Putra (10 th)**: Membutuhkan sepatu sekolah dan perlengkapan mengaji (Target: Rp 850.000).\n\n'
          '💡 *Cara membantu:* Buka tab **Sponsor**, pilih anak di atas, lalu pilih **Paket Pendidikan**!';
    }

    if (q.contains('nutrisi') || q.contains('gizi') || q.contains('makanan') || q.contains('susu') || q.contains('sembako') || q.contains('lapar')) {
      return '🥛 **Kebutuhan Nutrisi, Gizi, & Susu Pertumbuhan**\n\n'
          'Untuk asupan makanan bergizi dan susu pertumbuhan anak-anak di panti asuhan:\n'
          '• **Bulan Ramadhani (7 th)**: Membutuhkan susu kalori tinggi dan suplemen vitamin (Target: Rp 650.000).\n'
          '• **Hafizh Alfarizi (9 th)**: Membutuhkan paket makanan sehat dan nutrisi harian (Target: Rp 750.000).\n'
          '• **Nabila Syifa (8 th)**: Membutuhkan vitamin daya tahan tubuh dan nutrisi seimbang (Target: Rp 700.000).\n\n'
          '💡 Anda dapat menyalurkan bantuan melalui **Paket Nutrisi & Gizi** pada menu Sponsor!';
    }

    if (q.contains('sehat') || q.contains('kesehatan') || q.contains('obat') || q.contains('dokter') || q.contains('sakit') || q.contains('mata')) {
      return '🩺 **Kebutuhan Kesehatan & Perawatan Medis**\n\n'
          'Dukungan kesehatan anak asuh panti meliputi:\n'
          '• **Gita Kirana (7 th)**: Membutuhkan pemeriksaan kesehatan mata berkala dan kacamata koreksi (Target: Rp 600.000).\n'
          '• **Luthfi Rahman (11 th)**: Memerlukan pemeriksaan fisik rutin dan paket vitamin anak (Target: Rp 900.000).\n\n'
          'Seluruh pengeluaran obat dan biaya dokter dicatat secara transparan dengan foto nota kuitansi yang dapat diaudit di Dashboard Keuangan.';
    }

    // 3. Profil & Jumlah Anak Asuh
    if (q.contains('daftar anak') || q.contains('siapa saja') || q.contains('berapa anak') || q.contains('nama anak') || q.contains('umur') || q.contains('usia') || q.contains('cita-cita') || q.contains('hobi')) {
      return '👧👦 **Profil Anak Asuh di AsuhKita**\n\n'
          'Saat ini terdapat **$totalChildren anak asuh** yang terdata di sistem asrama Peduli Anak Lombok (rentang usia 6 - 13 tahun), di antaranya:\n'
          '1. **Arfa** (8 th) - Cita-cita: Arsitek | Hobi: Menggambar\n'
          '2. **Ayra** (6 th) - Cita-cita: Guru TK | Hobi: Mewarnai\n'
          '3. **Azkya** (9 th) - Cita-cita: Dokter Anak | Hobi: Membaca\n'
          '4. **Bima** (10 th) - Cita-cita: Pilot Pesawat | Hobi: Merakit Mainan\n'
          '5. **Bulan** (7 th) - Cita-cita: Chef / Koki | Hobi: Memasak\n'
          '6. **Dimas** (11 th) - Cita-cita: Polisi | Hobi: Atletik & Sepak Bola\n'
          '7. **Elsa** (8 th) - Cita-cita: Perawat | Hobi: Menulis Cerita\n'
          '8. **Fajar** (12 th) - Cita-cita: Software Engineer | Hobi: Sains & Coding\n'
          '9. **Jaka** (13 th) - Cita-cita: Atlet Badminton | Hobi: Bulutangkis\n'
          '...dan anak-anak hebat lainnya!\n\n'
          'Semua profil lengkap dengan foto dan cerita latar belakang dapat dilihat di menu **Sponsor**.';
    }

    // 4. Jadwal & 4 Zona Waktu
    if (q.contains('jadwal') || q.contains('zona') || q.contains('wib') || q.contains('wita') || q.contains('wit') || q.contains('london') || q.contains('jam') || q.contains('waktu')) {
      return '⏰ **Fitur Jadwal & Sinkronisasi 4 Zona Waktu Serentak**\n\n'
          'AsuhKita menghadirkan konversi waktu otomatis ke 4 zona waktu dunia:\n'
          '1. **WIB (UTC+7)**: Jakarta, Jawa, Sumatra, Kalimantan Barat.\n'
          '2. **WITA (UTC+8)**: Lombok (Pusat Panti Peduli Anak), Bali, Sulawesi.\n'
          '3. **WIT (UTC+9)**: Maluku dan Papua.\n'
          '4. **London BST/GMT (UTC+1)**: Sinkronisasi untuk donatur dan yayasan mitra internasional.\n\n'
          '🎯 **Fungsi Utama:**\n'
          '• **Untuk Donatur:** Menjadwalkan Panggilan Video Ramah Anak (antara pukul 08:00 - 17:00 waktu panti) dengan alarm pengingat otomatis.\n'
          '• **Untuk Admin Panti:** Menetapkan tenggat waktu pembuatan & audit Laporan Keuangan secara serentak agar donatur global mengetahui kapan laporan dirilis.';
    }

    // 5. Laporan Keuangan & Nota Belanja
    if (q.contains('laporan') || q.contains('keuangan') || q.contains('nota') || q.contains('kuitansi') || q.contains('belanja') || q.contains('audit') || q.contains('kas') || q.contains('saldo')) {
      return '📊 **Transparansi Laporan Keuangan & Nota Belanja**\n\n'
          'Prinsip keuangan di AsuhKita mengusung **Transparansi 100% Bebas Manipulasi**:\n'
          '• **Laporan Per Anak**: Setiap rupiah yang didonasikan dikelompokkan ke rekening kas masing-masing anak tanpa dobel pencatatan.\n'
          '• **Bukti Nota Fisik**: Pengurus panti wajib mengunggah foto nota/kuitansi asli (struk toko, kuitansi SPP, nota apotek) setiap kali membelanjakan dana anak.\n'
          '• **Kunci Kriptografi**: Setiap nota otomatis dihitung hash SHA-256 dan dicatat ke Blockchain Ledger.\n'
          '• **Audit Publik**: Donatur dapat memantau kas saldo panti secara real-time dan melihat rincian nota belanja di Dashboard Keuangan.';
    }

    // 6. Blockchain Ledger & Verifikasi Sertifikat Palsu / Rekayasa
    if (q.contains('blockchain') || q.contains('ledger') || q.contains('transparan') || q.contains('hash') || q.contains('sha') || q.contains('sertifikat') || q.contains('palsu') || q.contains('rekayasa')) {
      return '⛓️ **Sistem Blockchain Ledger & Deteksi Sertifikat Rekayasa**\n\n'
          'Setiap transaksi donasi dan nota belanja di AsuhKita dilindungi teknologi terdesentralisasi:\n'
          '• **Hash Chaining**: Setiap transaksi baru mengunci hash blok sebelumnya dengan algoritma SHA-256. Jika data diubah 1 huruf saja, seluruh rantai akan terputus.\n'
          '• **Sertifikat Digital Donatur**: Setiap kali berdonasi, Anda mendapatkan sertifikat resmi ber-QR code dan ID Kredensial unik.\n'
          '• **Uji Deteksi Sertifikat Palsu / Rekayasa**: Di menu **Blockchain Ledger**, terdapat tombol preset cepat **"🚨 Sertifikat Rekayasa/Palsu (Demo Dosen)"** yang membuktikan bahwa sertifikat manipulasi pihak ketiga akan langsung DITOLAK oleh konsensus blockchain.';
    }

    // 7. Kotak Amal Pintar IoT ESP32
    if (q.contains('kotak amal') || q.contains('iot') || q.contains('esp32') || q.contains('koin') || q.contains('hardware')) {
      return '📦 **Kotak Amal Pintar IoT ESP32 AsuhKita**\n\n'
          'Inovasi IoT untuk kotak amal fisik di panti asuhan:\n'
          '• **Hardware ESP32**: Dilengkapi sensor optik inframerah dan tombol pecahan uang (Rp 1.000 s/d Rp 100.000).\n'
          '• **Otentikasi Kriptografis HMAC-SHA256**: Setiap uang yang masuk ditandatangani oleh hardware key sebelum dikirimkan ke server.\n'
          '• **Real-Time Sync**: Dana langsung tercatat di kas saldo panti dan tersinkronisasi ke Blockchain Ledger secara otomatis.';
    }

    // 8. Poin Kebaikan, Donasi Langkah, & Mini Game
    if (q.contains('poin') || q.contains('game') || q.contains('langkah') || q.contains('pedometer') || q.contains('gyro') || q.contains('ranking') || q.contains('badge') || q.contains('peringkat')) {
      return '⭐ **Poin Kebaikan, Donasi Langkah, & Game Gyroscope**\n\n'
          'Anda bisa berbuat kebaikan tanpa harus selalu menggunakan uang tunai:\n'
          '1. **Donasi Langkah (Pedometer)**: Menggunakan sensor accelerometer HP Anda. Setiap 20 langkah bernilai 1 Poin Kebaikan!\n'
          '2. **Mini Game "Tangkap Bintang"**: Menggunakan sensor gerak gyroscope HP Anda untuk mengarahkan keranjang kebaikan dan mengumpulkan bintang.\n\n'
          '🏆 **Tingkatan Ranking Donatur:**\n'
          '• < 1.000 Poin: **Pemula Berbagi** 🌱\n'
          '• 1.000 - 2.999 Poin: **Sahabat Peduli** ⭐\n'
          '• 3.000 - 4.999 Poin: **Pejuang Kebaikan** 🌟\n'
          '• 5.000 - 9.999 Poin: **Duta Asuh Mulia** 💎\n'
          '• ≥ 10.000 Poin: **Pahlawan Kebaikan Utama** 🏆';
    }

    // 9. Peta Panti LBS & Check-In
    if (q.contains('peta') || q.contains('lbs') || q.contains('rute') || q.contains('jarak') || q.contains('lokasi') || q.contains('kunjungan') || q.contains('check in') || q.contains('gps')) {
      return '📍 **Peta Panti LBS & Fitur Check-In Kunjungan**\n\n'
          'Fitur berbasis lokasi (Location-Based Service) di AsuhKita:\n'
          '• **Deteksi GPS**: Menentukan posisi akurat Anda terhadap panti asuhan mitra.\n'
          '• **Rute Navigasi OpenStreetMap**: Menampilkan garis panduan perjalanan lengkap dengan jarak (km) dan estimasi waktu tempuh.\n'
          '• **Check-In Kunjungan Fisik**: Tombol check-in hanya dapat ditekan jika Anda berada dalam radius **100 meter** dari lokasi panti untuk mencegah klaim kunjungan fiktif.';
    }

    // 10. Mata Uang & Valuta Asing
    if (q.contains('kurs') || q.contains('mata uang') || q.contains('valuta') || q.contains('usd') || q.contains('dollar') || q.contains('euro') || q.contains('eur') || q.contains('sgd') || q.contains('sar')) {
      return '💱 **Dukungan 5 Mata Uang Asing & Konversi Real-Time**\n\n'
          'AsuhKita memfasilitasi donatur dari berbagai negara dengan pilihan mata uang:\n'
          '• **IDR**: Rupiah Indonesia\n'
          '• **USD**: Dolar Amerika Serikat\n'
          '• **EUR**: Euro Uni Eropa\n'
          '• **SGD**: Dolar Singapura\n'
          '• **SAR**: Riyal Arab Saudi\n\n'
          'Sistem mengonversi secara otomatis dengan kurs terstandarisasi sehingga donasi Anda tetap tercatat tepat dalam pembukuan panti.';
    }

    // 11. Ruang Kasih, Chat, Video Call, & Surat
    if (q.contains('surat') || q.contains('video call') || q.contains('chat') || q.contains('telepon') || q.contains('ruang kasih') || q.contains('komunikasi') || q.contains('rapor')) {
      return '💌 **Ruang Kasih & Komunikasi Hangat dengan Anak Asuh**\n\n'
          'Mendukung keterikatan batin antara orang tua asuh dan anak:\n'
          '• **Kirim Surat AI**: Gunakan tab **"Tulis Surat"** untuk meminta Sahabat Asuh AI membuat draf surat penyemangat belajar yang santun dan menyentuh hati.\n'
          '• **Jadwal Video Call Ramah Anak**: Pasang jadwal panggilan video interaktif dengan anak asuh di waktu luang mereka.\n'
          '• **Pantau Karya & Rapor**: Lihat perkembangan nilai sekolah dan gambar karya seni anak secara berkala.';
    }

    // 12. Akun, Keamanan, & Login Biometrik
    if (q.contains('akun') || q.contains('login') || q.contains('daftar') || q.contains('register') || q.contains('sidik jari') || q.contains('biometrik') || q.contains('password') || q.contains('logout')) {
      return '🔐 **Keamanan Akun & Fitur Login Biometrik**\n\n'
          '• **Enkripsi Sandi**: Password di-hash menggunakan SHA-256 dan salt unik sebelum disimpan.\n'
          '• **Secure Storage AES-256**: Sesi login disimpan di enkripsi hardware perangkat sehingga bebas dari pencurian token.\n'
          '• **Login Sidik Jari**: Setelah login pertama kali, Anda dapat mengaktifkan login biometrik untuk masuk instan dengan sidik jari.\n'
          '• **Logout Bersih**: Sesi lokal dihapus seketika (< 100 ms) dengan dialog animasi berlogo AsuhKita.';
    }

    // 13. Panti Asuhan & Legalitas
    if (q.contains('panti') || q.contains('peduli anak') || q.contains('legal') || q.contains('resmi') || q.contains('alamat') || q.contains('kontak')) {
      return '🏡 **Panti Asuhan Mitra: Peduli Anak Foundation**\n\n'
          '• **Lokasi**: Jl. Dharma Bhakti, Desa Langko, Kec. Lingsar, Lombok Barat, NTB 83371.\n'
          '• **Fokus Asuhan**: Menampung anak yatim, piatu, dan dhuafa dengan fasilitas asrama, sekolah dasar terakreditasi, fasilitas medis, dan area olahraga ramah anak.\n'
          '• **Legalitas**: Lembaga Kesejahteraan Sosial Anak (LKSA) resmi terdaftar di Kementerian Sosial Republik Indonesia.\n'
          '• **Kunjungan**: Anda dipersilakan berkunjung langsung dengan menjadwalkan kunjungan di aplikasi atau memanfaatkan navigasi Peta LBS.';
    }

    // 14. Cara Berdonasi & Pembayaran
    if (q.contains('cara donasi') || q.contains('cara bayar') || q.contains('gimana donasi') || q.contains('langkah donasi') || q.contains('mau donasi') || q.contains('transfer')) {
      return '💖 **Panduan Mudah Berdonasi di AsuhKita**\n\n'
          '1. Masuk ke tab **Sponsor** di menu navigasi bawah.\n'
          '2. Pilih anak asuh yang ingin Anda dampingi.\n'
          '3. Pilih paket donasi: **Pendidikan**, **Nutrisi & Gizi**, **Kesehatan**, atau **Kebutuhan Harian**.\n'
          '4. Tentukan mata uang (IDR, USD, EUR, SGD, SAR) dan frekuensi (Sekali / Rutin Bulanan).\n'
          '5. Konfirmasi pembayaran dan sertifikat resmi ber-QR blockchain akan langsung terbit untuk Anda!';
    }

    // 15. Saran & Kesan (Feedback)
    if (q.contains('saran') || q.contains('kesan') || q.contains('feedback') || q.contains('ulasan') || q.contains('kritik')) {
      return '📝 **Fitur Saran & Kesan (Feedback) Lintas Akun**\n\n'
          'Kami sangat menghargai masukan Anda! Di menu **Saran & Kesan**:\n'
          '• Anda dapat memberikan bintang penilaian (rating) dan menuliskan kesan pengalaman Anda menggunakan AsuhKita.\n'
          '• Seluruh feedback tersinkronisasi secara global dan persisten sehingga dapat dibaca bersama oleh donatur lain maupun admin panti asuhan.';
    }

    // Default Fallback Hangat & Informatif
    return 'Terima kasih atas pertanyaannya! Di AsuhKita saat ini terdapat **$totalChildren anak asuh** yang siap menerima dampingan donasi pendidikan, nutrisi, dan kesehatan.\n\n'
        'Anda dapat menjelajahi menu **Sponsor** untuk memilih anak asuh, membuka **Dashboard Keuangan** untuk memeriksa transparansi nota belanja, atau menjadwalkan panggilan video ramah anak di fitur **Jadwal 4 Zona Waktu**. Ada yang ingin ditanyakan lebih rinci?';
  }
}
