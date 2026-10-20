// File: backend/src/routes/ledger.routes.js
const express = require('express');
const router = express.Router();
const { verifyToken, requireRole } = require('../middlewares/auth.middleware');
const {
  getLedger, verifyLedger, getBlockDetail,
  issueCertificate, verifyCertificate, addReportBlock
} = require('../controllers/ledger.controller');

// Ledger — publik boleh verify, tapi daftar butuh login
router.get('/', verifyToken, getLedger);                // GET /api/ledger
router.get('/verify', verifyLedger);                    // GET /api/ledger/verify (publik)
router.get('/block/:index', getBlockDetail);            // GET /api/ledger/block/:index (publik)

// Sertifikat
router.post('/certificates', verifyToken, issueCertificate);          // POST /api/ledger/certificates
router.get('/certificates/verify/:code', verifyCertificate);          // GET  /api/ledger/certificates/verify/:code

// Laporan admin panti
router.post('/report', verifyToken, requireRole('admin_panti'), addReportBlock); // POST /api/ledger/report

module.exports = router;
