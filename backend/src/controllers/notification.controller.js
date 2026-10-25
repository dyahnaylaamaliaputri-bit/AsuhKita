const { query } = require('../config/database');
const { sendBroadcast } = require('../services/push_notification.service');

const registerDeviceToken = async (req, res, next) => {
  try {
    const token = typeof req.body?.token === 'string' ? req.body.token.trim() : '';
    if (token.length < 20 || token.length > 4096) {
      return res.status(400).json({
        success: false,
        message: 'Token perangkat tidak valid.',
        error: 'INVALID_DEVICE_TOKEN',
      });
    }

    await query(
      `INSERT INTO push_tokens (user_id, token, updated_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (token)
       DO UPDATE SET user_id = EXCLUDED.user_id, updated_at = NOW()`,
      [req.user.id, token]
    );
    return res.status(200).json({
      success: true,
      message: 'Perangkat berhasil didaftarkan untuk notifikasi.',
    });
  } catch (error) {
    next(error);
  }
};

const unregisterDeviceToken = async (req, res, next) => {
  try {
    const token = typeof req.body?.token === 'string' ? req.body.token.trim() : '';
    if (!token) {
      return res.status(400).json({
        success: false,
        message: 'Token perangkat wajib diisi.',
        error: 'MISSING_DEVICE_TOKEN',
      });
    }
    await query(
      'DELETE FROM push_tokens WHERE user_id = $1 AND token = $2',
      [req.user.id, token]
    );
    return res.status(200).json({ success: true });
  } catch (error) {
    next(error);
  }
};

const broadcastNotification = async (req, res, next) => {
  try {
    const title = typeof req.body?.title === 'string' ? req.body.title.trim() : '';
    const body = typeof req.body?.body === 'string' ? req.body.body.trim() : '';
    if (!title || !body || title.length > 120 || body.length > 1000) {
      return res.status(400).json({
        success: false,
        message: 'Judul (maksimal 120 karakter) dan isi (maksimal 1000 karakter) wajib diisi.',
        error: 'INVALID_NOTIFICATION',
      });
    }

    const result = await sendBroadcast({ title, body });
    return res.status(200).json({
      success: true,
      message: 'Pengiriman notifikasi selesai.',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  registerDeviceToken,
  unregisterDeviceToken,
  broadcastNotification,
};
