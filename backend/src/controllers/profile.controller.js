



const { query } = require('../config/database');
const path = require('path');
const fs = require('fs');







const getProfile = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT id, name, email, phone, role, avatar_url, biometric_enabled, created_at
       FROM users WHERE id = $1`,
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Profil tidak ditemukan.',
        error: 'USER_NOT_FOUND',
      });
    }

    return res.status(200).json({
      success: true,
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};






const updateProfile = async (req, res, next) => {
  try {
    const { name, phone } = req.body;

    if (!name || name.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Nama tidak boleh kosong.',
        error: 'MISSING_NAME',
      });
    }

    const result = await query(
      `UPDATE users
       SET name = $1, phone = $2, updated_at = NOW()
       WHERE id = $3
       RETURNING id, name, email, phone, role, avatar_url, biometric_enabled`,
      [name.trim(), phone || '', req.user.id]
    );

    return res.status(200).json({
      success: true,
      message: 'Profil berhasil diperbarui.',
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};






const updateBiometric = async (req, res, next) => {
  try {
    const { biometric_enabled } = req.body;

    if (typeof biometric_enabled !== 'boolean') {
      return res.status(400).json({
        success: false,
        message: 'Nilai biometric_enabled harus boolean (true/false).',
        error: 'INVALID_VALUE',
      });
    }

    await query(
      'UPDATE users SET biometric_enabled = $1, updated_at = NOW() WHERE id = $2',
      [biometric_enabled, req.user.id]
    );

    return res.status(200).json({
      success: true,
      message: `Biometrik berhasil ${biometric_enabled ? 'diaktifkan' : 'dinonaktifkan'}.`,
      data: { biometric_enabled },
    });
  } catch (err) {
    next(err);
  }
};











const uploadPhoto = async (req, res, next) => {
  try {
    const { photo_base64, file_extension } = req.body;

    if (!photo_base64) {
      return res.status(400).json({
        success: false,
        message: 'Data foto (photo_base64) wajib disertakan.',
        error: 'MISSING_PHOTO',
      });
    }


    const uploadsDir = path.join(__dirname, '../../uploads/avatars');
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }


    const ext = file_extension || 'jpg';
    const filename = `avatar_${req.user.id}.${ext}`;
    const filepath = path.join(uploadsDir, filename);


    const base64Data = photo_base64.replace(/^data:image\/\w+;base64,/, '');
    const buffer = Buffer.from(base64Data, 'base64');


    if (buffer.length > 5 * 1024 * 1024) {
      return res.status(400).json({
        success: false,
        message: 'Ukuran foto maksimal 5MB.',
        error: 'FILE_TOO_LARGE',
      });
    }


    fs.writeFileSync(filepath, buffer);


    const avatarUrl = `/uploads/avatars/${filename}`;


    await query(
      'UPDATE users SET avatar_url = $1, updated_at = NOW() WHERE id = $2',
      [avatarUrl, req.user.id]
    );

    return res.status(200).json({
      success: true,
      message: 'Foto profil berhasil diperbarui.',
      data: { avatar_url: avatarUrl },
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
              c.alias AS child_alias,
              sp.name AS package_name,
              s.frequency
       FROM donations d
       LEFT JOIN sponsorships s ON d.sponsorship_id = s.id
       LEFT JOIN children c ON s.child_id = c.id
       LEFT JOIN sponsorship_packages sp ON s.package_id = sp.id
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
        page,
        limit,
        total: parseInt(countResult.rows[0].count),
        total_pages: Math.ceil(parseInt(countResult.rows[0].count) / limit),
      },
    });
  } catch (err) {
    next(err);
  }
};

module.exports = { getProfile, updateProfile, updateBiometric, uploadPhoto, getDonationHistory };
