




const { query } = require('../config/database');




const createLetter = async (req, res, next) => {
  try {
    const { child_id, content, ai_generated } = req.body;


    if (!child_id || !content) {
      return res.status(400).json({
        success: false,
        message: 'child_id dan content wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }


    if (content.trim().length < 10) {
      return res.status(400).json({
        success: false,
        message: 'Isi surat minimal 10 karakter.',
        error: 'CONTENT_TOO_SHORT',
      });
    }


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







const getMyLetters = async (req, res, next) => {
  try {
    const { child_id } = req.query;
    let sql, params;

    if (child_id) {

      sql = `SELECT l.id, l.child_id, c.alias AS child_alias, l.content,
                    l.ai_generated, l.created_at
             FROM letters l
             LEFT JOIN children c ON c.id = l.child_id
             WHERE l.user_id = $1 AND l.child_id = $2
             ORDER BY l.created_at DESC`;
      params = [req.user.id, child_id];
    } else {

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
