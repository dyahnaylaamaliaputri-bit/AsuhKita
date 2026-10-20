// File: backend/src/routes/auth.routes.js
// Fungsi: Mendefinisikan semua endpoint autentikasi dan menghubungkannya ke controller

const express = require('express');
const router = express.Router();

const {
  register,
  login,
  refreshToken,
  logout,
  getMe,
} = require('../controllers/auth.controller');

const { verifyToken } = require('../middlewares/auth.middleware');

// ============================================================
// ENDPOINT PUBLIK (tidak butuh token)
// ============================================================

/**
 * POST /api/auth/register
 * Body: { name, email, password, role?, phone? }
 * Response: 201 Created + data user (tanpa password)
 */
router.post('/register', register);

/**
 * POST /api/auth/login
 * Body: { email, password }
 * Response: 200 OK + { access, refresh, user }
 */
router.post('/login', login);

/**
 * POST /api/auth/refresh
 * Body: { refreshToken }
 * Response: 200 OK + { access }
 */
router.post('/refresh', refreshToken);


// ============================================================
// ENDPOINT PRIVAT (butuh token — gunakan verifyToken)
// ============================================================

/**
 * POST /api/auth/logout
 * Header: Authorization: Bearer <access_token>
 * Body: { refreshToken }
 * Response: 200 OK + pesan sukses
 */
router.post('/logout', verifyToken, logout);

/**
 * GET /api/auth/me
 * Header: Authorization: Bearer <access_token>
 * Response: 200 OK + data profil user
 */
router.get('/me', verifyToken, getMe);

module.exports = router;
