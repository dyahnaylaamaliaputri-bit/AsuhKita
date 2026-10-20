// Script: seed IoT device ke Supabase dengan UUID yang benar
require('dotenv').config();
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

(async () => {
  try {
    // Ambil UUID panti Al-Ikhlas dari Supabase (sudah ada dari seed migrations)
    const orph = await pool.query("SELECT id FROM orphanages WHERE name ILIKE '%Al-Ikhlas%' LIMIT 1");
    const orphId = orph.rows[0]?.id || 'a0000001-0000-0000-0000-000000000001';
    console.log('Orphanage ID:', orphId);

    // Insert IoT device dengan UUID fixed yang sama dengan yang ada di mock DB
    const deviceId = 'c0000001-0000-0000-0000-000000000001';
    await pool.query(
      'INSERT INTO iot_devices (id, orphanage_id, device_name, device_key) VALUES ($1, $2, $3, $4) ON CONFLICT (id) DO UPDATE SET device_name = EXCLUDED.device_name, device_key = EXCLUDED.device_key',
      [deviceId, orphId, 'Kotak Amal Al-Ikhlas #1', 'demo_device_key_001']
    );

    const check = await pool.query('SELECT id, device_name, device_key, is_active FROM iot_devices');
    console.log('\nIoT Devices di Supabase:');
    check.rows.forEach(r => console.log(' ', r.id, '|', r.device_name, '| key:', r.device_key, '| active:', r.is_active));

    await pool.end();
    console.log('\n✅ IoT device seed selesai!');
    console.log('   Gunakan device_id:', deviceId);
  } catch (err) {
    console.error('❌ Error:', err.message);
    await pool.end();
    process.exit(1);
  }
})();
