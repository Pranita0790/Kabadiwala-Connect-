/*
|--------------------------------------------------------------------------
| AI GATEWAY ROUTE
|--------------------------------------------------------------------------
| POST /api/ai/analyze is the collector's only route to material
| classification. The upstream client is mocked so these tests exercise the
| gateway contract (routing, upload handling, error mapping) without a running
| FastAPI service or a database.
|--------------------------------------------------------------------------
*/

const request = require("supertest");
const express = require("express");

jest.mock("../src/clients/ai-service.client");
const aiClient = require("../src/clients/ai-service.client");

const aiRoutes = require("../src/modules/ai/ai.routes");
const { errorHandler } = require("../src/middleware/error-handler");
const {
  UnprocessableError,
  UpstreamTimeoutError,
  UpstreamUnavailableError,
} = require("../src/lib/errors");

function createTestApp() {
  const app = express();

  app.use("/api/ai", aiRoutes);
  app.use(errorHandler);

  return app;
}

const dummyImageBuffer = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);

const mockResponse = {
  material: "pcb",
  confidence: 0.95,
  critical_mineral: true,
  critical_mineral_reason: null,
  model_version: "sih-5class-v1",
  rule_version: "rules-1",
  supported_materials: ["pcb", "battery", "cable", "crt", "lcd_panel"],
  weight_estimate: { estimated_weight_kg: 1.0, confidence: 0.8, method: "image" },
  value_estimate: { estimated_value_inr: 448, confidence: 0.7, rate_per_kg_inr: 448, method: "rate_card" },
};

describe("POST /api/ai/analyze (backend AI gateway)", () => {
  afterEach(() => {
    jest.resetAllMocks();
  });

  test("returns 400 when no file is uploaded", async () => {
    const res = await request(createTestApp()).post("/api/ai/analyze");

    expect(res.status).toBe(400);
    expect(res.body.error).toBe("No image file provided.");
    expect(aiClient.analyzeMaterialRaw).not.toHaveBeenCalled();
  });

  test("returns the raw FastAPI body on success", async () => {
    aiClient.analyzeMaterialRaw.mockResolvedValueOnce({
      raw: mockResponse,
      latencyMs: 12,
    });

    const res = await request(createTestApp())
      .post("/api/ai/analyze")
      .attach("file", dummyImageBuffer, "test.jpg");

    expect(res.status).toBe(200);
    // Preserved snake_case engine fields the deployed collector may read.
    expect(res.body.material).toBe("pcb");
    expect(res.body.confidence).toBe(0.95);
    expect(res.body.critical_mineral).toBe(true);

    expect(aiClient.analyzeMaterialRaw).toHaveBeenCalledTimes(1);
    const call = aiClient.analyzeMaterialRaw.mock.calls[0][0];
    expect(call.mimetype).toBe("image/jpeg");
  });

  test("maps an upstream validation failure to 422", async () => {
    aiClient.analyzeMaterialRaw.mockRejectedValueOnce(
      new UnprocessableError("Only image files are supported.", "AI_ANALYSIS_FAILED")
    );

    const res = await request(createTestApp())
      .post("/api/ai/analyze")
      .attach("file", dummyImageBuffer, "test.jpg");

    expect(res.status).toBe(422);
    expect(res.body.error).toBe("Only image files are supported.");
  });

  test("maps an upstream timeout to 504", async () => {
    aiClient.analyzeMaterialRaw.mockRejectedValueOnce(
      new UpstreamTimeoutError()
    );

    const res = await request(createTestApp())
      .post("/api/ai/analyze")
      .attach("file", dummyImageBuffer, "test.jpg");

    expect(res.status).toBe(504);
  });

  test("maps an unreachable service to 503", async () => {
    aiClient.analyzeMaterialRaw.mockRejectedValueOnce(
      new UpstreamUnavailableError()
    );

    const res = await request(createTestApp())
      .post("/api/ai/analyze")
      .attach("file", dummyImageBuffer, "test.jpg");

    expect(res.status).toBe(503);
  });

  test("rejects a non-image upload with 422", async () => {
    const res = await request(createTestApp())
      .post("/api/ai/analyze")
      .attach("file", Buffer.from("not an image"), {
        filename: "notes.txt",
        contentType: "text/plain",
      });

    expect(res.status).toBe(422);
    expect(aiClient.analyzeMaterialRaw).not.toHaveBeenCalled();
  });

  test("forwards an optional weight to the client", async () => {
    aiClient.analyzeMaterialRaw.mockResolvedValueOnce({
      raw: { material: "battery", confidence: 0.8 },
      latencyMs: 5,
    });

    const res = await request(createTestApp())
      .post("/api/ai/analyze")
      .field("weight_kg", "2.5")
      .attach("file", dummyImageBuffer, "photo.jpg");

    expect(res.status).toBe(200);

    const call = aiClient.analyzeMaterialRaw.mock.calls[0][0];
    expect(call.weightKg).toBe(2.5);
  });
});
