
const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const {
  getNearbyOrphanages, getAllOrphanages, checkIn,
  createSchedule, getSchedules
} = require('../controllers/orphanages.controller');


router.get('/', getAllOrphanages);
router.get('/nearby', getNearbyOrphanages);
router.post('/:id/checkin', verifyToken, checkIn);


router.post('/schedules', verifyToken, createSchedule);
router.get('/schedules', verifyToken, getSchedules);

module.exports = router;
