
const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const {
  createSponsorship, createDonation,
  verifyDonationCertificate, getDonationHistory, syncOfflineDonations,
  getMySponsorships
} = require('../controllers/donations.controller');

router.get('/certificates/verify/:code', verifyDonationCertificate);
router.use(verifyToken);


router.post('/sponsorships', createSponsorship);
router.get('/sponsorships', getMySponsorships);


router.post('/', createDonation);
router.get('/history', getDonationHistory);
router.post('/sync', syncOfflineDonations);

module.exports = router;
