// File: backend/src/controllers/donations.controller.js
// Fungsi: Logic donasi, sponsorship, dan konversi mata uang
// PBI-023, PBI-024, PBI-026, PBI-029 — FR-22..FR-26

const { query } = require('../config/database');
const { addBlock } = require('../blockchain/hash_chain');
const { v4: uuidv4 } = require('uuid');

// ============================================================
// CREATE SPONSORSHIP — Buat sponsorship baru
// POST /api/sponsorships
// FR-22: Donatur membuat sponsorship dengan frekuensi sekali/bulanan
// PBI-026: POST /sponsorships
// ============================================================
const createSponsorship = async (req, res, next) => {
  try {
    const { child_id, package_id, frequency = 'monthly' } = req.body;

    if (!child_id || !package_id) {
      return res.status(400).json({
        success: false,
        message: 'child_id dan package_id wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }

    if (!['once', 'monthly'].includes(frequency)) {
      return res.status(400).json({
        success: false,
        message: 'Frekuensi harus "once" atau "monthly".',
        error: 'INVALID_FREQUENCY',
      });
    }

    // Cek apakah anak tersedia
    const childCheck = await query(
      "SELECT id, alias, status FROM children WHERE id = $1",
      [child_id]
    );

    if (childCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Anak tidak ditemukan.', error: 'CHILD_NOT_FOUND' });
    }

    if (childCheck.rows[0].status !== 'Tersedia') {
      return res.status(409).json({
        success: false,
        message: `${childCheck.rows[0].alias} tidak tersedia untuk disponsori saat ini.`,
        error: 'CHILD_NOT_AVAILABLE',
      });
    }

    // Cek sponsorship aktif ganda (FR-22: satu donatur per anak)
    const existingCheck = await query(
      "SELECT id FROM sponsorships WHERE user_id = $1 AND child_id = $2 AND status = 'active'",
      [req.user.id, child_id]
    );

    if (existingCheck.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'Kamu sudah menjadi orang tua asuh anak ini.',
        error: 'ALREADY_SPONSORED',
      });
    }

    // Cek paket ada
    const packageCheck = await query(
      'SELECT id, name, amount_idr FROM sponsorship_packages WHERE id = $1',
      [package_id]
    );
    if (packageCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Paket tidak ditemukan.', error: 'PACKAGE_NOT_FOUND' });
    }

    // Buat sponsorship
    const sponsorResult = await query(
      `INSERT INTO sponsorships (user_id, child_id, package_id, frequency, status)
       VALUES ($1, $2, $3, $4, 'active')
       RETURNING *`,
      [req.user.id, child_id, package_id, frequency]
    );

    // Update status anak jika frekuensi bulanan
    if (frequency === 'monthly') {
      await query(
        "UPDATE children SET status = 'Disponsori' WHERE id = $1",
        [child_id]
      );
    }

    return res.status(201).json({
      success: true,
      message: 'Sponsorship berhasil dibuat!',
      data: sponsorResult.rows[0],
    });
  } catch (err) {
    next(err);
  }
};

// ============================================================
// CREATE DONATION — Buat donasi (simulasi, bukan uang nyata)
// POST /api/donations
// FR-23: Konversi mata uang (IDR, USD, SGD, EUR, SAR)
// FR-25: Pembayaran simulasi
// FR-27: Blok ledger dibuat otomatis
// PBI-026: POST /donations dengan konversi kurs di server
// ============================================================
const createDonation = async (req, res, next) => {
  try {
    const {
      sponsorship_id,
      amount_original,
      currency = 'IDR',
      local_id,  // UUID dari device untuk idempotency offline sync
      notes = '',
    } = req.body;

    if (!amount_original || amount_original <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Nominal donasi harus lebih dari 0.',
        error: 'INVALID_AMOUNT',
      });
    }

    const validCurrencies = ['IDR', 'USD', 'SGD', 'EUR', 'SAR'];
    if (!validCurrencies.includes(currency)) {
      return res.status(400).json({
        success: false,
        message: `Mata uang tidak didukung. Pilih: ${validCurrencies.join(', ')}`,
        error: 'INVALID_CURRENCY',
      });
    }

    // Idempotency: cegah donasi ganda saat sync offline (FR-20, PBI-030)
    if (local_id) {
      const existingDonation = await query(
        'SELECT id FROM donations WHERE local_id = $1',
        [local_id]
      );
      if (existingDonation.rows.length > 0) {
        return res.status(200).json({
          success: true,
          message: 'Donasi ini sudah tersinkronisasi sebelumnya.',
          data: existingDonation.rows[0],
          is_duplicate: true,
        });
      }
    }

    // Ambil kurs dari database (cache kurs terakhir dari API eksternal)
    // FR-24: kurs diambil dari API eksternal dengan cadangan kurs terakhir di database
    let rateUsed = 1; // default IDR ke IDR
    if (currency !== 'IDR') {
      const rateResult = await query(
        "SELECT rate_to_idr FROM exchange_rates WHERE currency = $1 ORDER BY fetched_at DESC LIMIT 1",
        [currency]
      );

      if (rateResult.rows.length > 0) {
        rateUsed = parseFloat(rateResult.rows[0].rate_to_idr);
      } else {
        // Kurs cadangan statis jika API belum pernah dipanggil
        const fallbackRates = { USD: 16000, SGD: 12000, EUR: 17000, SAR: 4300 };
        rateUsed = fallbackRates[currency] || 1;
      }
    }

    const amountIdr = Math.round(parseFloat(amount_original) * rateUsed);

    // Simpan donasi ke database
    const donationResult = await query(
      `INSERT INTO donations
         (sponsorship_id, user_id, amount_original, currency, rate_used, amount_idr, source, local_id, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        sponsorship_id || null,
        req.user.id,
        parseFloat(amount_original),
        currency,
        rateUsed,
        amountIdr,
        'app',
        local_id || uuidv4(),
        notes,
      ]
    );

    const donation = donationResult.rows[0];

    // FR-27: Buat blok ledger secara otomatis setiap donasi berhasil
    // PBI-035: Pembuatan blok otomatis saat donasi masuk
    const ledgerBlock = await addBlock('DONATION', donation.id, {
      donation_id: donation.id,
      user_id: req.user.id,
      amount_idr: amountIdr,
      currency,
      amount_original: parseFloat(amount_original),
      source: 'app',
    });

    return res.status(201).json({
      success: true,
      message: 'Donasi berhasil dicatat! Terima kasih atas kepedulianmu.',
      data: {
        donation,
        ledger_block: {
          block_index: ledgerBlock.block_index,
          hash: ledgerBlock.hash,
          block_type: ledgerBlock.block_type,
        },
        summary: {
          amount_original: parseFloat(amount_original),
          currency,
          rate_used: rateUsed,
          amount_idr: amountIdr,
          amount_idr_formatted: `Rp ${amountIdr.toLocaleString('id-ID')}`,
        },
      },
    });
  } catch (err) {
    next(err);
  }
};

// ============================================================
// GET DONATION HISTORY — Riwayat donasi user
// GET /api/donations/history
// FR-26: Donatur melihat riwayat donasi beserta kurs yang dipakai
// PBI-029: GET /donations/history
// ============================================================
const getDonationHistory = async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const result = await query(
      `SELECT d.id, d.amount_original, d.currency, d.rate_used, d.amount_idr,
              d.source, d.status, d.notes, d.created_at,
              d.local_id,
              c.alias AS child_alias, c.avatar AS child_avatar,
              sp.name AS package_name, s.frequency,
              lb.hash AS ledger_hash, lb.block_index AS ledger_block_index
       FROM donations d
       LEFT JOIN sponsorships s ON d.sponsorship_id = s.id
       LEFT JOIN children c ON s.child_id = c.id
       LEFT JOIN sponsorship_packages sp ON s.package_id = sp.id
       LEFT JOIN ledger_blocks lb ON lb.ref_id = d.id AND lb.block_type = 'DONATION'
       WHERE d.user_id = $1
       ORDER BY d.created_at DESC
       LIMIT $2 OFFSET $3`,
      [req.user.id, limit, offset]
    );

    const countResult = await query(
      'SELECT COUNT(*) FROM donations WHERE user_id = $1',
      [req.user.id]
    );

    return res.status(200).json({
      success: true,
      data: result.rows,
      pagination: {
        page, limit,
        total: parseInt(countResult.rows[0].count),
        total_pages: Math.ceil(parseInt(countResult.rows[0].count) / limit),
      },
    });
  } catch (err) {
    next(err);
  }
};

// ============================================================
// SYNC OFFLINE DONATIONS — Sinkronisasi antrean offline dari SQLite
// POST /api/donations/sync
// FR-20: Donasi offline disinkronkan otomatis saat online
// PBI-030: Antrean donasi offline + sinkronisasi otomatis
// ============================================================
const syncOfflineDonations = async (req, res, next) => {
  try {
    const { donations } = req.body; // Array dari pending donations di SQLite Flutter

    if (!Array.isArray(donations) || donations.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Tidak ada donasi yang perlu disinkronisasi.',
        error: 'EMPTY_SYNC_DATA',
      });
    }

    const results = [];

    for (const d of donations) {
      try {
        // Cek idempotency — sudah tersinkronisasi sebelumnya?
        if (d.local_id) {
          const existing = await query(
            'SELECT id FROM donations WHERE local_id = $1',
            [d.local_id]
          );
          if (existing.rows.length > 0) {
            results.push({ local_id: d.local_id, status: 'duplicate', donation_id: existing.rows[0].id });
            continue;
          }
        }

        // Ambil kurs
        let rateUsed = parseFloat(d.rate_used) || 1;
        const amountIdr = Math.round(parseFloat(d.amount_original) * rateUsed);

        // Simpan donasi
        const donResult = await query(
          `INSERT INTO donations
             (sponsorship_id, user_id, amount_original, currency, rate_used, amount_idr, source, local_id)
           VALUES ($1, $2, $3, $4, $5, $6, 'offline', $7)
           RETURNING id`,
          [d.sponsorship_id || null, req.user.id, d.amount_original, d.currency || 'IDR', rateUsed, amountIdr, d.local_id || uuidv4()]
        );

        const donationId = donResult.rows[0].id;

        // Buat blok ledger
        await addBlock('DONATION', donationId, {
          donation_id: donationId,
          user_id: req.user.id,
          amount_idr: amountIdr,
          source: 'offline',
        });

        results.push({ local_id: d.local_id, status: 'synced', donation_id: donationId });
      } catch (itemErr) {
        results.push({ local_id: d.local_id, status: 'failed', error: itemErr.message });
      }
    }

    return res.status(200).json({
      success: true,
      message: `Sinkronisasi selesai. ${results.filter(r => r.status === 'synced').length} donasi berhasil.`,
      results,
    });
  } catch (err) {
    next(err);
  }
};

// ============================================================
// GET MY SPONSORSHIPS — Daftar sponsorship aktif user
// GET /api/sponsorships
// ============================================================
const getMySponsorships = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT s.id, s.frequency, s.status, s.started_at,
              c.alias, c.age, c.avatar, c.need_category,
              o.name AS orphanage_name, o.city,
              sp.name AS package_name, sp.amount_idr
       FROM sponsorships s
       JOIN children c ON s.child_id = c.id
       JOIN orphanages o ON c.orphanage_id = o.id
       JOIN sponsorship_packages sp ON s.package_id = sp.id
       WHERE s.user_id = $1
       ORDER BY s.started_at DESC`,
      [req.user.id]
    );

    return res.status(200).json({ success: true, data: result.rows });
  } catch (err) {
    next(err);
  }
};

module.exports = { createSponsorship, createDonation, getDonationHistory, syncOfflineDonations, getMySponsorships };
