/*
|--------------------------------------------------------------------------
| APP WIRING
|--------------------------------------------------------------------------
| Smoke tests for the assembled Express app: the routes exist, the index and
| liveness respond, the AI gateway is mounted, and an unknown path gets the
| standard 404 envelope.
|
| Nothing here touches PostgreSQL, so the suite runs with or without a
| database. DB-backed behaviour is covered by the integration suites.
|--------------------------------------------------------------------------
*/

const request = require("supertest");

const app = require("../src/app");

describe("app wiring", () => {
  test("GET / describes the service", async () => {
    const res = await request(app).get("/");

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.service).toBe("kabadiwala-backend");
    expect(res.body.data.endpoints.lots).toBe("/api/lots");
  });

  test("GET /health reports liveness without a database", async () => {
    const res = await request(app).get("/health");

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe("ok");
  });

  test("GET /health/live is an alias of liveness", async () => {
    const res = await request(app).get("/health/live");

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("ok");
  });

  test("POST /api/ai/analyze is mounted and rejects a missing image", async () => {
    const res = await request(app).post("/api/ai/analyze");

    expect(res.status).toBe(400);
    expect(res.body.error).toBe("No image file provided.");
  });

  test("an unknown path returns the standard 404 envelope", async () => {
    const res = await request(app).get("/api/does-not-exist");

    expect(res.status).toBe(404);
    expect(res.body.success).toBe(false);
    expect(res.body.code).toBe("NOT_FOUND");
  });
});
