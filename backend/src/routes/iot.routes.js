
const express = require('express');
const router = express.Router();
const { verifyToken, requireRole } = require('../middlewares/auth.middleware');
const { receiveIotEvent, getIotEvents, registerDevice, generateTestHmac } = require('../controllers/iot.controller');


router.post('/events', receiveIotEvent);
router.get('/events', verifyToken, getIotEvents);


router.post('/devices', verifyToken, requireRole('admin_panti'), registerDevice);


router.get('/test-hmac', generateTestHmac);

module.exports = router;
