const express = require('express');
const { verifyToken, requireRole } = require('../middlewares/auth.middleware');
const {
  registerDeviceToken,
  unregisterDeviceToken,
  broadcastNotification,
} = require('../controllers/notification.controller');

const router = express.Router();
router.use(verifyToken);

router.post('/devices', registerDeviceToken);
router.delete('/devices', unregisterDeviceToken);
router.post('/broadcast', requireRole('admin_panti'), broadcastNotification);

module.exports = router;
