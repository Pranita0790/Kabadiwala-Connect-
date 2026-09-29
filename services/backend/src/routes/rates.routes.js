const express = require("express");
const fs = require("fs");
const path = require("path");

const router = express.Router();

/* =========================================================
   RATE DATA FILE
   ========================================================= */

const dataDirectory = path.join(
  __dirname,
  "../data"
);

const dataFile = path.join(
  dataDirectory,
  "rates.json"
);


/* =========================================================
   DEFAULT RATES
   ========================================================= */

const defaultRates = [
  {
    id: "pcb",
    material: "PCB",
    category: "E-Waste",
    ratePerKg: 448,
    unit: "₹/kg",
    updatedAt: "17 Sep 2026",
  },
  {
    id: "battery",
    material: "Battery",
    category: "Critical Material",
    ratePerKg: 100,
    unit: "₹/kg",
    updatedAt: "17 Sep 2026",
  },
  {
    id: "cable",
    material: "Cable",
    category: "Copper",
    ratePerKg: 396,
    unit: "₹/kg",
    updatedAt: "17 Sep 2026",
  },
  {
    id: "lcd-panel",
    material: "LCD Panel",
    category: "E-Waste",
    ratePerKg: 180,
    unit: "₹/kg",
    updatedAt: "17 Sep 2026",
  },
  {
    id: "crt",
    material: "CRT",
    category: "E-Waste",
    ratePerKg: 85,
    unit: "₹/kg",
    updatedAt: "17 Sep 2026",
  },
  {
    id: "motor",
    material: "Motor",
    category: "Metal",
    ratePerKg: 220,
    unit: "₹/kg",
    updatedAt: "17 Sep 2026",
  },
  {
    id: "magnet-bearing-assembly",
    material: "Magnet/Bearing Assembly",
    category: "Critical Material",
    ratePerKg: 350,
    unit: "₹/kg",
    updatedAt: "17 Sep 2026",
  },
  {
    id: "mixed-plastics",
    material: "Mixed Plastics",
    category: "Plastic",
    ratePerKg: 45,
    unit: "₹/kg",
    updatedAt: "17 Sep 2026",
  },
];


/* =========================================================
   ENSURE DATA FILE EXISTS
   ========================================================= */

function ensureDataFile() {
  if (!fs.existsSync(dataDirectory)) {
    fs.mkdirSync(
      dataDirectory,
      {
        recursive: true,
      }
    );
  }

  if (!fs.existsSync(dataFile)) {
    fs.writeFileSync(
      dataFile,
      JSON.stringify(
        defaultRates,
        null,
        2
      ),
      "utf8"
    );
  }
}


/* =========================================================
   READ RATES
   ========================================================= */

function readRates() {
  try {
    ensureDataFile();

    const raw =
      fs.readFileSync(
        dataFile,
        "utf8"
      );

    const parsed =
      JSON.parse(raw);

    return Array.isArray(parsed)
      ? parsed
      : defaultRates;
  } catch (error) {
    console.error(
      "Failed to read rates:",
      error
    );

    return defaultRates;
  }
}


/* =========================================================
   SAVE RATES
   ========================================================= */

function saveRates(rates) {
  ensureDataFile();

  fs.writeFileSync(
    dataFile,
    JSON.stringify(
      rates,
      null,
      2
    ),
    "utf8"
  );
}


/* =========================================================
   GET ALL RATES
   GET /api/rates
   ========================================================= */

router.get(
  "/",
  (req, res) => {
    const rates = readRates();

    res.json(rates);
  }
);


/* =========================================================
   GET SINGLE RATE
   GET /api/rates/:id
   ========================================================= */

router.get(
  "/:id",
  (req, res) => {
    const rates = readRates();

    const rate =
      rates.find(
        (item) =>
          item.id === req.params.id
      );

    if (!rate) {
      return res
        .status(404)
        .json({
          message:
            "Rate not found",
        });
    }

    res.json(rate);
  }
);


/* =========================================================
   UPDATE RATE
   PUT /api/rates/:id
   ========================================================= */

router.put(
  "/:id",
  (req, res) => {
    const numericRate =
      Number(
        req.body.ratePerKg
      );

    if (
      !Number.isFinite(
        numericRate
      ) ||
      numericRate < 0
    ) {
      return res
        .status(400)
        .json({
          message:
            "ratePerKg must be a valid non-negative number",
        });
    }

    const rates = readRates();

    const index =
      rates.findIndex(
        (item) =>
          item.id ===
          req.params.id
      );

    if (index === -1) {
      return res
        .status(404)
        .json({
          message:
            "Rate not found",
        });
    }

    const updatedRate = {
      ...rates[index],

      ratePerKg:
        numericRate,

      updatedAt:
        new Date().toLocaleDateString(
          "en-IN",
          {
            day: "2-digit",
            month: "short",
            year: "numeric",
          }
        ),
    };

    rates[index] =
      updatedRate;

    saveRates(rates);

    res.json(
      updatedRate
    );
  }
);


module.exports = router;