



const { query } = require('../config/database');
const { verifyChain, addBlock, generatePayloadHash } = require('../blockchain/hash_chain');
const crypto = require('crypto');







const getLedger = async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const { type } = req.query;

    let sql = `
      SELECT lb.id, lb.block_index, lb.block_type, lb.ref_id,
             lb.payload_hash, lb.prev_hash, lb.hash, lb.created_at
      FROM ledger_blocks lb
    `;
    const params = [];

    if (type) {
      sql += ' WHERE lb.block_type = $1';
      params.push(type);
      params.push(limit);
      params.push(offset);
      sql += ` ORDER BY lb.block_index DESC LIMIT $2 OFFSET $3`;
    } else {
      params.push(limit);
      params.push(offset);
      sql += ` ORDER BY lb.block_index DESC LIMIT $1 OFFSET $2`;
    }

    const result = await query(sql, params);

    const countResult = await query(
      type
        ? 'SELECT COUNT(*) FROM ledger_blocks WHERE block_type = $1'
        : 'SELECT COUNT(*) FROM ledger_blocks',
      type ? [type] : []
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









const verifyLedger = async (req, res, next) => {
  try {
    const verificationResult = await verifyChain();
    const statusCode = verificationResult.valid ? 200 : 200;

    return res.status(statusCode).json({
      success: true,
      data: verificationResult,
    });
  } catch (err) {
    next(err);
  }
};





const getBlockDetail = async (req, res, next) => {
  try {
    const { index } = req.params;

    const result = await query(
      'SELECT * FROM ledger_blocks WHERE block_index = $1',
      [parseInt(index)]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Blok tidak ditemukan.',
        error: 'BLOCK_NOT_FOUND',
      });
    }

    return res.status(200).json({ success: true, data: result.rows[0] });
  } catch (err) {
    next(err);
  }
};







const issueCertificate = async (req, res, next) => {
  try {
    const { sponsorship_id } = req.body;

    if (!sponsorship_id) {
      return res.status(400).json({
        success: false,
        message: 'sponsorship_id wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }


    const sponsorResult = await query(
      `SELECT s.id, s.frequency, s.started_at, s.status,
              c.alias, c.age, c.need_category,
              o.name AS orphanage_name,
              u.name AS donor_name, u.email AS donor_email,
              sp.name AS package_name, sp.amount_idr
       FROM sponsorships s
       JOIN children c ON s.child_id = c.id
       JOIN orphanages o ON c.orphanage_id = o.id
       JOIN users u ON s.user_id = u.id
       JOIN sponsorship_packages sp ON s.package_id = sp.id
       WHERE s.id = $1 AND s.user_id = $2`,
      [sponsorship_id, req.user.id]
    );

    if (sponsorResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Sponsorship tidak ditemukan.',
        error: 'SPONSORSHIP_NOT_FOUND',
      });
    }

    const sponsorship = sponsorResult.rows[0];


    const verificationCode = crypto.randomBytes(4).toString('hex').toUpperCase();


    const certPayload = {
      sponsorship_id,
      donor_name: sponsorship.donor_name,
      child_alias: sponsorship.alias,
      orphanage: sponsorship.orphanage_name,
      package: sponsorship.package_name,
      issued_at: new Date().toISOString(),
      verification_code: verificationCode,
    };


    const ledgerBlock = await addBlock('CERTIFICATE', sponsorship_id, certPayload);




    const certificate = {
      id: `CERT-${verificationCode}`,
      verification_code: verificationCode,
      donor_name: sponsorship.donor_name,
      child_alias: sponsorship.alias,
      orphanage_name: sponsorship.orphanage_name,
      package_name: sponsorship.package_name,
      amount_idr: sponsorship.amount_idr,
      frequency: sponsorship.frequency,
      started_at: sponsorship.started_at,
      issued_at: new Date().toISOString(),
      ledger_block_index: ledgerBlock.block_index,
      ledger_hash: ledgerBlock.hash,

      qr_data: JSON.stringify({
        type: 'ASUHKITA_CERT',
        verification_code: verificationCode,
        ledger_block_index: ledgerBlock.block_index,
        ledger_hash: ledgerBlock.hash,
        verify_url: `/api/certificates/verify/${verificationCode}`,
      }),
    };

    return res.status(201).json({
      success: true,
      message: 'Sertifikat Orang Tua Asuh berhasil diterbitkan!',
      data: certificate,
    });
  } catch (err) {
    next(err);
  }
};






const verifyCertificate = async (req, res, next) => {
  try {
    const { code } = req.params;



    const blockResult = await query(
      `SELECT lb.block_index, lb.hash, lb.payload_hash, lb.created_at, lb.ref_id
       FROM ledger_blocks lb
       WHERE lb.block_type = 'CERTIFICATE'
       ORDER BY lb.block_index ASC`
    );


    let foundBlock = null;
    for (const block of blockResult.rows) {




    }


    const certResult = await query(
      `SELECT c.*, lb.hash AS ledger_hash, lb.block_index AS ledger_block_index
       FROM certificates c
       JOIN ledger_blocks lb ON c.ledger_block_id = lb.id
       WHERE c.verification_code = $1`,
      [code]
    ).catch(() => ({ rows: [] }));

    if (!certResult.rows || certResult.rows.length === 0) {
      return res.status(200).json({
        success: true,
        data: {
          valid: false,
          message: 'Kode verifikasi tidak ditemukan.',
        },
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        valid: true,
        certificate: certResult.rows[0],
      },
    });
  } catch (err) {
    next(err);
  }
};







const addReportBlock = async (req, res, next) => {
  try {
    const { child_id, period, summary, evidence_url } = req.body;

    if (!child_id || !period || !summary) {
      return res.status(400).json({
        success: false,
        message: 'child_id, period, dan summary wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }


    const reportResult = await query(
      `INSERT INTO progress_reports (child_id, period, summary, evidence_url)
       VALUES ($1, $2, $3, $4) RETURNING id`,
      [child_id, period, summary, evidence_url || '']
    );

    const reportId = reportResult.rows[0].id;


    const ledgerBlock = await addBlock('REPORT', reportId, {
      report_id: reportId,
      child_id,
      period,
      summary_hash: generatePayloadHash({ summary }),
      evidence_url: evidence_url || '',
    });


    await query(
      'UPDATE progress_reports SET ledger_ref = $1 WHERE id = $2',
      [ledgerBlock.id, reportId]
    );

    return res.status(201).json({
      success: true,
      message: 'Laporan perkembangan berhasil diunggah dan dicatat di ledger.',
      data: {
        report_id: reportId,
        ledger_block: {
          block_index: ledgerBlock.block_index,
          hash: ledgerBlock.hash,
        },
      },
    });
  } catch (err) {
    next(err);
  }
};

module.exports = { getLedger, verifyLedger, getBlockDetail, issueCertificate, verifyCertificate, addReportBlock };
