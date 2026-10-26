
const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const { getProfile, updateProfile, updateBiometric, uploadPhoto, getDonationHistory } = require('../controllers/profile.controller');


router.use(verifyToken);

router.get('/', getProfile);
router.put('/', updateProfile);
router.put('/biometric', updateBiometric);
router.post('/photo', uploadPhoto);
router.get('/donations', getDonationHistory);

module.exports = router;
