// File: backend/src/controllers/feedback.controller.js
// Fungsi: Logic Saran & Kesan mata kuliah PAM (PBI-012, FR-13)
// Endpoint: POST /api/feedback, GET /api/feedback

const { query } = require('../config/database');

// ============================================================
// SUBMIT FEEDBACK — Kirim saran dan kesan
// POST /api/feedback
// FR-13: Pengguna mengisi saran dan kesan mata kuliah PAM
// PBI-012: tabel feedback, riwayat tampil di halaman yang sama
// ============================================================
const submitFeedback = async (req, res, next) => {
  try {
    const { suggestion, impression } = req.body;

    if (!suggestion && !impression) {
      return res.status(400).json({
        success: false,
        message: 'Minimal satu dari Saran atau Kesan wajib diisi.',
        error: 'MISSING_FEEDBACK',
      });
    }

    const result = await query(
      `INSERT INTO feedback (user_id, suggestion, impression)
       VALUES ($1, $2, $3)
       RETURNING id, suggestion, impression, created_at`,
      [req.user.id, suggestion || '', impression || '']
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

// ============================================================
// GET MY FEEDBACK — Riwayat saran & kesan user yang login
// GET /api/feedback
// FR-13: riwayat tampil di halaman yang sama
// ============================================================
const getMyFeedback = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT id, suggestion, impression, created_at
       FROM feedback
       WHERE user_id = $1
       ORDER BY created_at DESC`,
      [req.user.id]
    );

    return res.status(200).json({
      success: true,
      data: result.rows,
    });
  } catch (err) {
    next(err);
  }
};

module.exports = { submitFeedback, getMyFeedback };
