// File: backend/src/app.js
// Fungsi: Konfigurasi utama aplikasi Express
// Semua middleware global dan route didaftarkan di sini

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const authRoutes       = require('./routes/auth.routes');
const profileRoutes    = require('./routes/profile.routes');
const feedbackRoutes   = require('./routes/feedback.routes');
const notificationRoutes = require('./routes/notification.routes');
const childrenRoutes   = require('./routes/children.routes');
const donationsRoutes  = require('./routes/donations.routes');
const ledgerRoutes     = require('./routes/ledger.routes');
const orphanagesRoutes = require('./routes/orphanages.routes');
const gameRoutes       = require('./routes/game.routes');
const iotRoutes        = require('./routes/iot.routes');
const lettersRoutes    = require('./routes/letters.routes');
const aiRoutes         = require('./routes/ai.routes');
const { errorHandler, notFoundHandler } = require('./middlewares/error.middleware');

const app = express();

// ============================================================
// MIDDLEWARE GLOBAL
// ============================================================

/**
 * helmet — Mengatur HTTP header keamanan secara otomatis
 * Mencegah serangan: XSS, clickjacking, dll.
 */
app.use(helmet());

/**
 * cors — Mengizinkan request dari Flutter app (semua origin saat dev)
 * Di production, ganti origin dengan domain yang spesifik
 */
app.use(cors({
  origin: process.env.NODE_ENV === 'production'
    ? ['https://asuhkita.app']   // ganti dengan domain production
    : '*',                        // dev: izinkan semua origin
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

/**
 * express.json() — Parse body request JSON dari Flutter
 * Membatasi ukuran body maksimal 5MB untuk mencegah abuse
 */
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

/**
 * morgan — Logging request HTTP di console
 * Format 'dev': METHOD /path STATUS WAKTU
 */
app.use(morgan('dev'));

/**
 * Rate Limiting — Membatasi jumlah request per IP
 * Mencegah brute-force attack pada endpoint login
 *
 * Konfigurasi: max 100 request per 15 menit per IP
 */
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 menit
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Terlalu banyak permintaan. Coba lagi dalam 15 menit.',
    error: 'RATE_LIMIT_EXCEEDED',
  },
});
app.use(limiter);

// Rate limit lebih ketat khusus untuk endpoint login (cegah brute-force)
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20, // hanya 20 percobaan login per 15 menit per IP
  message: {
    success: false,
    message: 'Terlalu banyak percobaan login. Coba lagi dalam 15 menit.',
    error: 'AUTH_RATE_LIMIT_EXCEEDED',
  },
});

// ============================================================
// HEALTH CHECK — Cek apakah server berjalan
// ============================================================
app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'AsuhKita Backend berjalan dengan baik! 🎉',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  });
});

// Serve foto profil yang diupload (FR-12)
const path = require('path');
app.use('/uploads', require('express').static(path.join(__dirname, '../uploads')));

// ============================================================
// DAFTARKAN SEMUA ROUTES (sesuai PBI dokumen)
// ============================================================
app.use('/api/auth',        authLimiter, authRoutes);    // PBI-001..004 (Sprint 1)
app.use('/api/users/profile', profileRoutes);            // PBI-010, PBI-011 (Sprint 1)
app.use('/api/feedback',    feedbackRoutes);             // PBI-012 (Sprint 1)
app.use('/api/notifications', notificationRoutes);
app.use('/api/children',    childrenRoutes);             // PBI-016, PBI-017 (Sprint 2)
app.use('/api/donations',   donationsRoutes);            // PBI-023..026, PBI-029..030 (Sprint 2)
app.use('/api/ledger',      ledgerRoutes);               // PBI-032..037 (Sprint 3)
app.use('/api/orphanages',  orphanagesRoutes);           // PBI-042, PBI-045 (Sprint 4)
app.use('/api/game',        gameRoutes);                 // PBI-054, PBI-055 (Sprint 5)
app.use('/api/iot',         iotRoutes);                  // PBI-066, PBI-067 (Sprint 6)
app.use('/api/letters',     lettersRoutes);              // PBI-061 (Sprint 6 — Surat Donatur)
app.use('/api/ai',          aiRoutes);                   // PBI-060 (Sprint 6 — AI Sahabat Asuh)

// ============================================================
// ERROR HANDLERS (harus di paling bawah)
// ============================================================
app.use(notFoundHandler);  // 404 — route tidak ditemukan
app.use(errorHandler);     // 500 — error tidak tertangani

module.exports = app;
