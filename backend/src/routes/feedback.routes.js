// File: backend/src/routes/feedback.routes.js
const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const { submitFeedback, getMyFeedback } = require('../controllers/feedback.controller');

router.use(verifyToken);

router.post('/', submitFeedback);     // POST /api/feedback
router.get('/', getMyFeedback);       // GET  /api/feedback

module.exports = router;
