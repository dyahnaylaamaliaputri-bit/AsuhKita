


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










router.post('/register', register);






router.post('/login', login);






router.post('/refresh', refreshToken);












router.post('/logout', verifyToken, logout);






router.get('/me', verifyToken, getMe);

module.exports = router;
