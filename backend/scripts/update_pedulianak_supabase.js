// File: backend/scripts/update_pedulianak_supabase.js
// Fungsi: Memperbarui data anak asuh di Supabase PostgreSQL dengan data & foto asli dari PeduliAnak.org

const { Pool } = require('pg');

const pool = new Pool({
  host: 'aws-0-ap-northeast-1.pooler.supabase.com',
  port: 6543,
  database: 'postgres',
  user: 'postgres.aigrpoxfjwyequzcuzda',
  password: 'Teorimobile3#',
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 20000,
});

const peduliAnakChildren = [
  {
    alias: 'Arfa',
    age: 8,
    gender: 'L',
    need_category: 'Pendidikan',
    story_summary: 'Arfa adalah anak yang ceria dan penuh semangat belajar di Pusat Peduli Anak Lombok. Bercita-cita menjadi arsitek dan sangat menyukai matematika.',
    avatar: 'https://www.pedulianak.org/wp-content/uploads/2025/08/6-200x300.jpg',
    status: 'Tersedia'
  },
  {
    alias: 'Ayra',
    age: 6,
    gender: 'P',
    need_category: 'Kebutuhan Sehari-hari',
    story_summary: 'Ayra adalah anak bungsu yang periang dan suka menggambar pemandangan alam. Membutuhkan dukungan nutrisi, pakaian, dan perlengkapan harian.',
    avatar: 'https://www.pedulianak.org/wp-content/uploads/2026/07/Ayra-200x300.jpg',
    status: 'Tersedia'
  },
  {
    alias: 'Azkya',
    age: 9,
    gender: 'P',
    need_category: 'Pendidikan',
    story_summary: 'Azkya rajin membaca buku cerita dan bercita-cita menjadi guru SD. Membutuhkan seragam sekolah, tas, dan buku-buku pelajaran.',
    avatar: 'https://www.pedulianak.org/wp-content/uploads/2026/07/DSCF6859-200x300.jpg',
    status: 'Tersedia'
  },
  {
    alias: 'Elsa Saputri',
    age: 10,
    gender: 'P',
    need_category: 'Perawatan Esensial',
    story_summary: 'Elsa anak yang mandiri dan peduli pada teman-temannya di asrama. Membutuhkan dukungan biaya kesehatan berkala dan suplemen vitamin.',
    avatar: 'https://www.pedulianak.org/wp-content/uploads/2026/07/DSCF6838-200x300.jpg',
    status: 'Tersedia'
  },
  {
    alias: 'Rangga',
    age: 11,
    gender: 'L',
    need_category: 'Pendidikan',
    story_summary: 'Rangga gemar berolahraga sepak bola dan sains alam. Sangat antusias mengikuti kegiatan les ekstrakurikuler sains di panti asuhan.',
    avatar: 'https://www.pedulianak.org/wp-content/uploads/2026/07/DSCF6843-200x300.jpg',
    status: 'Tersedia'
  },
  {
    alias: 'Sasmita',
    age: 7,
    gender: 'P',
    need_category: 'Gizi',
    story_summary: 'Sasmita menyukai kesenian tari tradisional dan menyanyi. Memerlukan bantuan paket makanan bergizi seimbang dan susu pertumbuhan.',
    avatar: 'https://www.pedulianak.org/wp-content/uploads/2026/08/DSCF8123-200x300.jpg',
    status: 'Tersedia'
  },
  {
    alias: 'Seregar',
    age: 12,
    gender: 'L',
    need_category: 'Pendidikan',
    story_summary: 'Seregar adalah siswa berprestasi di sekolah menengah dan memiliki cita-cita menjadi insinyur teknik elektro masa depan.',
    avatar: 'https://www.pedulianak.org/wp-content/uploads/2026/08/DSCF7024-200x300.jpg',
    status: 'Tersedia'
  },
  {
    alias: 'Shiddiq',
    age: 9,
    gender: 'L',
    need_category: 'Kebutuhan Sehari-hari',
    story_summary: 'Shiddiq anak yang santun dan suka membantu pengurus panti merawat taman. Membutuhkan perlengkapan sekolah dan pakaian asrama.',
    avatar: 'https://www.pedulianak.org/wp-content/uploads/2026/08/DSCF8114-200x300.jpg',
    status: 'Tersedia'
  },
  {
    alias: 'Hamdi',
    age: 13,
    gender: 'L',
    need_category: 'Pendidikan',
    story_summary: 'Hamdi gemar mempelajari teknologi komputer dan aktif memimpin kegiatan doa bersama adik-adik di panti asuhan.',
    avatar: 'https://www.pedulianak.org/wp-content/uploads/2022/10/Hamdi.jpg',
    status: 'Tersedia'
  },
  {
    alias: 'Dika & Sahabat',
    age: 8,
    gender: 'L',
    need_category: 'Umum',
    story_summary: 'Kelompok belajar ceria di panti asuhan yang membutuhkan ruang bermain edukatif dan buku-buku ensiklopedia bergambar.',
    avatar: 'https://www.pedulianak.org/wp-content/uploads/2024/08/DSCF0645-1-563x375.jpg',
    status: 'Tersedia'
  },
  {
    alias: 'Fajar & Bintang',
    age: 11,
    gender: 'L',
    need_category: 'Pendidikan',
    story_summary: 'Dua sahabat yang rajin belajar sains dan komputer di Pusat Edukasi Peduli Anak. Membutuhkan perlengkapan praktikum sains dasar.',
    avatar: 'https://www.pedulianak.org/wp-content/uploads/2024/08/DSCF4843-1-570x365.jpg',
    status: 'Tersedia'
  }
];

