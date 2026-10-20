// File: backend/index.js
// Fungsi: Entry point — menjalankan server Express dan test koneksi database

require('dotenv').config();
const app = require('./src/app');
const { pool } = require('./src/config/database');

const PORT = process.env.PORT || 3000;

// Test koneksi database sebelum server mulai
async function startServer() {
  try {
    // Coba query sederhana untuk memastikan koneksi ke Supabase berhasil
    await pool.query('SELECT NOW()');
    console.log('✅ Koneksi ke Supabase PostgreSQL berhasil!');

    // Jalankan server Express
    app.listen(PORT, () => {
      console.log('');
      console.log('╔══════════════════════════════════════╗');
      console.log('║   AsuhKita Backend Server v1.0.0     ║');
      console.log('╠══════════════════════════════════════╣');
      console.log(`║   Berjalan di: http://localhost:${PORT}  ║`);
      console.log(`║   Mode: ${process.env.NODE_ENV || 'development'}                  ║`);
      console.log('╚══════════════════════════════════════╝');
      console.log('');
      console.log('📌 Endpoint yang tersedia:');
      console.log(`   [AUTH]      POST /api/auth/register | login | refresh | logout`);
      console.log(`   [AUTH]      GET  /api/auth/me`);
      console.log(`   [PROFILE]   GET/PUT /api/users/profile`);
      console.log(`   [PROFILE]   POST /api/users/profile/photo`);
      console.log(`   [FEEDBACK]  POST/GET /api/feedback`);
      console.log(`   [CHILDREN]  GET /api/children | /api/children/:id | /api/children/packages`);
      console.log(`   [DONATIONS] POST /api/donations | /api/donations/sponsorships`);
      console.log(`   [DONATIONS] GET /api/donations/history | POST /api/donations/sync`);
      console.log(`   [LEDGER]    GET /api/ledger | /api/ledger/verify | /api/ledger/block/:index`);
      console.log(`   [LEDGER]    POST /api/ledger/certificates | /api/ledger/report`);
      console.log(`   [LBS]       GET /api/orphanages | /api/orphanages/nearby`);
      console.log(`   [SCHEDULE]  POST/GET /api/orphanages/schedules`);
      console.log(`   [GAME]      POST /api/game/scores | /api/game/steps`);
      console.log(`   [GAME]      GET  /api/game/leaderboard | /api/game/my-scores | /api/game/steps`);
      console.log(`   [IOT]       POST /api/iot/events | /api/iot/devices`);
      console.log(`   [IOT]       GET  /api/iot/events | /api/iot/test-hmac`);
      console.log('');
    });
  } catch (err) {
    console.error('❌ Gagal terhubung ke database:', err.message);
    console.error('Periksa DATABASE_URL di file .env kamu!');
    process.exit(1); // Hentikan server jika database tidak bisa diakses
  }
}

startServer();
