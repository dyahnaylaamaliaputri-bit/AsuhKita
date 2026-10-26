



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









app.use(helmet());





app.use(cors({
  origin: process.env.NODE_ENV === 'production'
    ? ['https://asuhkita.app']
    : '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));





app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));





app.use(morgan('dev'));







const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
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


const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: {
    success: false,
    message: 'Terlalu banyak percobaan login. Coba lagi dalam 15 menit.',
    error: 'AUTH_RATE_LIMIT_EXCEEDED',
  },
});




app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'AsuhKita Backend berjalan dengan baik! 🎉',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  });
});


const path = require('path');
app.use('/uploads', require('express').static(path.join(__dirname, '../uploads')));




app.use('/api/auth',        authLimiter, authRoutes);
app.use('/api/users/profile', profileRoutes);
app.use('/api/feedback',    feedbackRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/children',    childrenRoutes);
app.use('/api/donations',   donationsRoutes);
app.use('/api/ledger',      ledgerRoutes);
app.use('/api/orphanages',  orphanagesRoutes);
app.use('/api/game',        gameRoutes);
app.use('/api/iot',         iotRoutes);
app.use('/api/letters',     lettersRoutes);
app.use('/api/ai',          aiRoutes);




app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
