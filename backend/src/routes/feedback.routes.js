// File: backend/src/routes/feedback.routes.js
const express = require('express');
const router = express.Router();
const { verifyToken, requireRole } = require('../middlewares/auth.middleware');
const {
  submitFeedback,
  getMyFeedback,
  updateFeedback,
  deleteFeedback,
} = require('../controllers/feedback.controller');

router.use(verifyToken);

router.post('/', submitFeedback);     // POST /api/feedback
router.get('/', getMyFeedback);       // Admin: all; donor: feedback from all donors
router.put('/:id', requireRole('admin_panti'), updateFeedback);
router.delete('/:id', requireRole('admin_panti'), deleteFeedback);

module.exports = router;
