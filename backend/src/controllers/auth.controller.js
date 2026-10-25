// File: backend/src/controllers/auth.controller.js
// Fungsi: Logic bisnis untuk Registrasi, Login, Refresh Token, dan Logout
// Digunakan oleh: src/routes/auth.routes.js

const bcrypt = require('bcrypt');
const { query } = require('../config/database');
const {
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
  hashToken,
} = require('../utils/jwt.utils');

// ============================================================
// REGISTER — Buat akun baru
// POST /api/auth/register
// ============================================================
const register = async (req, res, next) => {
  try {
    const { name, email, password, role = 'donatur', phone = '' } = req.body;

    // --- 1. Validasi input sederhana ---
    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Nama, email, dan password wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }

    if (password.length < 8) {
      return res.status(400).json({
        success: false,
        message: 'Password minimal 8 karakter.',
        error: 'WEAK_PASSWORD',
      });
    }

    // Validasi format email sederhana
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Format email tidak valid.',
        error: 'INVALID_EMAIL',
      });
    }

    // --- 2. Cek apakah email sudah terdaftar ---
    const existingUser = await query(
      'SELECT id FROM users WHERE email = $1',
      [email.toLowerCase()]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'Email sudah terdaftar. Gunakan email lain.',
        error: 'EMAIL_ALREADY_EXISTS',
      });
    }

    // --- 3. Hash password menggunakan bcrypt ---
    // PENTING: Kita HASH password, bukan "enkripsi".
    // Hash bersifat satu arah — tidak bisa dikembalikan ke password asli.
    // bcrypt secara otomatis menambahkan 'salt' untuk mencegah serangan rainbow table.
    const saltRounds = parseInt(process.env.BCRYPT_SALT_ROUNDS) || 12;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // --- 4. Simpan user baru ke database ---
    const result = await query(
      `INSERT INTO users (name, email, password_hash, role, phone)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, name, email, role, created_at`,
      [name.trim(), email.toLowerCase(), passwordHash, role, phone]
    );

    const newUser = result.rows[0];

    // --- 5. Kembalikan respons sukses ---
    return res.status(201).json({
      success: true,
      message: 'Registrasi berhasil! Silakan login.',
      data: {
        id: newUser.id,
        name: newUser.name,
        email: newUser.email,
        role: newUser.role,
      },
    });
  } catch (err) {
    next(err); // Teruskan ke error handler global
  }
};


// ============================================================
// LOGIN — Verifikasi email & password, buat token JWT
// POST /api/auth/login
// ============================================================
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    // --- 1. Validasi input ---
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email dan password wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }

    // --- 2. Cari user berdasarkan email ---
    const result = await query(
      'SELECT id, name, email, password_hash, role, avatar_url FROM users WHERE email = $1',
      [email.toLowerCase()]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Akun belum terdaftar di AsuhKita. Silakan daftar terlebih dahulu.',
        error: 'USER_NOT_FOUND',
      });
    }

    const user = result.rows[0];

    // --- 3. Verifikasi password dengan bcrypt ---
    // bcrypt.compare() membandingkan password plain dengan hash yang tersimpan
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);

    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Email atau password salah.',
        error: 'INVALID_CREDENTIALS',
      });
    }

    // --- 4. Generate token ---
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    // --- 5. Simpan hash refresh token di tabel sessions ---
    // Kita simpan HASH-nya bukan plain token untuk keamanan
    const refreshHash = hashToken(refreshToken);

    // Hitung waktu kedaluwarsa (7 hari dari sekarang)
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    // Informasi perangkat dari request (opsional untuk audit)
    const deviceInfo = req.headers['user-agent'] || 'Unknown Device';
    const ipAddress = req.ip || req.connection.remoteAddress;

    await query(
      `INSERT INTO sessions (user_id, refresh_hash, device_info, ip_address, expires_at)
       VALUES ($1, $2, $3, $4, $5)`,
      [user.id, refreshHash, deviceInfo, ipAddress, expiresAt]
    );

    // --- 6. Kembalikan token ke Flutter ---
    return res.status(200).json({
      success: true,
      message: 'Login berhasil.',
      data: {
        access: accessToken,      // Flutter simpan di secure_storage
        refresh: refreshToken,    // Flutter simpan di secure_storage
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role,
          avatar_url: user.avatar_url,
        },
      },
    });
  } catch (err) {
    next(err);
  }
};


