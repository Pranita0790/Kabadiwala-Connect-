const express = require("express");

const lotsRouter = require("./lots.routes");

const router = express.Router();

function currentStage(status) {
  switch (status) {
    case "Pending":
      return "Verification";
    case "Accepted":
      return "Handover";
    case "Handover":
      return "Processing";
    case "Completed":
      return "Completed";
    case "Rejected":
      return "Verification";
    default:
      return "Collection";
  }
}

function eventsForLot(lot) {
  const stages = [
    {
      id: "collection",
      title: "Collection",
      description:
        "Material was collected and registered by the collector.",
    },
    {
      id: "verification",
      title: "Verification",
      description:
        "Recycler review and AI-assisted material verification.",
    },
    {
      id: "handover",
      title: "Handover",
      description:
        "Physical handover of the lot to the recycling facility.",
    },
    {
      id: "processing",
      title: "Processing",
      description:
        "Lot is being processed at the recycling facility.",
    },
    {
      id: "completed",
      title: "Completed",
      description:
        "Journey closed after processing and settlement.",
    },
  ];

  if (lot.status === "Completed") {
    return stages.map((stage) => ({
      ...stage,
      status: "completed",
    }));
  }

  if (lot.status === "Rejected") {
    return stages.map((stage, index) => {
      if (index === 0) {
        return { ...stage, status: "completed" };
      }

      if (index === 1) {
        return {
          ...stage,
          description:
            "This lot was rejected during recycler verification.",
          status: "current",
        };
      }

      return { ...stage, status: "pending" };
    });
  }

  const currentIndex =
    lot.status === "Pending"
      ? 1
      : lot.status === "Accepted"
        ? 2
        : lot.status === "Handover"
          ? 3
          : 0;

  return stages.map((stage, index) => {
    if (index < currentIndex) {
      return { ...stage, status: "completed" };
    }

    if (index === currentIndex) {
      return { ...stage, status: "current" };
    }

    return { ...stage, status: "pending" };
  });
}

function toRecord(lot) {
  return {
    id: lot.id,
    material: lot.material,
    collector: lot.collector,
    location: lot.location,
    collectorLocation: lot.location,
    weight: lot.weight,
    weightKg: lot.weight,
    aiConfidence: lot.aiConfidence,
    estimatedValue: lot.estimatedValue,
    status: lot.status,
    currentStage: currentStage(lot.status),
    criticalMineral: lot.criticalMineral,
    createdAt: lot.createdAt,
    lastUpdated: lot.createdAt,
    condition: lot.condition,
    events: eventsForLot(lot),
  };
}

router.get("/", (req, res) => {
  const { search = "", status = "All" } = req.query;
  const normalizedSearch = String(search).trim().toLowerCase();
  const lots = lotsRouter.getLots();

  const records = lots
    .map(toRecord)
    .filter((record) => {
      const matchesSearch =
        !normalizedSearch ||
        record.id.toLowerCase().includes(normalizedSearch) ||
        record.material.toLowerCase().includes(normalizedSearch) ||
        record.collector.toLowerCase().includes(normalizedSearch);

      const matchesStatus =
        status === "All" || record.status === status;

      return matchesSearch && matchesStatus;
    });

  res.status(200).json({
    success: true,
    count: records.length,
    records,
  });
});

router.get("/:lotId", (req, res) => {
  const lots = lotsRouter.getLots();
  const lot = lots.find((item) => item.id === req.params.lotId);

  if (!lot) {
    return res.status(404).json({
      success: false,
      message: "Traceability record not found",
    });
  }

  return res.status(200).json({
    success: true,
    record: toRecord(lot),
  });
});

module.exports = router;
