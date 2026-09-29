const ratesRoutes = require("./routes/rates.routes");const express = require("express");
const cors = require("cors");

const lotsRoutes = require("./routes/lots.routes");
const traceabilityRoutes = require("./routes/traceability.routes");

const app = express();

const PORT = 5000;


/*
|--------------------------------------------------------------------------
| MIDDLEWARE
|--------------------------------------------------------------------------
*/

app.use(
  cors({
    origin: "http://localhost:5174",
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

app.listen(PORT, () => {
  console.log(
    `Kabadiwala backend running on http://localhost:${PORT}`
  );
});