// ============================================================
// REFRESH — Minta access token baru menggunakan refresh token
// POST /api/auth/refresh
// ============================================================
const refreshToken = async (req, res, next) => {
  try {
    const { refreshToken: token } = req.body;

    if (!token) {
      return res.status(400).json({
        success: false,
        message: 'Refresh token wajib disertakan.',
        error: 'MISSING_REFRESH_TOKEN',
      });
    }

    // --- 1. Verifikasi tanda tangan JWT refresh token ---
    let decoded;
    try {
      decoded = verifyRefreshToken(token);
    } catch (jwtErr) {
      return res.status(401).json({
        success: false,
        message: 'Refresh token tidak valid atau kedaluwarsa. Silakan login ulang.',
        error: 'INVALID_REFRESH_TOKEN',
      });
    }

    // --- 2. Cek apakah token ada di database dan belum dicabut ---
    const tokenHash = hashToken(token);
    const sessionResult = await query(
      `SELECT id, is_revoked, expires_at FROM sessions
       WHERE refresh_hash = $1 AND user_id = $2`,
      [tokenHash, decoded.id]
    );

    if (sessionResult.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Sesi tidak ditemukan. Silakan login ulang.',
        error: 'SESSION_NOT_FOUND',
      });
    }

    const session = sessionResult.rows[0];

    // Cek apakah token sudah dicabut (logout sebelumnya)
    if (session.is_revoked) {
      return res.status(401).json({
        success: false,
        message: 'Sesi sudah berakhir. Silakan login ulang.',
        error: 'SESSION_REVOKED',
      });
    }

    // Cek apakah token sudah kedaluwarsa di database
    if (new Date() > new Date(session.expires_at)) {
      return res.status(401).json({
        success: false,
        message: 'Sesi kedaluwarsa. Silakan login ulang.',
        error: 'SESSION_EXPIRED',
      });
    }

    // --- 3. Ambil data user terbaru dari database ---
    const userResult = await query(
      'SELECT id, name, email, role FROM users WHERE id = $1',
      [decoded.id]
    );

    if (userResult.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Akun tidak ditemukan.',
        error: 'USER_NOT_FOUND',
      });
    }

    const user = userResult.rows[0];

    // --- 4. Generate access token baru ---
    const newAccessToken = generateAccessToken(user);

    return res.status(200).json({
      success: true,
      message: 'Token berhasil diperbarui.',
      data: {
        access: newAccessToken,
        // Refresh token TIDAK diganti (kecuali implementasi "rotation")
        userId: user.id,
      },
    });
  } catch (err) {
    next(err);
  }
};


// ============================================================
// LOGOUT — Cabut refresh token (invalidate sesi)
// POST /api/auth/logout
// Memerlukan: verifyToken middleware
// ============================================================
const logout = async (req, res, next) => {
  try {
    const { refreshToken: token } = req.body;

    if (token) {
      // Tandai sesi sebagai dicabut (revoked) di database
      // Flutter juga harus menghapus token dari secure_storage
      const tokenHash = hashToken(token);
      await query(
        'UPDATE sessions SET is_revoked = TRUE WHERE refresh_hash = $1',
        [tokenHash]
      );
    }

    return res.status(200).json({
      success: true,
      message: 'Logout berhasil. Sesi telah dicabut.',
    });
  } catch (err) {
    next(err);
  }
};


// ============================================================
// GET PROFILE — Ambil data profil user yang sedang login
// GET /api/auth/me
// Memerlukan: verifyToken middleware
// ============================================================
const getMe = async (req, res, next) => {
  try {
    // req.user diisi oleh verifyToken middleware
    const result = await query(
      'SELECT id, name, email, role, phone, avatar_url, biometric_enabled, created_at FROM users WHERE id = $1',
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Pengguna tidak ditemukan.',
        error: 'USER_NOT_FOUND',
      });
    }

    return res.status(200).json({
      success: true,
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};

module.exports = { register, login, refreshToken, logout, getMe };
