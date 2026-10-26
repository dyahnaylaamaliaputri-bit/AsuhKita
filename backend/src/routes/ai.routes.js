



const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const { draftLetter, summarizeReport, getFaq } = require('../controllers/ai.controller');










router.post('/letter-draft', verifyToken, draftLetter);






router.post('/report-summary', verifyToken, summarizeReport);






router.get('/faq', getFaq);

module.exports = router;
