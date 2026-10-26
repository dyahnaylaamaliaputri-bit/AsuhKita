








const errorHandler = (err, req, res, next) => {

  console.error('🔴 Error:', err.message);
  if (process.env.NODE_ENV === 'development') {
    console.error(err.stack);
  }


  const statusCode = err.statusCode || err.status || 500;

  res.status(statusCode).json({
    success: false,
    message: err.message || 'Terjadi kesalahan pada server.',
    error: err.code || 'INTERNAL_SERVER_ERROR',

    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
};





const notFoundHandler = (req, res) => {
  res.status(404).json({
    success: false,
    message: `Endpoint tidak ditemukan: ${req.method} ${req.originalUrl}`,
    error: 'NOT_FOUND',
  });
};

module.exports = { errorHandler, notFoundHandler };
