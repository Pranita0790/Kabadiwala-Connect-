const express = require("express");

const router = express.Router();

/*
|--------------------------------------------------------------------------
| MOCK LOT DATA
|--------------------------------------------------------------------------
| This is temporary backend data.
| Later this will come from PostgreSQL.
|--------------------------------------------------------------------------
*/

const lots = [
  {
    id: "KC-2026-0148",
    material: "PCB",
    collector: "Ramesh Kumar",
    location: "Dharavi, Mumbai",
    weight: 12.5,
    aiConfidence: 0.991,
    estimatedValue: 5604,
    status: "Pending",
    criticalMineral: true,
    createdAt: "17 Sep 2026, 09:42 AM",
    condition: "Scrap",
  },

  {
    id: "KC-2026-0147",
    material: "Battery",
    collector: "Suresh Patil",
    location: "Kurla, Mumbai",
    weight: 8.0,
    aiConfidence: 0.998,
    estimatedValue: 800,
    status: "Accepted",
    criticalMineral: true,
    createdAt: "17 Sep 2026, 08:25 AM",
    condition: "Scrap",
  },

  {
    id: "KC-2026-0146",
    material: "Cable",
    collector: "Amit Shah",
    location: "Sion, Mumbai",
    weight: 15.2,
    aiConfidence: 0.642,
    estimatedValue: 6027,
    status: "Handover",
    criticalMineral: false,
    createdAt: "16 Sep 2026, 05:18 PM",
    condition: "Scrap",
  },

  {
    id: "KC-2026-0145",
    material: "LCD Panel",
    collector: "Vijay More",
    location: "Chembur, Mumbai",
    weight: 10.0,
    aiConfidence: 0.829,
    estimatedValue: null,
    status: "Pending",
    criticalMineral: false,
    createdAt: "16 Sep 2026, 03:41 PM",
    condition: "Scrap",
  },

  {
    id: "KC-2026-0144",
    material: "CRT",
    collector: "Mahesh Jadhav",
    location: "Wadala, Mumbai",
    weight: 18.0,
    aiConfidence: 0.905,
    estimatedValue: null,
    status: "Pending",
    criticalMineral: false,
    createdAt: "16 Sep 2026, 01:16 PM",
    condition: "Scrap",
  },

  {
    id: "KC-2026-0143",
    material: "PCB",
    collector: "Ravi Yadav",
    location: "Kurla, Mumbai",
    weight: 6.5,
    aiConfidence: 0.987,
    estimatedValue: 2914,
    status: "Accepted",
    criticalMineral: true,
    createdAt: "16 Sep 2026, 11:08 AM",
    condition: "Scrap",
  },
];


/*
|--------------------------------------------------------------------------
| GET ALL LOTS
|--------------------------------------------------------------------------
*/

router.get("/", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Lots API is working",
    lots,
  });
});


/*
|--------------------------------------------------------------------------
| GET SINGLE LOT
|--------------------------------------------------------------------------
*/

router.get("/:id", (req, res) => {
  const lot = lots.find(
    (item) => item.id === req.params.id
  );

  if (!lot) {
    return res.status(404).json({
      success: false,
      message: "Lot not found",
    });
  }

  res.status(200).json({
    success: true,
    lot,
  });
});


/*
|--------------------------------------------------------------------------
| UPDATE LOT STATUS
|--------------------------------------------------------------------------
*/

router.patch("/:id/status", (req, res) => {
  const { status } = req.body;

  const allowedStatuses = [
    "Pending",
    "Accepted",
    "Rejected",
    "Handover",
    "Completed",
  ];

  if (!allowedStatuses.includes(status)) {
    return res.status(400).json({
      success: false,
      message: "Invalid lot status",
    });
  }

  const lot = lots.find(
    (item) => item.id === req.params.id
  );

  if (!lot) {
    return res.status(404).json({
      success: false,
      message: "Lot not found",
    });
  }

  lot.status = status;

  res.status(200).json({
    success: true,
    message: "Lot status updated",
    lot,
  });
});


module.exports = router;
module.exports.getLots = () => lots;