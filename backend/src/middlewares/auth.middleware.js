// File: backend/src/middlewares/auth.middleware.js
// Fungsi: Middleware verifikasi JWT Access Token
// Digunakan di setiap route yang butuh autentikasi

const jwt = require('jsonwebtoken');

/**
 * verifyToken — Middleware wajib untuk endpoint yang butuh login
 *
 * Cara kerja:
 * 1. Ambil token dari header Authorization: Bearer <token>
 * 2. Verifikasi token menggunakan JWT_ACCESS_SECRET
 * 3. Jika valid → simpan payload di req.user lalu lanjutkan
 * 4. Jika tidak valid / kedaluwarsa → kembalikan 401
 */
const verifyToken = (req, res, next) => {
  // Ambil header Authorization
  const authHeader = req.headers['authorization'];

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'Akses ditolak. Token tidak ditemukan.',
      error: 'MISSING_TOKEN',
    });
  }

  // Potong "Bearer " untuk ambil token saja
  const token = authHeader.split(' ')[1];

  try {
    // Verifikasi tanda tangan dan masa berlaku token
    const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET);

    // Simpan payload ke req.user agar bisa dipakai controller
    // Payload berisi: id, email, role
    req.user = decoded;
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'Token kedaluwarsa. Silakan refresh token.',
        error: 'TOKEN_EXPIRED',
      });
    }
    return res.status(401).json({
      success: false,
      message: 'Token tidak valid.',
      error: 'INVALID_TOKEN',
    });
  }
};

/**
 * requireRole — Middleware untuk membatasi akses berdasarkan role
 *
 * Contoh penggunaan:
 *   router.delete('/anak/:id', verifyToken, requireRole('admin_panti'), deleteChild)
 *
 * @param {...string} roles - Role yang diizinkan, misal 'admin_panti' atau 'donatur'
 */
const requireRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: 'Akses ditolak. Anda tidak memiliki izin untuk aksi ini.',
        error: 'FORBIDDEN',
      });
    }
    next();
  };
};

module.exports = { verifyToken, requireRole };
