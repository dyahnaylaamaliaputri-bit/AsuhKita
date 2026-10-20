// File: backend/src/routes/iot.routes.js
const express = require('express');
const router = express.Router();
const { verifyToken, requireRole } = require('../middlewares/auth.middleware');
const { receiveIotEvent, getIotEvents, registerDevice, generateTestHmac } = require('../controllers/iot.controller');

// Event dari ESP32 (tidak butuh JWT, pakai device_key + HMAC)
router.post('/events', receiveIotEvent);                   // POST /api/iot/events
router.get('/events', verifyToken, getIotEvents);          // GET  /api/iot/events

// Admin panti: daftarkan perangkat baru
router.post('/devices', verifyToken, requireRole('admin_panti'), registerDevice); // POST /api/iot/devices

// Dev only: generate HMAC untuk simulasi Postman (FR-54)
router.get('/test-hmac', generateTestHmac);                // GET  /api/iot/test-hmac

module.exports = router;
