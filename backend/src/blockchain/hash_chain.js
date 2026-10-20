// File: backend/src/blockchain/hash_chain.js
// Fungsi: Modul SHA-256 hash chain untuk ledger donasi AsuhKita
// PBI-032, PBI-034, PBI-035 — FR-27, FR-28, NFR-05
//
// Penting:
// - Ini adalah hash chain TERPUSAT di satu server (bukan blockchain terdesentralisasi)
// - Fungsinya sebagai audit trail tamper-evident untuk kebutuhan akademik
// - Kelemahan: admin yang menguasai DB bisa menghitung ulang seluruh rantai
// - Hal ini dijelaskan jujur di laporan

const crypto = require('crypto');
const { query } = require('../config/database');

/**
 * generatePayloadHash — Hash data payload transaksi
 *
 * Payload adalah data inti transaksi (misal: data donasi).
 * Di-hash agar blok tidak menyimpan data mentah (yang bisa berisi info sensitif).
 *
 * @param {object} payloadData - Data transaksi (object)
 * @returns {string}           - SHA-256 hash dalam format hex
 */
const generatePayloadHash = (payloadData) => {
  const json = JSON.stringify(payloadData, Object.keys(payloadData).sort()); // sort keys agar konsisten
  return crypto.createHash('sha256').update(json).digest('hex');
};

/**
 * generateBlockHash — Hash satu blok ledger
 *
 * Rumus dari dokumen:
 * hash_i = SHA256(index_i || timestamp_i || type_i || payload_hash_i || hash_{i-1})
 *
 * @param {number} index        - Urutan blok
 * @param {string} timestamp    - ISO timestamp
 * @param {string} type         - Tipe blok: GENESIS, DONATION, REPORT, CERTIFICATE, IOT_EVENT
 * @param {string} payloadHash  - Hash dari data payload
 * @param {string} prevHash     - Hash blok sebelumnya
 * @returns {string}            - SHA-256 hash blok dalam format hex
 */
const generateBlockHash = (index, timestamp, type, payloadHash, prevHash) => {
  const data = `${index}${timestamp}${type}${payloadHash}${prevHash}`;
  return crypto.createHash('sha256').update(data).digest('hex');
};

/**
 * addBlock — Tambahkan blok baru ke rantai
 *
 * Langkah:
 * 1. Ambil blok terakhir dari database (untuk dapatkan prev_hash dan index berikutnya)
 * 2. Hitung payload_hash dari data transaksi
 * 3. Hitung hash blok baru
 * 4. INSERT ke tabel ledger_blocks
 *
 * @param {string} type       - Tipe blok (DONATION, REPORT, CERTIFICATE, IOT_EVENT)
 * @param {string|null} refId - UUID referensi ke tabel asal (donations.id, dsb)
 * @param {object} payload    - Data transaksi yang di-hash
 * @returns {object}          - Blok yang baru dibuat
 */
const addBlock = async (type, refId, payload) => {
  // 1. Ambil blok terakhir untuk mendapatkan index dan prev_hash
  const lastBlockResult = await query(
    'SELECT block_index, hash FROM ledger_blocks ORDER BY block_index DESC LIMIT 1'
  );

  if (lastBlockResult.rows.length === 0) {
    throw new Error('Genesis block tidak ditemukan. Jalankan migrasi SQL terlebih dahulu.');
  }

  const lastBlock = lastBlockResult.rows[0];
  const newIndex = lastBlock.block_index + 1;
  const prevHash = lastBlock.hash;
  const timestamp = new Date().toISOString();

  // 2. Hitung hash payload
  const payloadHash = generatePayloadHash(payload);

  // 3. Hitung hash blok baru
  const blockHash = generateBlockHash(newIndex, timestamp, type, payloadHash, prevHash);

  // 4. Simpan ke database
  const result = await query(
    `INSERT INTO ledger_blocks (block_index, block_type, ref_id, payload_hash, prev_hash, hash, created_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [newIndex, type, refId, payloadHash, prevHash, blockHash, timestamp]
  );

  return result.rows[0];
};

/**
 * verifyChain — Verifikasi seluruh rantai hash
 *
 * Proses:
 * 1. Ambil semua blok dari database urut berdasarkan index
 * 2. Untuk setiap blok (mulai dari blok ke-1):
 *    a. Hitung ulang hash blok menggunakan data tersimpan di DB
 *    b. Bandingkan dengan hash tersimpan
 *    c. Pastikan prev_hash = hash blok sebelumnya
 * 3. Jika ada ketidaksesuaian → kembalikan info blok yang rusak
 *
 * @returns {object} - { valid: boolean, total_blocks, invalid_block?: object }
 */
const verifyChain = async () => {
  const result = await query(
    'SELECT * FROM ledger_blocks ORDER BY block_index ASC'
  );

  const blocks = result.rows;

  if (blocks.length === 0) {
    return { valid: false, message: 'Tidak ada blok dalam ledger.' };
  }

  // Verifikasi genesis block
  const genesis = blocks[0];
  if (genesis.block_index !== 0 || genesis.block_type !== 'GENESIS') {
    return {
      valid: false,
      message: 'Genesis block tidak valid.',
      invalid_block: genesis,
    };
  }

  // Verifikasi blok ke-1 dst
  for (let i = 1; i < blocks.length; i++) {
    const block = blocks[i];
    const prevBlock = blocks[i - 1];

    // Cek prev_hash cocok dengan hash blok sebelumnya
    if (block.prev_hash !== prevBlock.hash) {
      return {
        valid: false,
        message: `Rantai rusak pada blok ke-${block.block_index}. prev_hash tidak cocok.`,
        invalid_block: {
          block_index: block.block_index,
          block_type: block.block_type,
          ref_id: block.ref_id,
          created_at: block.created_at,
          stored_hash: block.hash,
          expected_prev_hash: prevBlock.hash,
          actual_prev_hash: block.prev_hash,
        },
      };
    }

    // Hitung ulang hash blok menggunakan data tersimpan
    const recalculatedHash = generateBlockHash(
      block.block_index,
      block.created_at instanceof Date
        ? block.created_at.toISOString()
        : new Date(block.created_at).toISOString(),
      block.block_type,
      block.payload_hash,
      block.prev_hash
    );

    // Bandingkan hash yang tersimpan vs yang dihitung ulang
    if (block.hash !== recalculatedHash) {
      return {
        valid: false,
        message: `Blok ke-${block.block_index} telah dimodifikasi! Hash tidak cocok.`,
        invalid_block: {
          block_index: block.block_index,
          block_type: block.block_type,
          ref_id: block.ref_id,
          created_at: block.created_at,
          stored_hash: block.hash,
          recalculated_hash: recalculatedHash,
        },
      };
    }
  }

  return {
    valid: true,
    message: `Semua ${blocks.length} blok valid. Rantai utuh.`,
    total_blocks: blocks.length,
  };
};

module.exports = { addBlock, verifyChain, generatePayloadHash, generateBlockHash };
