const ratesRoutes = require("./routes/rates.routes");const express = require("express");
const cors = require("cors");

const lotsRoutes = require("./routes/lots.routes");
const traceabilityRoutes = require("./routes/traceability.routes");
const aiRoutes = require("./routes/ai.routes");

const app = express();

const PORT = process.env.PORT || 5000;


/*
|--------------------------------------------------------------------------
| MIDDLEWARE
|--------------------------------------------------------------------------
*/

app.use(
  cors({
    origin: [
      "http://localhost:5174",
      "http://localhost:5173",
      "https://kabadiwala-connect-xi.vercel.app",
    ],
    methods: ["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.use(express.json());


/*
|--------------------------------------------------------------------------
| HEALTH CHECK
|--------------------------------------------------------------------------
*/

app.get("/health", (req, res) => {
  res.status(200).json({
    success: true,
    service: "kabadiwala-backend",
    message: "Backend is running",
  });
});


/*
|--------------------------------------------------------------------------
| API ROUTES
|--------------------------------------------------------------------------
*/

app.use(
  "/api/lots",
  lotsRoutes
);

app.use(
  "/api/traceability",
  traceabilityRoutes
);

app.use(
  "/api/rates",
  ratesRoutes
);

app.use(
  "/api/ai",
  aiRoutes
);


/*
|--------------------------------------------------------------------------
| ROOT
|--------------------------------------------------------------------------
*/

app.get("/", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Kabadiwala Connect Backend API",
    endpoints: {
      health: "/health",
      lots: "/api/lots",
      traceability: "/api/traceability",
      ai: "/api/ai/analyze",
    },
  });
});


/*
|--------------------------------------------------------------------------
| 404 HANDLER
|--------------------------------------------------------------------------
*/

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Route not found",
  });
});


/*
|--------------------------------------------------------------------------
| START SERVER
|--------------------------------------------------------------------------
*/

if (require.main === module) {
  app.listen(PORT, "0.0.0.0", () => {
    console.log(
      `Kabadiwala backend running on port ${PORT}`
    );
  });
}

module.exports = app;