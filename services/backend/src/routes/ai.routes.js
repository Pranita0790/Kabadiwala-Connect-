const express = require('express');
const multer = require('multer');
const FormData = require('form-data');
const axios = require('axios');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:8000';

router.post('/analyze', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No image file provided.' });
    }

    const form = new FormData();
    form.append('file', req.file.buffer, {
      filename: req.file.originalname,
      contentType: req.file.mimetype,
    });

    // Forward to FastAPI
    const response = await axios.post(`${AI_SERVICE_URL}/api/v1/analyze`, form, {
      headers: {
        ...form.getHeaders(),
      },
      timeout: 15000,
      validateStatus: () => true, // Don't throw on error status codes
    });

    if (response.status !== 200) {
      return res.status(response.status).json(response.data);
    }

    // Return FastAPI response to Flutter
    return res.status(200).json(response.data);
  } catch (error) {
    console.error('AI Gateway Error:', error.message);
    if (error.code === 'ECONNABORTED') {
      return res.status(504).json({ error: 'AI service timeout' });
    }
    return res.status(500).json({ error: 'Failed to communicate with AI service' });
  }
});

module.exports = router;
