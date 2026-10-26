

const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middlewares/auth.middleware');
const { createLetter, getMyLetters, getLetterById, deleteLetter } = require('../controllers/letters.controller');


router.use(verifyToken);

router.post('/',    createLetter);
router.get('/',     getMyLetters);
router.get('/:id',  getLetterById);
router.delete('/:id', deleteLetter);

module.exports = router;
