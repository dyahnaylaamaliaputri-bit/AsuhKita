









const { query } = require('../config/database');
const { addBlock } = require('../blockchain/hash_chain');
const crypto = require('crypto');






















const receiveIotEvent = async (req, res, next) => {
  try {
    const { device_id, device_key, amount_sim, timestamp, hmac_signature } = req.body;


    if (!device_id || !device_key || !amount_sim || !timestamp || !hmac_signature) {
      return res.status(400).json({
        success: false,
        message: 'Field wajib: device_id, device_key, amount_sim, timestamp, hmac_signature.',
        error: 'MISSING_FIELDS',
      });
    }

    if (amount_sim <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Nominal donasi harus lebih dari 0.',
        error: 'INVALID_AMOUNT',
      });
    }


    const deviceResult = await query(
      'SELECT id, device_name, orphanage_id, device_key, is_active FROM iot_devices WHERE id = $1',
      [device_id]
    );

    if (deviceResult.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Perangkat tidak terdaftar.',
        error: 'DEVICE_NOT_FOUND',
      });
    }

    const device = deviceResult.rows[0];

    if (!device.is_active) {
      return res.status(403).json({
        success: false,
        message: 'Perangkat tidak aktif.',
        error: 'DEVICE_INACTIVE',
      });
    }


    if (device.device_key !== device_key) {
      return res.status(401).json({
        success: false,
        message: 'Device key tidak valid.',
        error: 'INVALID_DEVICE_KEY',
      });
    }




    const payload = `${device_id}|${amount_sim}|${timestamp}`;
    const expectedHmac = crypto
      .createHmac('sha256', process.env.IOT_DEVICE_SECRET || 'dev_secret')
      .update(payload)
      .digest('hex');

    if (hmac_signature !== expectedHmac) {
      return res.status(401).json({
        success: false,
        message: 'Tanda tangan HMAC tidak valid. Event ditolak.',
        error: 'INVALID_HMAC',
      });
    }


    const duplicateCheck = await query(
      `SELECT id FROM iot_events WHERE device_id = $1
       AND created_at > NOW() - INTERVAL '2 minutes'
       AND amount_sim = $2`,
      [device_id, parseInt(amount_sim)]
    );

    if (duplicateCheck.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'Event duplikat terdeteksi. Event ini sudah diproses.',
        error: 'DUPLICATE_EVENT',
      });
    }


    const eventResult = await query(
      `INSERT INTO iot_events (device_id, amount_sim) VALUES ($1, $2) RETURNING id`,
      [device_id, parseInt(amount_sim)]
    );

    const eventId = eventResult.rows[0].id;


    const ledgerBlock = await addBlock('IOT_EVENT', eventId, {
      event_id: eventId,
      device_id,
      device_name: device.device_name,
      orphanage_id: device.orphanage_id,
      amount_sim: parseInt(amount_sim),
      timestamp,
    });


    await query(
      'UPDATE iot_events SET ledger_ref = $1 WHERE id = $2',
      [ledgerBlock.id, eventId]
    );

    return res.status(201).json({
      success: true,
      message: `Donasi kotak amal Rp ${parseInt(amount_sim).toLocaleString('id-ID')} berhasil dicatat!`,
      data: {
        event_id: eventId,
        device_name: device.device_name,
        amount_sim: parseInt(amount_sim),
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






const getIotEvents = async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const result = await query(
      `SELECT ie.id, ie.amount_sim, ie.created_at,
              d.device_name, d.orphanage_id,
              o.name AS orphanage_name,
              lb.hash AS ledger_hash, lb.block_index AS ledger_block_index
       FROM iot_events ie
       JOIN iot_devices d ON ie.device_id = d.id
       JOIN orphanages o ON d.orphanage_id = o.id
       LEFT JOIN ledger_blocks lb ON ie.ledger_ref = lb.id
       ORDER BY ie.created_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset]
    );

    const countResult = await query('SELECT COUNT(*) FROM iot_events');

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






const registerDevice = async (req, res, next) => {
  try {
    const { orphanage_id, device_name, device_key } = req.body;

    if (!orphanage_id || !device_name || !device_key) {
      return res.status(400).json({
        success: false,
        message: 'orphanage_id, device_name, dan device_key wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }

    const result = await query(
      `INSERT INTO iot_devices (orphanage_id, device_name, device_key)
       VALUES ($1, $2, $3)
       RETURNING id, device_name, orphanage_id, is_active, created_at`,
      [orphanage_id, device_name, device_key]
    );

    return res.status(201).json({
      success: true,
      message: 'Perangkat IoT berhasil didaftarkan.',
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};






const generateTestHmac = async (req, res, next) => {
  try {
    if (process.env.NODE_ENV === 'production') {
      return res.status(403).json({ success: false, message: 'Endpoint ini hanya tersedia di development.' });
    }

    const { device_id, amount, timestamp } = req.query;

    if (!device_id || !amount || !timestamp) {
      return res.status(400).json({
        success: false,
        message: 'Parameter: device_id, amount, timestamp',
        error: 'MISSING_PARAMS',
      });
    }

    const payload = `${device_id}|${amount}|${timestamp}`;
    const hmac = crypto
      .createHmac('sha256', process.env.IOT_DEVICE_SECRET || 'dev_secret')
      .update(payload)
      .digest('hex');

    return res.status(200).json({
      success: true,
      message: 'Gunakan nilai ini untuk simulasi POST /api/iot/events',
      data: {
        payload,
        hmac_signature: hmac,
        example_body: {
          device_id,
          device_key: '(isi device_key dari database)',
          amount_sim: parseInt(amount),
          timestamp,
          hmac_signature: hmac,
        },
      },
    });
  } catch (err) {
    next(err);
  }
};

module.exports = { receiveIotEvent, getIotEvents, registerDevice, generateTestHmac };
