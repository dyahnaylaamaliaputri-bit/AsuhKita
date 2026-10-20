// File: backend/src/utils/jwt.utils.js
// Fungsi: Helper untuk membuat dan memverifikasi JWT Access Token & Refresh Token

const jwt = require('jsonwebtoken');
const crypto = require('crypto');

/**
 * generateAccessToken — Buat JWT Access Token (umur pendek: 15 menit)
 *
 * Payload yang disimpan di dalam token:
 * - id    : UUID user dari database
 * - email : email user
 * - role  : 'donatur' atau 'admin_panti'
 *
 * Token ini dikirim di setiap request API melalui header Authorization.
 * Karena umurnya pendek, aman jika token bocor (hanya berlaku 15 menit).
 */
const generateAccessToken = (user) => {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role,
    },
    process.env.JWT_ACCESS_SECRET,
    { expiresIn: process.env.JWT_ACCESS_EXPIRES || '15m' }
  );
};

/**
 * generateRefreshToken — Buat JWT Refresh Token (umur panjang: 7 hari)
 *
 * Refresh token hanya dipakai untuk mendapatkan access token baru.
 * Disimpan di tabel sessions dalam bentuk HASH (bukan plain token).
 * Saat logout, hash ini ditandai is_revoked = true.
 */
const generateRefreshToken = (user) => {
  return jwt.sign(
    { id: user.id },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES || '7d' }
  );
};

/**
 * verifyRefreshToken — Verifikasi refresh token saat request /auth/refresh
 *
 * @param {string} token - Refresh token dari client
 * @returns {object}     - Payload decoded jika valid
 * @throws               - Error jika token tidak valid atau kedaluwarsa
 */
const verifyRefreshToken = (token) => {
  return jwt.verify(token, process.env.JWT_REFRESH_SECRET);
};

/**
 * hashToken — Hash token menggunakan SHA-256
 *
 * Kita tidak menyimpan refresh token dalam bentuk plain di database.
 * Kita menyimpan hasil hashnya. Saat verifikasi, kita hash token yang
 * diterima lalu bandingkan dengan yang ada di database.
 *
 * Ini seperti bcrypt untuk password, tapi untuk token (SHA-256 cukup
 * karena token sudah memiliki entropy yang tinggi).
 */
const hashToken = (token) => {
  return crypto.createHash('sha256').update(token).digest('hex');
};

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
  hashToken,
};
