// File: backend/src/routes/game.routes.js
const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const { saveGameScore, getLeaderboard, getMyScores, saveStepLog, getStepLogs } = require('../controllers/game.controller');

router.use(verifyToken);

// Mini game
router.post('/scores', saveGameScore);         // POST /api/game/scores
router.get('/leaderboard', getLeaderboard);    // GET  /api/game/leaderboard
router.get('/my-scores', getMyScores);         // GET  /api/game/my-scores

// Donasi langkah (accelerometer)
router.post('/steps', saveStepLog);            // POST /api/game/steps
router.get('/steps', getStepLogs);             // GET  /api/game/steps

module.exports = router;
