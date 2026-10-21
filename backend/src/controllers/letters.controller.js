// File: backend/src/controllers/letters.controller.js
// Fungsi: CRUD Surat Donatur ke Anak Asuh (PBI-061, FR-49)
// Tabel letters menyimpan surat yang ditulis donatur (manual atau dibantu AI)
// Endpoint: POST /api/letters, GET /api/letters, GET /api/letters/:id, DELETE /api/letters/:id

const { query } = require('../config/database');

// ============================================================
// CREATE LETTER — Donatur mengirim surat ke anak asuh
// POST /api/letters
// Body: { child_id, content, ai_generated (boolean) }
// PBI-061: Menyimpan surat ke tabel letters
// ============================================================
const createLetter = async (req, res, next) => {
  try {
    const { child_id, content, ai_generated } = req.body;

    // Validasi input wajib
    if (!child_id || !content) {
      return res.status(400).json({
        success: false,
        message: 'child_id dan content wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }

    // Validasi isi surat tidak kosong
    if (content.trim().length < 10) {
      return res.status(400).json({
        success: false,
        message: 'Isi surat minimal 10 karakter.',
        error: 'CONTENT_TOO_SHORT',
      });
    }

    // Cek apakah anak asuh ada
    const childCheck = await query(
      `SELECT id, alias FROM children WHERE id = $1`,
      [child_id]
    );

    if (childCheck.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Anak asuh tidak ditemukan.',
        error: 'CHILD_NOT_FOUND',
      });
    }

    // Simpan surat ke tabel letters
    const result = await query(
      `INSERT INTO letters (user_id, child_id, content, ai_generated)
       VALUES ($1, $2, $3, $4)
       RETURNING id, user_id, child_id, content, ai_generated, created_at`,
      [req.user.id, child_id, content.trim(), ai_generated === true]
    );

    return res.status(201).json({
      success: true,
      message: `Surat berhasil dikirim ke ${childCheck.rows[0]?.alias || 'anak asuh'}! 💌`,
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};

// ============================================================
// GET MY LETTERS — Riwayat surat yang dikirim donatur
// GET /api/letters
// Query params: ?child_id=xxx (opsional, filter per anak)
// PBI-061: Menampilkan riwayat surat donatur
// ============================================================
const getMyLetters = async (req, res, next) => {
  try {
    const { child_id } = req.query;
    let sql, params;

    if (child_id) {
      // Filter surat ke anak tertentu
      sql = `SELECT l.id, l.child_id, c.alias AS child_alias, l.content,
                    l.ai_generated, l.created_at
             FROM letters l
             LEFT JOIN children c ON c.id = l.child_id
             WHERE l.user_id = $1 AND l.child_id = $2
             ORDER BY l.created_at DESC`;
      params = [req.user.id, child_id];
    } else {
      // Semua surat dari donatur ini
      sql = `SELECT l.id, l.child_id, c.alias AS child_alias, l.content,
                    l.ai_generated, l.created_at
             FROM letters l
             LEFT JOIN children c ON c.id = l.child_id
             WHERE l.user_id = $1
             ORDER BY l.created_at DESC`;
      params = [req.user.id];
    }

    const result = await query(sql, params);

    return res.status(200).json({
      success: true,
      count: result.rowCount,
      data: result.rows,
    });
  } catch (err) {
    next(err);
  }
};

// ============================================================
// GET LETTER BY ID — Detail satu surat
// GET /api/letters/:id
// PBI-061: Ambil detail surat berdasarkan ID
// ============================================================
const getLetterById = async (req, res, next) => {
  try {
    const { id } = req.params;

    const result = await query(
      `SELECT l.id, l.user_id, l.child_id, c.alias AS child_alias,
              l.content, l.ai_generated, l.created_at
       FROM letters l
       LEFT JOIN children c ON c.id = l.child_id
       WHERE l.id = $1 AND l.user_id = $2`,
      [id, req.user.id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Surat tidak ditemukan.',
        error: 'LETTER_NOT_FOUND',
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

// ============================================================
// DELETE LETTER — Hapus surat milik sendiri
// DELETE /api/letters/:id
// PBI-061: Donatur bisa menghapus surat yang pernah dikirim
// ============================================================
const deleteLetter = async (req, res, next) => {
  try {
    const { id } = req.params;

    const result = await query(
      `DELETE FROM letters WHERE id = $1 AND user_id = $2 RETURNING id`,
      [id, req.user.id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Surat tidak ditemukan atau bukan milik Anda.',
        error: 'LETTER_NOT_FOUND',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Surat berhasil dihapus.',
    });
  } catch (err) {
    next(err);
  }
};

module.exports = { createLetter, getMyLetters, getLetterById, deleteLetter };
