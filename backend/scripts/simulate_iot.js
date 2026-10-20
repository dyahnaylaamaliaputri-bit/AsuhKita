// File: backend/scripts/simulate_iot.js
// Fungsi: Skrip simulasi event IoT kotak amal (FR-54 — fallback tanpa hardware ESP32)
// Cara pakai: node scripts/simulate_iot.js
//
// Pastikan backend sudah berjalan (node index.js) sebelum menjalankan skrip ini

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const crypto = require('crypto');
const http = require('http');

// ---- Konfigurasi Simulasi ----
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';
const DEVICE_ID   = 'c0000001-0000-0000-0000-000000000001'; // dari seed iot_devices
const DEVICE_KEY  = 'demo_device_key_001';
const AMOUNT_SIM  = 50000; // nominal simulasi dalam Rupiah
const IOT_SECRET  = process.env.IOT_DEVICE_SECRET || 'asuhkita_iot_dev_secret';

// ---- Generate HMAC ----
const timestamp = new Date().toISOString();
const payload   = `${DEVICE_ID}|${AMOUNT_SIM}|${timestamp}`;
const hmac      = crypto.createHmac('sha256', IOT_SECRET).update(payload).digest('hex');

const body = JSON.stringify({
  device_id:      DEVICE_ID,
  device_key:     DEVICE_KEY,
  amount_sim:     AMOUNT_SIM,
  timestamp,
  hmac_signature: hmac,
});

console.log('🚀 Mengirim simulasi event IoT kotak amal...');
console.log('   Device   :', DEVICE_ID);
console.log('   Nominal  : Rp', AMOUNT_SIM.toLocaleString('id-ID'));
console.log('   Timestamp:', timestamp);
console.log('   HMAC     :', hmac);
console.log('');

// ---- Kirim request ke backend ----
const url = new URL('/api/iot/events', BACKEND_URL);
const options = {
  hostname: url.hostname,
  port:     url.port || 3000,
  path:     url.pathname,
  method:   'POST',
  headers:  { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) },
};

const req = http.request(options, (res) => {
  let data = '';
  res.on('data', (chunk) => data += chunk);
  res.on('end', () => {
    const response = JSON.parse(data);
    if (response.success) {
      console.log('✅ Event berhasil diterima!');
      console.log('   Event ID    :', response.data?.event_id);
      console.log('   Blok Ledger :', response.data?.ledger_block?.block_index);
      console.log('   Hash Blok   :', response.data?.ledger_block?.hash?.substring(0, 20) + '...');
    } else {
      console.log('❌ Event ditolak:', response.message);
    }
  });
});

req.on('error', (e) => {
  console.error('❌ Koneksi gagal:', e.message);
  console.log('   Pastikan backend berjalan: cd backend && node index.js');
});

req.write(body);
req.end();
