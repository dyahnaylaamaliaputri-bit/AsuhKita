



const { query } = require('../config/database');









const getChildren = async (req, res, next) => {
  try {
    const {
      search = '',
      category = '',
      min_age,
      max_age,
      orphanage_id = '',
      city = '',
      status = 'Tersedia',
      page = 1,
      limit = 20,
    } = req.query;


    const conditions = [];
    const params = [];
    let paramIndex = 1;


    if (search) {
      conditions.push(`c.alias ILIKE $${paramIndex}`);
      params.push(`%${search}%`);
      paramIndex++;
    }


    if (category && category !== 'Semua') {
      conditions.push(`c.need_category = $${paramIndex}`);
      params.push(category);
      paramIndex++;
    }


    if (min_age) {
      conditions.push(`c.age >= $${paramIndex}`);
      params.push(parseInt(min_age));
      paramIndex++;
    }


    if (max_age) {
      conditions.push(`c.age <= $${paramIndex}`);
      params.push(parseInt(max_age));
      paramIndex++;
    }


    if (orphanage_id) {
      conditions.push(`c.orphanage_id = $${paramIndex}`);
      params.push(orphanage_id);
      paramIndex++;
    }


    if (city) {
      conditions.push(`o.city ILIKE $${paramIndex}`);
      params.push(`%${city}%`);
      paramIndex++;
    }


    conditions.push(`c.status = $${paramIndex}`);
    params.push(status);
    paramIndex++;

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';


    const offset = (parseInt(page) - 1) * parseInt(limit);
    params.push(parseInt(limit));
    params.push(offset);

    const sql = `
      SELECT c.id, c.alias, c.age, c.gender, c.need_category,
             c.story_summary, c.avatar, c.status,
             c.target, c.dream, c.hobby, c.category_budgets,
             COALESCE(c.orphanage_city, o.city, 'Lombok') AS orphanage_city,
             COALESCE(c.orphanage_name, o.name, 'Peduli Anak Foundation') AS orphanage_name,
             o.id AS orphanage_id
      FROM children c
      LEFT JOIN orphanages o ON c.orphanage_id = o.id
      ${whereClause}
      ORDER BY c.created_at DESC, c.alias ASC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;

    const result = await query(sql, params);


    const countParams = params.slice(0, -2);
    const countSql = `
      SELECT COUNT(*) FROM children c
      JOIN orphanages o ON c.orphanage_id = o.id
      ${whereClause}
    `;
    const countResult = await query(countSql, countParams);
    const total = parseInt(countResult.rows[0].count);

    return res.status(200).json({
      success: true,
      data: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        total_pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (err) {
    next(err);
  }
};







const getChildDetail = async (req, res, next) => {
  try {
    const { id } = req.params;


    const childResult = await query(
      `SELECT c.id, c.alias, c.age, c.gender, c.need_category,
              c.story_summary, c.avatar, c.status,
              o.id AS orphanage_id, o.name AS orphanage_name,
              o.city AS orphanage_city, o.address AS orphanage_address,
              o.phone AS orphanage_phone
       FROM children c
       JOIN orphanages o ON c.orphanage_id = o.id
       WHERE c.id = $1`,
      [id]
    );

    if (childResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Data anak tidak ditemukan.',
        error: 'CHILD_NOT_FOUND',
      });
    }

    const child = childResult.rows[0];


    const packagesResult = await query(
      `SELECT id, category, name, amount_idr, description
       FROM sponsorship_packages
       WHERE category = $1 OR category = 'Umum'
       ORDER BY amount_idr ASC`,
      [child.need_category]
    );


    let isAlreadySponsored = false;
    if (req.user) {
      const existingSponsor = await query(
        `SELECT id FROM sponsorships
         WHERE user_id = $1 AND child_id = $2 AND status = 'active'`,
        [req.user.id, id]
      );
      isAlreadySponsored = existingSponsor.rows.length > 0;
    }

    return res.status(200).json({
      success: true,
      data: {
        child,
        sponsorship_packages: packagesResult.rows,
        is_already_sponsored: isAlreadySponsored,
      },
    });
  } catch (err) {
    next(err);
  }
};






const getPackages = async (req, res, next) => {
  try {
    const { category } = req.query;
    let sql = 'SELECT * FROM sponsorship_packages';
    const params = [];

    if (category) {
      sql += ' WHERE category = $1';
      params.push(category);
    }

    sql += ' ORDER BY category, amount_idr ASC';

    const result = await query(sql, params);

    return res.status(200).json({
      success: true,
      data: result.rows,
    });
  } catch (err) {
    next(err);
  }
};






const createChild = async (req, res, next) => {
  try {
    const {
      alias,
      age = 8,
      gender = 'L',
      need_category = 'Pendidikan',
      story_summary = '',
      avatar = '',
      orphanage_id,
      orphanage_city = 'Lombok',
      orphanage_name = 'Peduli Anak Foundation',
      target = 500000,
      dream = '',
      hobby = '',
      category_budgets = '',
    } = req.body;

    if (!alias || alias.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Nama samaran/alias anak wajib diisi.',
        error: 'MISSING_ALIAS',
      });
    }


    let validOrphanageId = orphanage_id;
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!validOrphanageId || !uuidRegex.test(validOrphanageId)) {
      try {
        const firstOrp = await query('SELECT id FROM orphanages LIMIT 1');
        validOrphanageId = firstOrp.rows.length > 0 ? firstOrp.rows[0].id : 'a0000001-0000-0000-0000-000000000001';
      } catch (_) {
        validOrphanageId = 'a0000001-0000-0000-0000-000000000001';
      }
    }


    let normGender = 'L';
    if (gender) {
      const g = gender.toString().toUpperCase();
      if (g.startsWith('P')) normGender = 'P';
      else normGender = 'L';
    }

    const sql = `
      INSERT INTO children (orphanage_id, alias, age, gender, need_category, story_summary, avatar, status, orphanage_name, orphanage_city, target, dream, hobby, category_budgets)
      VALUES ($1, $2, $3, $4, $5, $6, $7, 'Tersedia', $8, $9, $10, $11, $12, $13)
      RETURNING *
    `;

    const result = await query(sql, [
      validOrphanageId,
      alias.trim(),
      parseInt(age) || 8,
      normGender,
      need_category || 'Pendidikan',
      story_summary || '',
      avatar || '',
      orphanage_name || 'Peduli Anak Foundation',
      orphanage_city || 'Lombok',
      parseFloat(target) || 500000,
      dream || '',
      hobby || '',
      typeof category_budgets === 'object' ? JSON.stringify(category_budgets) : (category_budgets || ''),
    ]);

    const created = result.rows[0];

    return res.status(201).json({
      success: true,
      message: `Data anak asuh "${alias.trim()}" berhasil disimpan ke Supabase!`,
      data: created,
    });
  } catch (err) {
    console.error('Error createChild:', err);
    return res.status(500).json({
      success: false,
      message: 'Gagal menyimpan anak ke Supabase: ' + err.message,
      error: err.message,
    });
  }
};





const updateChild = async (req, res, next) => {
  try {
    const { id } = req.params;
    const {
      alias,
      age = 8,
      gender = 'L',
      need_category = 'Pendidikan',
      story_summary = '',
      avatar = '',
      orphanage_city = 'Lombok',
      target = 500000,
      dream = '',
      hobby = '',
      category_budgets = '',
    } = req.body;

    let normGender = 'L';
    if (gender) {
      const g = gender.toString().toUpperCase();
      if (g.startsWith('P')) normGender = 'P';
      else normGender = 'L';
    }

    const sql = `
      UPDATE children
      SET alias = COALESCE($1, alias),
          age = COALESCE($2, age),
          gender = COALESCE($3, gender),
          need_category = COALESCE($4, need_category),
          story_summary = COALESCE($5, story_summary),
          avatar = CASE WHEN $6 <> '' THEN $6 ELSE avatar END,
          orphanage_city = COALESCE($7, orphanage_city),
          target = COALESCE($8, target),
          dream = COALESCE($9, dream),
          hobby = COALESCE($10, hobby),
          category_budgets = COALESCE($11, category_budgets)
      WHERE id::text = $12 OR alias ILIKE $12
      RETURNING *
    `;

    const result = await query(sql, [
      alias ? alias.trim() : null,
      parseInt(age) || 8,
      normGender,
      need_category,
      story_summary,
      avatar || '',
      orphanage_city,
      parseFloat(target) || 500000,
      dream,
      hobby,
      typeof category_budgets === 'object' ? JSON.stringify(category_budgets) : (category_budgets || ''),
      id,
    ]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Data anak tidak ditemukan untuk diperbarui.',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Data anak berhasil diperbarui.',
      data: result.rows[0],
    });
  } catch (err) {
    console.error('Error updateChild:', err);
    return res.status(500).json({
      success: false,
      message: 'Gagal memperbarui anak: ' + err.message,
      error: err.message,
    });
  }
};





const deleteChild = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await query(
      'DELETE FROM children WHERE id::text = $1 OR alias ILIKE $1 RETURNING *',
      [id]
    );

    return res.status(200).json({
      success: true,
      message: 'Data anak berhasil dihapus dari sistem.',
      deleted: result.rows.length,
    });
  } catch (err) {
    console.error('Error deleteChild:', err);
    return res.status(500).json({
      success: false,
      error: err.message,
    });
  }
};

const deleteAllChildren = async (req, res, next) => {
  try {
    await query('DELETE FROM call_schedules WHERE sponsorship_id IN (SELECT id FROM sponsorships)');
    await query('UPDATE donations SET sponsorship_id = NULL');
    await query('DELETE FROM sponsorships');
    const result = await query('DELETE FROM children RETURNING id');

    return res.status(200).json({
      success: true,
      message: 'Semua data anak asuh berhasil dihapus (Mulai dari 0).',
      deletedCount: result.rows.length,
    });
  } catch (err) {
    console.error('Error deleteAllChildren:', err);
    return res.status(500).json({
      success: false,
      message: 'Gagal mengosongkan data anak: ' + err.message,
      error: err.message,
    });
  }
};

module.exports = { getChildren, getChildDetail, getPackages, createChild, updateChild, deleteChild, deleteAllChildren };
