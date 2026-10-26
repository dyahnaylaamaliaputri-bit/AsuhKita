
const express = require('express');
const router = express.Router();
const { verifyToken, requireRole } = require('../middlewares/auth.middleware');
const {
  getLedger, verifyLedger, getBlockDetail,
  issueCertificate, verifyCertificate, addReportBlock
} = require('../controllers/ledger.controller');


router.get('/', verifyToken, getLedger);
router.get('/verify', verifyLedger);
router.get('/block/:index', getBlockDetail);


router.post('/certificates', verifyToken, issueCertificate);
router.get('/certificates/verify/:code', verifyCertificate);


router.post('/report', verifyToken, requireRole('admin_panti'), addReportBlock);

module.exports = router;
