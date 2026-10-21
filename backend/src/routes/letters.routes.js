// File: backend/src/routes/letters.routes.js
// Fungsi: Routing CRUD surat donatur ke anak asuh (PBI-061)
const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const { createLetter, getMyLetters, getLetterById, deleteLetter } = require('../controllers/letters.controller');

// Semua endpoint butuh autentikasi
router.use(verifyToken);

router.post('/',    createLetter);     // POST   /api/letters
router.get('/',     getMyLetters);     // GET    /api/letters
router.get('/:id',  getLetterById);    // GET    /api/letters/:id
router.delete('/:id', deleteLetter);   // DELETE /api/letters/:id

module.exports = router;