async function updateChildrenData() {
  const client = await pool.connect();
  try {
    console.log('✅ Terhubung ke Supabase PostgreSQL...');

    // Ambil daftar panti untuk relasi foreign key
    const orphanagesRes = await client.query('SELECT id FROM orphanages LIMIT 5');
    const orphanageIds = orphanagesRes.rows.map(r => r.id);

    if (orphanageIds.length === 0) {
      throw new Error('Belum ada data orphanages di database!');
    }

    console.log(`🏠 Ditemukan ${orphanageIds.length} data panti.`);

    // Bersihkan data lama jika belum ada donasi terkait, atau upsert
    console.log('🔄 Memperbarui data anak dengan data & foto asli pedulianak.org...');

    for (let i = 0; i < peduliAnakChildren.length; i++) {
      const ch = peduliAnakChildren[i];
      const orphId = orphanageIds[i % orphanageIds.length];

      // Cek apakah anak dengan alias ini sudah ada
      const checkRes = await client.query('SELECT id FROM children WHERE alias = $1', [ch.alias]);

      if (checkRes.rows.length > 0) {
        // Update data & foto yang sudah ada
        await client.query(
          `UPDATE children 
           SET age = $1, gender = $2, need_category = $3, story_summary = $4, avatar = $5, status = $6, updated_at = NOW()
           WHERE id = $7`,
          [ch.age, ch.gender, ch.need_category, ch.story_summary, ch.avatar, ch.status, checkRes.rows[0].id]
        );
        console.log(`   [UPDATE] ${ch.alias} -> Foto: ${ch.avatar}`);
      } else {
        // Insert anak baru
        await client.query(
          `INSERT INTO children (orphanage_id, alias, age, gender, need_category, story_summary, avatar, status)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [orphId, ch.alias, ch.age, ch.gender, ch.need_category, ch.story_summary, ch.avatar, ch.status]
        );
        console.log(`   [INSERT] ${ch.alias} -> Foto: ${ch.avatar}`);
      }
    }

    // Tampilkan total anak di database
    const countRes = await client.query('SELECT COUNT(*) FROM children');
    console.log(`\n🎉 SELESAI! Total data anak di Supabase sekarang: ${countRes.rows[0].count} anak.`);

    // Verifikasi sampel data
    const sample = await client.query('SELECT alias, age, need_category, avatar FROM children LIMIT 5');
    console.log('\n📋 Sampel data di Supabase:');
    sample.rows.forEach(r => {
      console.log(`   - ${r.alias} (${r.need_category}): ${r.avatar}`);
    });

  } catch (err) {
    console.error('❌ Gagal memperbarui data:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

updateChildrenData();
