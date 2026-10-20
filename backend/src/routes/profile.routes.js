// File: backend/src/routes/profile.routes.js
const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const { getProfile, updateProfile, updateBiometric, uploadPhoto, getDonationHistory } = require('../controllers/profile.controller');

// Semua route profil butuh login
router.use(verifyToken);

router.get('/', getProfile);                        // GET  /api/users/profile
router.put('/', updateProfile);                     // PUT  /api/users/profile
router.put('/biometric', updateBiometric);          // PUT  /api/users/profile/biometric
router.post('/photo', uploadPhoto);                 // POST /api/users/profile/photo
router.get('/donations', getDonationHistory);       // GET  /api/users/profile/donations

module.exports = router;
