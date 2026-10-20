// File: backend/src/middlewares/error.middleware.js
// Fungsi: Global error handler — menangkap semua error yang tidak tertangani di route

/**
 * errorHandler — Middleware error global
 *
 * Dipasang PALING AKHIR di app.js (setelah semua route)
 * Express mengenali ini sebagai error handler karena memiliki 4 parameter (err, req, res, next)
 */
const errorHandler = (err, req, res, next) => {
  // Cetak error ke console untuk debugging (jangan di production tanpa logging sistem)
  console.error('🔴 Error:', err.message);
  if (process.env.NODE_ENV === 'development') {
    console.error(err.stack);
  }

  // Tentukan status code
  const statusCode = err.statusCode || err.status || 500;

  res.status(statusCode).json({
    success: false,
    message: err.message || 'Terjadi kesalahan pada server.',
    error: err.code || 'INTERNAL_SERVER_ERROR',
    // Hanya tampilkan stack trace saat development
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
};

/**
 * notFoundHandler — Menangkap route yang tidak ada (404)
 * Dipasang setelah semua route, sebelum errorHandler
 */
const notFoundHandler = (req, res) => {
  res.status(404).json({
    success: false,
    message: `Endpoint tidak ditemukan: ${req.method} ${req.originalUrl}`,
    error: 'NOT_FOUND',
  });
};

module.exports = { errorHandler, notFoundHandler };
