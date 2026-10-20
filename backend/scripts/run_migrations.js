// Script: jalankan migrations ke Supabase
require('dotenv').config();
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

async function runMigrations() {
  console.log('📦 Menjalankan migrations ke Supabase...\n');

  try {
    // File 1: migrations.sql
    console.log('1️⃣  migrations.sql (tabel utama + seed data)...');
    const sql1 = fs.readFileSync(path.join(__dirname, '../src/config/migrations.sql'), 'utf8');
    await pool.query(sql1);
    console.log('   ✅ Selesai!\n');

    // File 2: migrations_additional.sql
    console.log('2️⃣  migrations_additional.sql (exchange_rates, certificates)...');
    const sql2 = fs.readFileSync(path.join(__dirname, '../src/config/migrations_additional.sql'), 'utf8');
    await pool.query(sql2);
    console.log('   ✅ Selesai!\n');

    // Verifikasi tabel
    const tables = await pool.query(
      "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename"
    );
    console.log('📋 Tabel yang terbuat di Supabase:');
    tables.rows.forEach(r => console.log('   ✓', r.tablename));

    // Cek genesis block
    const genesis = await pool.query("SELECT block_index, hash FROM ledger_blocks WHERE block_type = 'GENESIS'");
    console.log('\n⛓️  Genesis Block:', genesis.rows.length > 0 ? '✅ Ada!' : '❌ Tidak ada');

    // Cek seed data
    const [children, orphanages, packages, rates] = await Promise.all([
      pool.query('SELECT COUNT(*) FROM children'),
      pool.query('SELECT COUNT(*) FROM orphanages'),
      pool.query('SELECT COUNT(*) FROM sponsorship_packages'),
      pool.query('SELECT COUNT(*) FROM exchange_rates'),
    ]);

    console.log('\n📊 Data Seed:');
    console.log('   Panti asuhan  :', orphanages.rows[0].count);
    console.log('   Anak          :', children.rows[0].count);
    console.log('   Paket sponsor :', packages.rows[0].count);
    console.log('   Kurs mata uang:', rates.rows[0].count);

    console.log('\n✅ ===================================');
    console.log('   Database Supabase siap digunakan!');
    console.log('   Jalankan: node index.js');
    console.log('=====================================');

  } catch (err) {
    console.error('❌ Error:', err.message);
    throw err;
  } finally {
    await pool.end();
  }
}

runMigrations().catch(() => process.exit(1));
