// File: backend/src/routes/children.routes.js
const express = require('express');
const router = express.Router();
const { verifyToken, optionalToken } = require('../middlewares/auth.middleware');
const { getChildren, getChildDetail, getPackages, createChild, updateChild, deleteChild, deleteAllChildren } = require('../controllers/children.controller');

router.get('/packages', optionalToken, getPackages);     // GET /api/children/packages
router.get('/', optionalToken, getChildren);             // GET /api/children?search=&category=...
router.get('/:id', optionalToken, getChildDetail);       // GET /api/children/:id
router.post('/', verifyToken, createChild);            // POST /api/children (admin tambah anak baru)
router.put('/:id', verifyToken, updateChild);          // PUT /api/children/:id (admin edit data anak)
router.delete('/:id', verifyToken, deleteChild);       // DELETE /api/children/:id (admin hapus data anak)
router.delete('/', verifyToken, deleteAllChildren);    // DELETE /api/children (admin bersihkan semua data anak)

module.exports = router;


