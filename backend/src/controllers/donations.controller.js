



const { query } = require('../config/database');
const { addBlock } = require('../blockchain/hash_chain');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');







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


    const packageCheck = await query(
      'SELECT id, name, amount_idr FROM sponsorship_packages WHERE id = $1',
      [package_id]
    );
    if (packageCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Paket tidak ditemukan.', error: 'PACKAGE_NOT_FOUND' });
    }


    const sponsorResult = await query(
      `INSERT INTO sponsorships (user_id, child_id, package_id, frequency, status)
       VALUES ($1, $2, $3, $4, 'active')
       RETURNING *`,
      [req.user.id, child_id, package_id, frequency]
    );


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









const createDonation = async (req, res, next) => {
  try {
    const {
      sponsorship_id,
      child_id,
      package_name,
      donor_name,
      donor_email,
      amount_original,
      currency = 'IDR',
      local_id,
      notes = '',
    } = req.body;

    const parsedAmount = Number(amount_original);
    if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Nominal donasi harus lebih dari 0.',
        error: 'INVALID_AMOUNT',
      });
    }

    if (
      !child_id ||
      typeof package_name !== 'string' ||
      package_name.trim().length === 0 ||
      typeof donor_name !== 'string' ||
      donor_name.trim().length === 0 ||
      typeof donor_email !== 'string' ||
      !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(donor_email.trim())
    ) {
      return res.status(400).json({
        success: false,
        message: 'Data anak, paket, nama, dan email donatur wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }

    const childResult = await query(
      `SELECT c.id, c.alias, o.name AS orphanage_name
       FROM children c
       JOIN orphanages o ON o.id = c.orphanage_id
       WHERE c.id::text = $1`,
      [child_id.toString()]
    );
    if (childResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Anak asuh tidak ditemukan.',
        error: 'CHILD_NOT_FOUND',
      });
    }
    const child = childResult.rows[0];

    const validCurrencies = ['IDR', 'USD', 'SGD', 'EUR', 'SAR'];
    if (!validCurrencies.includes(currency)) {
      return res.status(400).json({
        success: false,
        message: `Mata uang tidak didukung. Pilih: ${validCurrencies.join(', ')}`,
        error: 'INVALID_CURRENCY',
      });
    }


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



    let rateUsed = 1;
    if (currency !== 'IDR') {
      const rateResult = await query(
        "SELECT rate_to_idr FROM exchange_rates WHERE currency = $1 ORDER BY fetched_at DESC LIMIT 1",
        [currency]
      );

      if (rateResult.rows.length > 0) {
        rateUsed = parseFloat(rateResult.rows[0].rate_to_idr);
      } else {

        const fallbackRates = { USD: 16000, SGD: 12000, EUR: 17000, SAR: 4300 };
        rateUsed = fallbackRates[currency] || 1;
      }
    }

    const amountIdr = Math.round(parsedAmount * rateUsed);
    const certificateCode = `CERT-${crypto.randomBytes(8).toString('hex').toUpperCase()}`;


    const donationResult = await query(
      `INSERT INTO donations
         (sponsorship_id, user_id, child_id, package_name, donor_name, donor_email,
          amount_original, currency, rate_used, amount_idr, source, local_id, notes, certificate_code)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
       RETURNING *`,
      [
        sponsorship_id || null,
        req.user.id,
        child.id,
        package_name.trim(),
        donor_name.trim(),
        donor_email.trim().toLowerCase(),
        parsedAmount,
        currency,
        rateUsed,
        amountIdr,
        'app',
        local_id || uuidv4(),
        notes,
        certificateCode,
      ]
    );

    const donation = donationResult.rows[0];



    const ledgerBlock = await addBlock('DONATION', donation.id, {
      donation_id: donation.id,
      user_id: req.user.id,
      donor_name: donation.donor_name,
      donor_email: donation.donor_email,
      child_id: donation.child_id,
      child_alias: child.alias,
      package_name: donation.package_name,
      certificate_code: certificateCode,
      amount_idr: amountIdr,
      currency,
      amount_original: parsedAmount,
      source: 'app',
    });

    return res.status(201).json({
      success: true,
      message: 'Donasi berhasil dicatat! Terima kasih atas kepedulianmu.',
      data: {
        donation,
        certificate_code: certificateCode,
        block_hash: ledgerBlock.hash,
        ledger_block: {
          block_index: ledgerBlock.block_index,
          hash: ledgerBlock.hash,
          block_type: ledgerBlock.block_type,
        },
        summary: {
          amount_original: parsedAmount,
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

const verifyDonationCertificate = async (req, res, next) => {
  try {
    const credential = req.params.code.trim();
    const code = /^CERT-/i.test(credential)
      ? credential.toUpperCase()
      : credential.toLowerCase();
    const providedHash = req.query.hash?.toString().trim().toLowerCase();
    const result = await query(
      `SELECT d.certificate_code, d.donor_name, d.donor_email,
              c.alias AS child_alias, o.name AS orphanage_name,
              d.package_name, d.amount_idr, d.created_at,
              lb.hash AS ledger_hash, lb.block_index
       FROM donations d
       JOIN ledger_blocks lb
         ON lb.ref_id = d.id AND lb.block_type = 'DONATION'
       LEFT JOIN children c ON c.id = d.child_id
       LEFT JOIN orphanages o ON o.id = c.orphanage_id
       WHERE d.certificate_code = $1 OR lb.hash = $1
       ORDER BY lb.block_index DESC
       LIMIT 1`,
      [code]
    );
    const certificate = result.rows[0];
    const isValid = Boolean(
      certificate &&
      (!providedHash || certificate.ledger_hash.toLowerCase() === providedHash)
    );

    return res.status(200).json({
      success: true,
      data: isValid
        ? {
            valid: true,
            certificate: {
              certCode: certificate.certificate_code,
              donor: certificate.donor_name,
              child: certificate.child_alias || 'Anak Asuh',
              orphanage: certificate.orphanage_name || 'Panti Asuhan',
              amount: `Rp ${Number(certificate.amount_idr).toLocaleString('id-ID')} (${certificate.package_name})`,
              timestamp: certificate.created_at,
              hash: certificate.ledger_hash,
              blockIndex: certificate.block_index,
            },
          }
        : {
            valid: false,
            message: 'Kode sertifikat tidak ditemukan atau hash tidak cocok.',
          },
    });
  } catch (err) {
    next(err);
  }
};





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







const syncOfflineDonations = async (req, res, next) => {
  try {
    const { donations } = req.body;

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


        let rateUsed = parseFloat(d.rate_used) || 1;
        const amountIdr = Math.round(parseFloat(d.amount_original) * rateUsed);


        const donResult = await query(
          `INSERT INTO donations
             (sponsorship_id, user_id, amount_original, currency, rate_used, amount_idr, source, local_id)
           VALUES ($1, $2, $3, $4, $5, $6, 'offline', $7)
           RETURNING id`,
          [d.sponsorship_id || null, req.user.id, d.amount_original, d.currency || 'IDR', rateUsed, amountIdr, d.local_id || uuidv4()]
        );

        const donationId = donResult.rows[0].id;


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

module.exports = {
  createSponsorship,
  createDonation,
  verifyDonationCertificate,
  getDonationHistory,
  syncOfflineDonations,
  getMySponsorships,
};
