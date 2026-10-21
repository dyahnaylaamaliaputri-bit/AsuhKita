// File: backend/src/routes/ai.routes.js
// Fungsi: Routing untuk fitur AI (Google Gemini 2.0 Flash) dan FAQ Cerdas
// Sesuai PBI-060 (FR-49, FR-50) dan PBI-061 (FR-51) — Sprint 6

const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const { draftLetter, summarizeReport, getFaq } = require('../controllers/ai.controller');

// ============================================================
// DAFTAR ROUTE AI (Sprint 6)
// ============================================================

/**
 * POST /api/ai/letter-draft
 * FR-49: AI membantu donatur menulis surat untuk anak asuh
 * PBI-060: Memerlukan autentikasi (verifyToken)
 */
router.post('/letter-draft', verifyToken, draftLetter);

/**
 * POST /api/ai/report-summary
 * FR-50: AI merangkum laporan perkembangan anak binaan
 * PBI-060: Memerlukan autentikasi (verifyToken)
 */
router.post('/report-summary', verifyToken, summarizeReport);

/**
 * GET /api/ai/faq
 * FR-51: FAQ otomatis platform AsuhKita & Yayasan Peduli Anak
 * PBI-061: Endpoint publik, tidak memerlukan autentikasi
 */
router.get('/faq', getFaq);

module.exports = router;
