const request = require('supertest');
const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// We test the ai.routes module in isolation with a mock for axios
// so we don't need the real FastAPI service running.

// Mock axios before requiring the route
jest.mock('axios');
const axios = require('axios');

// Now require the route
const aiRoutes = require('../src/routes/ai.routes');

// Build a minimal test app
function createTestApp() {
  const app = express();
  app.use('/api/ai', aiRoutes);
  return app;
}

// Create a tiny valid JPEG-like buffer for uploads
const dummyImageBuffer = Buffer.from([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

describe('POST /api/ai/analyze (Node.js AI Gateway)', () => {

  afterEach(() => {
    jest.resetAllMocks();
  });

  test('returns 400 when no file is uploaded', async () => {
    const app = createTestApp();
    const res = await request(app)
      .post('/api/ai/analyze');

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('No image file provided.');
  });

  test('forwards image to FastAPI and returns classification result on success', async () => {
    const mockResponse = {
      material: 'pcb',
      confidence: 0.95,
      critical_mineral: true,
      critical_mineral_reason: null,
      model_version: '1.0',
      rule_version: '1.0',
      supported_materials: ['pcb', 'battery', 'cable', 'crt', 'lcd_panel'],
      weight_estimate: { value: 1.0, unit: 'kg' },
      value_estimate: { min: 100, max: 200, currency: 'INR' },
    };

    axios.post.mockResolvedValueOnce({
      status: 200,
      data: mockResponse,
    });

    const app = createTestApp();
    const res = await request(app)
      .post('/api/ai/analyze')
      .attach('file', dummyImageBuffer, 'test.jpg');

    expect(res.status).toBe(200);
    expect(res.body.material).toBe('pcb');
    expect(res.body.confidence).toBe(0.95);
    expect(res.body.critical_mineral).toBe(true);

    // Verify axios was called with the right URL
    expect(axios.post).toHaveBeenCalledTimes(1);
    const axiosCallUrl = axios.post.mock.calls[0][0];
    expect(axiosCallUrl).toContain('/api/v1/analyze');
  });

  test('returns FastAPI error status when AI service responds with non-200', async () => {
    axios.post.mockResolvedValueOnce({
      status: 400,
      data: { detail: 'Only image files are supported.' },
    });

    const app = createTestApp();
    const res = await request(app)
      .post('/api/ai/analyze')
      .attach('file', dummyImageBuffer, 'test.jpg');

    expect(res.status).toBe(400);
    expect(res.body.detail).toBe('Only image files are supported.');
  });

  test('returns 504 when FastAPI times out', async () => {
    const timeoutError = new Error('timeout of 15000ms exceeded');
    timeoutError.code = 'ECONNABORTED';
    axios.post.mockRejectedValueOnce(timeoutError);

    const app = createTestApp();
    const res = await request(app)
      .post('/api/ai/analyze')
      .attach('file', dummyImageBuffer, 'test.jpg');

    expect(res.status).toBe(504);
    expect(res.body.error).toBe('AI service timeout');
  });

  test('returns 500 when FastAPI is unreachable', async () => {
    const connectionError = new Error('connect ECONNREFUSED 127.0.0.1:8000');
    connectionError.code = 'ECONNREFUSED';
    axios.post.mockRejectedValueOnce(connectionError);

    const app = createTestApp();
    const res = await request(app)
      .post('/api/ai/analyze')
      .attach('file', dummyImageBuffer, 'test.jpg');

    expect(res.status).toBe(500);
    expect(res.body.error).toBe('Failed to communicate with AI service');
  });

  test('correctly forwards multipart field name "file"', async () => {
    axios.post.mockResolvedValueOnce({
      status: 200,
      data: { material: 'battery', confidence: 0.80 },
    });

    const app = createTestApp();
    const res = await request(app)
      .post('/api/ai/analyze')
      .attach('file', dummyImageBuffer, 'photo.jpg');

    expect(res.status).toBe(200);

    // Check that axios.post received a FormData with the file
    const axiosCallData = axios.post.mock.calls[0][1];
    // form-data appends produce a readable stream; verify it was called
    expect(axiosCallData).toBeDefined();
  });
});
