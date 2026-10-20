// File: backend/src/routes/orphanages.routes.js
const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const {
  getNearbyOrphanages, getAllOrphanages, checkIn,
  createSchedule, getSchedules
} = require('../controllers/orphanages.controller');

// Panti
router.get('/', getAllOrphanages);                          // GET  /api/orphanages (publik untuk peta)
router.get('/nearby', getNearbyOrphanages);                // GET  /api/orphanages/nearby?lat=&lng=
router.post('/:id/checkin', verifyToken, checkIn);         // POST /api/orphanages/:id/checkin

// Jadwal video call
router.post('/schedules', verifyToken, createSchedule);   // POST /api/orphanages/schedules
router.get('/schedules', verifyToken, getSchedules);      // GET  /api/orphanages/schedules

module.exports = router;
