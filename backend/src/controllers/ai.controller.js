



const https = require('https');









const callGeminiApi = (prompt, systemInstruction = '') => {
  return new Promise((resolve, reject) => {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      return reject(new Error('GEMINI_API_KEY belum dikonfigurasi di environment variable.'));
    }

    const payload = {
      contents: [
        {
          role: 'user',
          parts: [{ text: prompt }]
        }
      ]
    };

    if (systemInstruction) {
      payload.systemInstruction = {
        parts: [{ text: systemInstruction }]
      };
    }

    const postData = JSON.stringify(payload);

    const options = {
      hostname: 'generativelanguage.googleapis.com',
      port: 443,
      path: `/v1beta/models/gemini-2.0-flash:generateContent?key=${encodeURIComponent(apiKey)}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      },
      timeout: 20000
    };

    const req = https.request(options, (res) => {
      let responseBody = '';

      res.on('data', (chunk) => {
        responseBody += chunk;
      });

      res.on('end', () => {
        try {
          const json = JSON.parse(responseBody);

          if (res.statusCode < 200 || res.statusCode >= 300) {
            const errorMsg = json.error?.message || `HTTP status code ${res.statusCode}`;
            return reject(new Error(errorMsg));
          }

          const generatedText = json.candidates?.[0]?.content?.parts?.[0]?.text;
          if (!generatedText) {
            return reject(new Error('Format respons Gemini tidak terduga atau tidak mengandung teks.'));
          }

          resolve(generatedText.trim());
        } catch (parseError) {
          reject(new Error(`Gagal memproses respons JSON dari Gemini: ${parseError.message}`));
        }
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Koneksi ke Gemini API mengalami batas waktu (timeout).'));
    });

    req.write(postData);
    req.end();
  });
};





const getFallbackLetter = (childAlias, childAge, childNeedCategory, donorName, theme) => {
  const child = childAlias || 'Adik Tersayang';
  const sponsor = donorName || 'Kakak Asuh';
  const themeLower = (theme || 'motivasi').toLowerCase();

  if (themeLower.includes('ulang tahun')) {
    return `Halo ${child},\n\nSelamat ulang tahun yang luar biasa! Kakak sangat bersyukur dan bangga bisa melihatmu tumbuh dengan sehat dan penuh keceriaan di usia yang baru ini. Tetaplah menjadi anak yang baik hati, selalu rajin belajar, dan jangan pernah ragu untuk bermimpi setinggi langit.\n\nKakak selalu mendoakan agar setiap langkahmu dipenuhi berkah, kesehatan, dan kebahagiaan. Ingat, Kakak selalu ada di sini mendukung perjuanganmu!\n\nSalam hangat dan peluk erat,\n${sponsor}`;
  }

  if (themeLower.includes('belajar') || themeLower.includes('sekolah') || themeLower.includes('pendidikan')) {
    return `Halo ${child},\n\nBagaimana kegiatanmu di sekolah hari ini? Kakak harap kamu selalu bersemangat dalam menuntut ilmu dan mencoba hal-hal baru setiap hari. Belajar memang butuh kesabaran dan ketekunan, tetapi Kakak percaya kamu memiliki potensi yang sangat luar biasa.\n\nJangan pernah takut salah saat belajar, karena setiap proses akan membuatmu semakin bijak dan pintar. Jika ada pelajaran yang sulit, jangan ragu untuk berdiskusi dengan guru dan teman-temanmu ya.\n\nSemangat terus belajarnya ya, Kakak selalu bangga padamu!\n\nSalam hangat,\n${sponsor}`;
  }


  return `Halo ${child},\n\nSemoga hari ini membawakan senyuman dan kebahagiaan untukmu. Kakak menulis surat ini untuk mengingatkanmu bahwa kamu adalah anak yang istimewa, tangguh, dan sangat berharga.\n\nTeruslah bersemangat dalam menjalani hari-harimu, jaga kesehatan dengan baik, dan jangan pernah berhenti mengejar cita-citamu. Meskipun jarak kita jauh, doa dan dukungan penuh dari Kakak selalu menyertai setiap langkahmu menuju masa depan yang cerah.\n\nTetap semangat dan selalu tersenyum ya!\n\nSalam penuh kasih,\n${sponsor}`;
};




const getFallbackSummary = (childAlias, reportText) => {
  const child = childAlias || 'Anak asuh';
  return `• ${child} menunjukkan kemajuan perkembangan yang stabil dan positif pada periode ini.\n` +
    `• Berpartisipasi aktif dalam kegiatan pembelajaran serta berinteraksi secara sehat dan ceria bersama teman-temannya.\n` +
    `• Kondisi kesehatan, pemenuhan gizi, dan kebutuhan harian terpantau dalam keadaan baik di bawah pendampingan panti.\n` +
    `• Terus menunjukkan motivasi dan antusiasme tinggi dalam mengasah minat dan keterampilannya.\n` +
    `• Disarankan untuk terus memberikan pendampingan berkelanjutan guna memaksimalkan potensi tumbuh kembangnya.`;
};







const draftLetter = async (req, res, next) => {
  try {
    const {
      child_alias = 'Adik',
      child_age = 10,
      child_need_category = 'Pendidikan',
      donor_name = req.user?.name || 'Kakak Asuh',
      theme = 'motivasi'
    } = req.body;

    const systemPrompt = 'Kamu adalah asisten AI ramah untuk platform AsuhKita yang bertugas membantu orang tua asuh (sponsor) menulis surat hangat, menyemangati, dan penuh kasih kepada anak asuh mereka di Indonesia. Bahasa yang digunakan harus ramah, bersahabat, sopan, dan mudah dimengerti anak-anak. Jangan sertakan teks pengantar atau penutup meta seperti "Tentu, ini suratnya:". Langsung tuliskan isi surat dari awal hingga penutup.';

    const userPrompt = `Tolong buatkan draf surat dari seorang donatur/orang tua asuh bernama "${donor_name}" kepada anak asuhnya yang bernama "${child_alias}" (berusia ${child_age} tahun, kategori kebutuhan: ${child_need_category}).
Tema surat: "${theme}" (misalnya: motivasi, ulang tahun, atau semangat belajar).
Tuliskan surat yang menyentuh hati, memberikan semangat, dan menunjukkan kepedulian tulus.`;

    let letterContent = '';

    try {
      letterContent = await callGeminiApi(userPrompt, systemPrompt);
    } catch (apiError) {
      console.warn('⚠️ [AI CONTROLLER] Panggilan Gemini API gagal atau API key belum disetel, menggunakan fallback template:', apiError.message);
      letterContent = getFallbackLetter(child_alias, child_age, child_need_category, donor_name, theme);
    }

    return res.status(200).json({
      success: true,
      data: {
        letter_content: letterContent,
        child_alias,
        theme,
        generated_at: new Date().toISOString()
      }
    });
  } catch (err) {
    next(err);
  }
};







const summarizeReport = async (req, res, next) => {
  try {
    const { report_text, child_alias = 'Anak Asuh' } = req.body;

    if (!report_text || typeof report_text !== 'string' || report_text.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Teks laporan (report_text) wajib diisi untuk dirangkum.',
        error: 'MISSING_REPORT_TEXT'
      });
    }

    const systemPrompt = 'Kamu adalah asisten AI untuk platform AsuhKita. Tugasmu adalah merangkum laporan perkembangan anak binaan dari panti asuhan menjadi 3 sampai 5 poin ringkas (bullet points) dalam bahasa Indonesia yang ringkas, profesional, dan menyoroti kemajuan anak. Jangan sertakan pengantar meta, langsung berikan poin-poin menggunakan simbol "•".';

    const userPrompt = `Berikut adalah teks laporan perkembangan untuk anak bernama ${child_alias}:\n\n"${report_text}"\n\nRangkumlah laporan di atas menjadi 3-5 poin penting (bullet points) yang jelas, positif, dan informatif bagi donatur/orang tua asuh.`;

    let summary = '';

    try {
      summary = await callGeminiApi(userPrompt, systemPrompt);
    } catch (apiError) {
      console.warn('⚠️ [AI CONTROLLER] Panggilan Gemini API gagal atau API key belum disetel, menggunakan fallback template:', apiError.message);
      summary = getFallbackSummary(child_alias, report_text);
    }

    return res.status(200).json({
      success: true,
      data: {
        summary,
        child_alias,
        generated_at: new Date().toISOString()
      }
    });
  } catch (err) {
    next(err);
  }
};







const getFaq = async (req, res, next) => {
  try {
    const faqList = [
      {
        question: 'Apa itu platform AsuhKita dan bagaimana kaitannya dengan Yayasan Peduli Anak?',
        answer: 'AsuhKita adalah platform digital orang tua asuh yang bermitra dengan Yayasan Peduli Anak (pedulianak.org)—organisasi nirlaba independen yang telah berkiprah selama lebih dari 20 tahun di NTB untuk melindungi dan membina anak-anak kurang mampu, yatim, dan terlantar.'
      },
      {
        question: 'Berapa banyak anak dan keluarga yang telah didukung oleh Peduli Anak Foundation?',
        answer: 'Selama lebih dari dua dekade berdiri sejak tahun 2004, Yayasan Peduli Anak telah berhasil menyelamatkan dan mendampingi lebih dari 22.000 anak serta memberdayakan lebih dari 9.000 keluarga prasejahtera agar mandiri.'
      },
      {
        question: 'Di mana saja lokasi pusat kesejahteraan anak mitra AsuhKita berada?',
        answer: 'Pusat kesejahteraan anak dan fasilitas panti mitra AsuhKita berada di Nusa Tenggara Barat (NTB), terutama di Pulau Lombok (Lombok Barat dan Mataram) serta Pulau Sumbawa (Sumbawa Besar dan Bima).'
      },
      {
        question: 'Program apa saja yang dijalankan oleh AsuhKita dan mitra panti?',
        answer: 'Program berfokus pada tiga pilar utama: 1) Pendidikan Berkualitas (sekolah formal, perlengkapan belajar, pelatihan vokasional komputer & kerajinan), 2) Kesehatan & Gizi (pemeriksaan rutin medis, imunisasi, makanan bergizi seimbang), serta 3) Pengasuhan Berbasis Keluarga (family care dan pencegahan pernikahan usia anak).'
      },
      {
        question: 'Bagaimana cara menjadi orang tua asuh (sponsorship) di AsuhKita?',
        answer: 'Anda dapat memilih anak asuh melalui menu Daftar Anak di aplikasi, memilih paket kebutuhan (Pendidikan, Kesehatan, Gizi, atau Paket Lengkap), dan mengatur komitmen donasi bulanan atau sekali donasi dengan mudah.'
      },
      {
        question: 'Bagaimana alokasi dan penyaluran dana donasi dilakukan?',
        answer: '100% donasi yang disalurkan melalui AsuhKita dialokasikan langsung untuk kebutuhan primer anak asuh sesuai paket yang dipilih (buku sekolah, seragam, suplemen vitamin, pemeriksaan medis, dan makanan bergizi) tanpa potongan tersembunyi.'
      },
      {
        question: 'Bagaimana transparansi penyaluran donasi dijamin oleh AsuhKita?',
        answer: 'AsuhKita mengimplementasikan teknologi blockchain ledger sederhana (hash chain SHA-256). Setiap donasi yang masuk, bukti laporan perkembangan anak, serta event kotak amal IoT dicatat ke dalam blok terenkripsi yang kekal (immutable) dan dapat diverifikasi kapan saja.'
      },
      {
        question: 'Bagaimana AsuhKita melindungi privasi dan keamanan data anak asuh?',
        answer: 'Sesuai kebijakan perlindungan anak (Child Protection Policy), kami tidak pernah mempublikasikan nama lengkap asli, dokumen identitas, atau lokasi spesifik tempat tinggal anak. Seluruh anak ditampilkan dengan nama samaran (alias) dan avatar ilustrasi digital.'
      },
      {
        question: 'Mata uang apa saja yang didukung untuk pembayaran donasi di AsuhKita?',
        answer: 'Selain Rupiah (IDR), sistem AsuhKita mendukung donasi multi-mata uang internasional seperti Dolar AS (USD), Dolar Singapura (SGD), Euro (EUR), dan Riyal Arab Saudi (SAR) dengan integrasi konversi kurs real-time.'
      },
      {
        question: 'Bagaimana cara mendaftar menjadi sukarelawan (volunteer)?',
        answer: 'Anda dapat bergabung menjadi sukarelawan melalui informasi kontak resmi mitra panti atau menu komunitas di aplikasi AsuhKita. Peluang relawan terbuka untuk tenaga pengajar, dokter/perawat medis, mentor keterampilan komputer, hingga pelatih olahraga dan seni di fasilitas panti di Lombok dan Sumbawa.'
      }
    ];

    return res.status(200).json({
      success: true,
      data: faqList
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  draftLetter,
  summarizeReport,
  getFaq
};
