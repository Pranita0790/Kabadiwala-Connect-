const express = require("express");

const router = express.Router();

const traceabilityRecords = [
  {
    id: "KC-2026-0148",
    material: "PCB",
    collector: "Ramesh Kumar",
    collectorLocation: "Dharavi, Mumbai",
    weightKg: 12.5,
    estimatedValue: 5604,
    status: "Completed",
    aiConfidence: 0.991,
    criticalMineral: true,
    criticalMineralType:
      "Copper / precious-metal-bearing e-waste",
    currentLocation:
      "EcoCycle Recycling Facility, Mumbai",
    recycler: "EcoCycle Recycler",
    createdAt: "17 Sep 2026, 09:42 AM",
    events: [
      {
        id: "1",
        title: "Lot collected",
        description:
          "Material collected from registered collector.",
        timestamp: "17 Sep 2026, 09:42 AM",
        actor: "Ramesh Kumar",
        location: "Dharavi, Mumbai",
        status: "completed",
      },
      {
        id: "2",
        title: "AI material analysis",
        description:
          "AI classified the material as PCB.",
        timestamp: "17 Sep 2026, 09:45 AM",
        actor: "Kabadiwala AI Engine",
        status: "completed",
      },
      {
        id: "3",
        title: "Recycler accepted",
        description:
          "Recycler accepted the incoming lot.",
        timestamp: "17 Sep 2026, 10:15 AM",
        actor: "EcoCycle Recycler",
        location: "Mumbai Facility",
        status: "completed",
      },
      {
        id: "4",
        title: "Handover verified",
        description:
          "Physical handover was verified.",
        timestamp: "17 Sep 2026, 01:20 PM",
        actor: "EcoCycle Recycler",
        location: "Mumbai Facility",
        status: "completed",
      },
      {
        id: "5",
        title: "Payment completed",
        description:
          "Settlement recorded for the lot.",
        timestamp: "17 Sep 2026, 02:05 PM",
        actor: "EcoCycle Recycler",
        status: "completed",
      },
    ],
  },

  {
    id: "KC-2026-0147",
    material: "Battery",
    collector: "Suresh Patil",
    collectorLocation: "Kurla, Mumbai",
    weightKg: 8,
    estimatedValue: 800,
    status: "Accepted",
    aiConfidence: 0.998,
    criticalMineral: true,
    criticalMineralType: "Lithium battery",
    currentLocation:
      "EcoCycle Recycling Facility, Mumbai",
    recycler: "EcoCycle Recycler",
    createdAt: "17 Sep 2026, 08:25 AM",
    events: [
      {
        id: "1",
        title: "Lot collected",
        description:
          "Battery lot submitted by registered collector.",
        timestamp: "17 Sep 2026, 08:25 AM",
        actor: "Suresh Patil",
        location: "Kurla, Mumbai",
        status: "completed",
      },
      {
        id: "2",
        title: "AI material analysis",
        description:
          "AI classified the material as Battery.",
        timestamp: "17 Sep 2026, 08:29 AM",
        actor: "Kabadiwala AI Engine",
        status: "completed",
      },
      {
        id: "3",
        title: "Recycler accepted",
        description:
          "Recycler accepted the lot for processing.",
        timestamp: "17 Sep 2026, 09:10 AM",
        actor: "EcoCycle Recycler",
        location: "Mumbai Facility",
        status: "completed",
      },
      {
        id: "4",
        title: "Handover verification",
        description:
          "Physical handover is awaiting completion.",
        timestamp: "Pending",
        actor: "EcoCycle Recycler",
        status: "current",
      },
      {
        id: "5",
        title: "Payment",
        description:
          "Payment will be recorded after completion.",
        timestamp: "Pending",
        actor: "EcoCycle Recycler",
        status: "pending",
      },
    ],
  },

  {
    id: "KC-2026-0146",
    material: "Cable",
    collector: "Amit Shah",
    collectorLocation: "Sion, Mumbai",
    weightKg: 15.2,
    estimatedValue: 6027,
    status: "Handover",
    aiConfidence: 0.642,
    criticalMineral: false,
    currentLocation:
      "In transit to EcoCycle Facility",
    recycler: "EcoCycle Recycler",
    createdAt: "16 Sep 2026, 05:18 PM",
    events: [
      {
        id: "1",
        title: "Lot collected",
        description:
          "Cable lot submitted by registered collector.",
        timestamp: "16 Sep 2026, 05:18 PM",
        actor: "Amit Shah",
        location: "Sion, Mumbai",
        status: "completed",
      },
      {
        id: "2",
        title: "AI material analysis",
        description:
          "AI classified the material as Cable.",
        timestamp: "16 Sep 2026, 05:24 PM",
        actor: "Kabadiwala AI Engine",
        status: "completed",
      },
      {
        id: "3",
        title: "Recycler accepted",
        description:
          "Recycler accepted the lot.",
        timestamp: "17 Sep 2026, 09:00 AM",
        actor: "EcoCycle Recycler",
        status: "completed",
      },
      {
        id: "4",
        title: "Handover verification",
        description:
          "Handover is currently being processed.",
        timestamp: "17 Sep 2026, 11:30 AM",
        actor: "EcoCycle Recycler",
        status: "current",
      },
      {
        id: "5",
        title: "Payment",
        description:
          "Payment will be recorded after successful handover.",
        timestamp: "Pending",
        actor: "EcoCycle Recycler",
        status: "pending",
      },
    ],
  },

  {
    id: "KC-2026-0145",
    material: "LCD Panel",
    collector: "Vijay More",
    collectorLocation: "Andheri, Mumbai",
    weightKg: 10,
    estimatedValue: null,
    status: "Pending",
    aiConfidence: 0.884,
    criticalMineral: false,
    currentLocation: "Collector location",
    recycler: "EcoCycle Recycler",
    createdAt: "16 Sep 2026, 03:40 PM",
    events: [
      {
        id: "1",
        title: "Lot collected",
        description:
          "LCD panel lot registered.",
        timestamp: "16 Sep 2026, 03:40 PM",
        actor: "Vijay More",
        location: "Andheri, Mumbai",
        status: "completed",
      },
      {
        id: "2",
        title: "AI material analysis",
        description:
          "AI classified the material as LCD Panel.",
        timestamp: "16 Sep 2026, 03:46 PM",
        actor: "Kabadiwala AI Engine",
        status: "completed",
      },
      {
        id: "3",
        title: "Recycler review",
        description:
          "Recycler review is pending.",
        timestamp: "Pending",
        actor: "EcoCycle Recycler",
        status: "current",
      },
      {
        id: "4",
        title: "Handover",
        description:
          "Handover will begin after acceptance.",
        timestamp: "Pending",
        actor: "EcoCycle Recycler",
        status: "pending",
      },
      {
        id: "5",
        title: "Payment",
        description:
          "Payment will follow successful handover.",
        timestamp: "Pending",
        actor: "EcoCycle Recycler",
        status: "pending",
      },
    ],
  },
];

/*
 * GET /api/traceability
 */
router.get("/", (req, res) => {
  const {
    search = "",
    status = "All",
  } = req.query;

  const normalizedSearch =
    String(search).trim().toLowerCase();

  const records = traceabilityRecords.filter(
    (record) => {
      const matchesSearch =
        !normalizedSearch ||
        record.id
          .toLowerCase()
          .includes(normalizedSearch) ||
        record.material
          .toLowerCase()
          .includes(normalizedSearch) ||
        record.collector
          .toLowerCase()
          .includes(normalizedSearch);

      const matchesStatus =
        status === "All" ||
        record.status === status;

      return matchesSearch && matchesStatus;
    }
  );

  res.json({
    success: true,
    count: records.length,
    records,
  });
});

/*
 * GET /api/traceability/:lotId
 */
router.get("/:lotId", (req, res) => {
  const lotId = req.params.lotId;

  const record = traceabilityRecords.find(
    (item) => item.id === lotId
  );

  if (!record) {
    return res.status(404).json({
      success: false,
      message: "Traceability record not found",
    });
  }

  return res.json({
    success: true,
    record,
  });
});

module.exports = router;