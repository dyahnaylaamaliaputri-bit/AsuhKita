// File: backend/src/routes/donations.routes.js
const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const {
  createSponsorship, createDonation,
  getDonationHistory, syncOfflineDonations, getMySponsorships
} = require('../controllers/donations.controller');

router.use(verifyToken);

// Sponsorship
router.post('/sponsorships', createSponsorship);      // POST /api/donations/sponsorships
router.get('/sponsorships', getMySponsorships);       // GET  /api/donations/sponsorships

// Donasi
router.post('/', createDonation);                     // POST /api/donations
router.get('/history', getDonationHistory);           // GET  /api/donations/history
router.post('/sync', syncOfflineDonations);           // POST /api/donations/sync (offline sync)

module.exports = router;
