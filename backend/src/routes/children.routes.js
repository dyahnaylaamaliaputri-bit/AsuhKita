// File: backend/src/routes/children.routes.js
const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const { getChildren, getChildDetail, getPackages, createChild } = require('../controllers/children.controller');

router.get('/packages', verifyToken, getPackages);     // GET /api/children/packages
router.get('/', verifyToken, getChildren);             // GET /api/children?search=&category=...
router.get('/:id', verifyToken, getChildDetail);       // GET /api/children/:id
router.post('/', verifyToken, createChild);            // POST /api/children (admin tambah anak baru)

module.exports = router;

