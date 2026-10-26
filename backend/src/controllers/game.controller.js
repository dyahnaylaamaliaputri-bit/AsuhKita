



const { query } = require('../config/database');








const saveGameScore = async (req, res, next) => {
  try {
    const { score } = req.body;

    if (score === undefined || score < 0) {
      return res.status(400).json({
        success: false,
        message: 'Skor tidak valid.',
        error: 'INVALID_SCORE',
      });
    }

    const result = await query(
      `INSERT INTO game_scores (user_id, score)
       VALUES ($1, $2)
       RETURNING id, score, created_at`,
      [req.user.id, parseInt(score)]
    );



    const pointsEarned = Math.floor(parseInt(score) / 10);

    return res.status(201).json({
      success: true,
      message: `Skor ${score} berhasil disimpan! Kamu mendapat ${pointsEarned} poin kebaikan.`,
      data: {
        ...result.rows[0],
        points_earned: pointsEarned,
      },
    });
  } catch (err) {
    next(err);
  }
};







const getLeaderboard = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT u.name, u.avatar_url,
              MAX(gs.score) AS best_score,
              SUM(gs.score) AS total_score,
              COUNT(gs.id) AS games_played
       FROM game_scores gs
       JOIN users u ON gs.user_id = u.id
       GROUP BY u.id, u.name, u.avatar_url
       ORDER BY best_score DESC
       LIMIT 10`
    );

    return res.status(200).json({ success: true, data: result.rows });
  } catch (err) {
    next(err);
  }
};





const getMyScores = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT score, created_at,
              FLOOR(score / 10) AS points_earned
       FROM game_scores
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 20`,
      [req.user.id]
    );

    const totalPoints = result.rows.reduce((sum, r) => sum + parseInt(r.points_earned || 0), 0);

    return res.status(200).json({
      success: true,
      data: {
        scores: result.rows,
        total_goodness_points: totalPoints,
      },
    });
  } catch (err) {
    next(err);
  }
};







const saveStepLog = async (req, res, next) => {
  try {
    const { steps, log_date } = req.body;

    if (!steps || steps < 0) {
      return res.status(400).json({
        success: false,
        message: 'Jumlah langkah tidak valid.',
        error: 'INVALID_STEPS',
      });
    }

    const date = log_date || new Date().toISOString().split('T')[0];


    const points = Math.floor(parseInt(steps) / 1000);


    const result = await query(
      `INSERT INTO step_logs (user_id, log_date, steps, points)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (user_id, log_date)
       DO UPDATE SET steps = EXCLUDED.steps, points = EXCLUDED.points
       RETURNING *`,
      [req.user.id, date, parseInt(steps), points]
    );

    return res.status(200).json({
      success: true,
      message: `${steps} langkah tercatat. Kamu mendapat ${points} poin kebaikan hari ini!`,
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};





const getStepLogs = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT log_date, steps, points
       FROM step_logs
       WHERE user_id = $1
       ORDER BY log_date DESC
       LIMIT 30`,
      [req.user.id]
    );


    const stepPoints = result.rows.reduce((sum, r) => sum + parseInt(r.points || 0), 0);

    const gamePointsResult = await query(
      'SELECT COALESCE(SUM(FLOOR(score / 10)), 0) AS total FROM game_scores WHERE user_id = $1',
      [req.user.id]
    );
    const gamePoints = parseInt(gamePointsResult.rows[0].total || 0);

    return res.status(200).json({
      success: true,
      data: {
        logs: result.rows,
        total_step_points: stepPoints,
        total_game_points: gamePoints,
        total_goodness_points: stepPoints + gamePoints,
      },
    });
  } catch (err) {
    next(err);
  }
};

module.exports = { saveGameScore, getLeaderboard, getMyScores, saveStepLog, getStepLogs };
