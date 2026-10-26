



const { query } = require('../config/database');







const submitFeedback = async (req, res, next) => {
  try {
    const suggestion = typeof req.body?.suggestion === 'string'
      ? req.body.suggestion.trim()
      : '';
    const impression = typeof req.body?.impression === 'string'
      ? req.body.impression.trim()
      : '';
    const rating = Number(req.body?.rating ?? 5);
    const category = typeof req.body?.category === 'string' && req.body.category.trim()
      ? req.body.category.trim()
      : 'Kuliah PAM';

    if (!suggestion && !impression) {
      return res.status(400).json({
        success: false,
        message: 'Minimal satu dari Saran atau Kesan wajib diisi.',
        error: 'MISSING_FEEDBACK',
      });
    }

    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating harus berupa bilangan bulat antara 1 dan 5.',
        error: 'INVALID_RATING',
      });
    }

    const userName = req.user.name || req.user.email || 'Pengguna';
    const userEmail = req.user.email || '';
    const result = await query(
      `INSERT INTO feedback
         (user_id, suggestion, impression, rating, category, user_name, user_email)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, suggestion, impression, rating, category, user_name, user_email, created_at`,
      [req.user.id, suggestion, impression, rating, category, userName, userEmail]
    );

    return res.status(201).json({
      success: true,
      message: 'Saran dan kesan berhasil dikirim. Terima kasih!',
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};






const getMyFeedback = async (req, res, next) => {
  try {
    const isAdmin = req.user.role === 'admin_panti';
    const result = isAdmin
      ? await query(
        `SELECT f.id, f.user_id, f.user_name, f.user_email, f.suggestion,
                f.impression, f.rating, f.category, f.created_at
         FROM feedback f
         ORDER BY f.created_at DESC`
      )
      : await query(
        `SELECT f.id, f.user_name, NULL::text AS user_email, f.suggestion,
                f.impression, f.rating, f.category, f.created_at
         FROM feedback f
         JOIN users u ON u.id = f.user_id
         WHERE u.role = 'donatur'
         ORDER BY f.created_at DESC`
      );

    return res.status(200).json({
      success: true,
      data: result.rows,
    });
  } catch (err) {
    next(err);
  }
};

const updateFeedback = async (req, res, next) => {
  try {
    const suggestion = typeof req.body?.suggestion === 'string'
      ? req.body.suggestion.trim()
      : '';
    const impression = typeof req.body?.impression === 'string'
      ? req.body.impression.trim()
      : '';
    const rating = Number(req.body?.rating);

    if (!suggestion && !impression) {
      return res.status(400).json({
        success: false,
        message: 'Minimal satu dari Saran atau Kesan wajib diisi.',
        error: 'MISSING_FEEDBACK',
      });
    }
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating harus berupa bilangan bulat antara 1 dan 5.',
        error: 'INVALID_RATING',
      });
    }

    const result = await query(
      `UPDATE feedback
       SET suggestion = $1, impression = $2, saran = $1, kesan = $2, rating = $3
       WHERE id = $4
       RETURNING id, user_id, user_name, user_email, suggestion, impression,
                 rating, category, created_at`,
      [suggestion, impression, rating, req.params.id]
    );
    if (!result.rows.length) {
      return res.status(404).json({
        success: false,
        message: 'Feedback tidak ditemukan.',
        error: 'FEEDBACK_NOT_FOUND',
      });
    }
    return res.status(200).json({ success: true, data: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const deleteFeedback = async (req, res, next) => {
  try {
    const result = await query(
      'DELETE FROM feedback WHERE id = $1 RETURNING id',
      [req.params.id]
    );
    if (!result.rows.length) {
      return res.status(404).json({
        success: false,
        message: 'Feedback tidak ditemukan.',
        error: 'FEEDBACK_NOT_FOUND',
      });
    }
    return res.status(200).json({
      success: true,
      message: 'Feedback berhasil dihapus.',
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  submitFeedback,
  getMyFeedback,
  updateFeedback,
  deleteFeedback,
};
