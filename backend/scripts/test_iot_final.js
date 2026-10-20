// Script: Test IoT event ke Supabase (versi final)
require('dotenv').config();
const crypto = require('crypto');
const http = require('http');

const DEVICE_ID  = 'c0000001-0000-0000-0000-000000000001';
const DEVICE_KEY = 'demo_device_key_001';
const AMOUNT     = 75000;
const SECRET     = process.env.IOT_DEVICE_SECRET || 'asuhkita_iot_dev_secret';

const timestamp = new Date().toISOString();
const payload   = `${DEVICE_ID}|${AMOUNT}|${timestamp}`;
const hmac      = crypto.createHmac('sha256', SECRET).update(payload).digest('hex');

const body = JSON.stringify({ device_id: DEVICE_ID, device_key: DEVICE_KEY, amount_sim: AMOUNT, timestamp, hmac_signature: hmac });

const req = http.request({ hostname: 'localhost', port: 3000, path: '/api/iot/events', method: 'POST',
  headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) }
}, res => {
  let d = '';
  res.on('data', c => d += c);
  res.on('end', () => {
    const r = JSON.parse(d);
    if (r.success) {
      console.log('✅ IoT Event BERHASIL disimpan ke Supabase!');
      console.log('   Device   :', r.data.device_name);
      console.log('   Nominal  : Rp', r.data.amount_sim.toLocaleString('id-ID'));
      console.log('   Blok     :', r.data.ledger_block.block_index);
      console.log('   Hash     :', r.data.ledger_block.hash.substring(0, 30) + '...');
    } else {
      console.log('❌ Gagal:', r.message);
    }
  });
});
req.write(body);
req.end();
