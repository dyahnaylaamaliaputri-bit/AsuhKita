
const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const { saveGameScore, getLeaderboard, getMyScores, saveStepLog, getStepLogs } = require('../controllers/game.controller');

router.use(verifyToken);


router.post('/scores', saveGameScore);
router.get('/leaderboard', getLeaderboard);
router.get('/my-scores', getMyScores);


router.post('/steps', saveStepLog);
router.get('/steps', getStepLogs);

module.exports = router;
