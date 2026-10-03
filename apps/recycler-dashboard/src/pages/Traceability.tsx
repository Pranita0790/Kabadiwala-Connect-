import React, { useEffect, useMemo, useState } from "react";
import {
  ArrowLeft,
  CheckCircle2,
  ChevronRight,
  Clock3,
  FileCheck2,
  Package,
  Search,
  ShieldCheck,
} from "lucide-react";
import { useNavigate, useParams } from "react-router-dom";

import type { Lot } from "../data/mockLots";
import { getStoredLots } from "../data/lotsStore";

import { getApiBase } from "../lib/api";

const API_BASE = getApiBase();

type JourneyStatus = "completed" | "current" | "pending";

type JourneyStep = {
  id: string;
  title: string;
  description: string;
  status: JourneyStatus;
};

function getCurrentStage(status: Lot["status"]): string {
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

function getJourney(status: Lot["status"]): JourneyStep[] {
  const steps: Omit<JourneyStep, "status">[] = [
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

  if (status === "Completed") {
    return steps.map((step) => ({
      ...step,
      status: "completed",
    }));
  }

  if (status === "Rejected") {
    return steps.map((step, index) => {
      if (index === 0) {
        return {
          ...step,
          status: "completed",
        };
      }

      if (index === 1) {
        return {
          ...step,
          status: "current",
          description:
            "This lot was rejected during recycler verification.",
        };
      }

      return {
        ...step,
        status: "pending",
      };
    });
  }

  const currentIndex =
    status === "Pending"
      ? 1
      : status === "Accepted"
      ? 2
      : status === "Handover"
      ? 3
      : 0;

  return steps.map((step, index) => {
    if (index < currentIndex) {
      return {
        ...step,
        status: "completed",
      };
    }

    if (index === currentIndex) {
      return {
        ...step,
        status: "current",
      };
    }

    return {
      ...step,
      status: "pending",
    };
  });
}

function normalizeLot(value: unknown): Lot | null {
  if (!value || typeof value !== "object") {
    return null;
  }

  const item = value as Partial<Lot> & {
    weightKg?: number;
    lastUpdated?: string;
    collectorLocation?: string;
  };

  const weight =
    typeof item.weight === "number"
      ? item.weight
      : item.weightKg;

  const createdAt =
    typeof item.createdAt === "string"
      ? item.createdAt
      : item.lastUpdated;

  if (
    typeof item.id !== "string" ||
    typeof item.material !== "string" ||
    typeof item.collector !== "string" ||
    typeof weight !== "number" ||
    typeof item.status !== "string" ||
    typeof createdAt !== "string"
  ) {
    return null;
  }

  return {
    id: item.id,
    material: item.material,
    collector: item.collector,
    location:
      typeof item.location === "string"
        ? item.location
        : typeof item.collectorLocation === "string"
        ? item.collectorLocation
        : "",
    weight,
    aiConfidence:
      typeof item.aiConfidence === "number"
        ? item.aiConfidence
        : 0,
    estimatedValue:
      typeof item.estimatedValue === "number"
        ? item.estimatedValue
        : null,
    status: item.status as Lot["status"],
    criticalMineral: Boolean(item.criticalMineral),
    createdAt,
    condition:
      typeof item.condition === "string"
        ? item.condition
        : "Scrap",
  };
}

/* ============================================================
   TRACEABILITY DETAIL PAGE
   ============================================================ */

function TraceabilityDetail({
  lot,
}: {
  lot: Lot;
}) {
  const navigate = useNavigate();

  const journey = useMemo(
    () => getJourney(lot.status),
    [lot.status]
  );

  return (
    <section className="page-content traceability-page">
      <div className="page-heading">
        <div>
          <p className="breadcrumb">
            Recycler Portal / Traceability / Lot Journey
          </p>

          <h2>Lot Journey</h2>

          <p>
            Complete traceability record for collected material.
          </p>
        </div>
      </div>

      <button
        type="button"
        className="trace-back-button"
        onClick={() => navigate("/traceability")}
      >
        <ArrowLeft size={17} />
        Back to Traceability
      </button>

      <div className="trace-detail-panel">
        <div className="trace-detail-header">
          <div>
            <p className="breadcrumb">Lot Journey</p>

            <h3>{lot.id}</h3>

            <p>
              Collection → Verification → Handover → Processing
              → Completed
            </p>
          </div>

          <span
            className={`status-pill ${String(lot.status)
              .toLowerCase()
              .replace(/\s+/g, "-")}`}
          >
            {lot.status}
          </span>
        </div>

        <div className="trace-detail-info">
          <div>
            <span>Material</span>
            <strong>{lot.material}</strong>
          </div>

          <div>
            <span>Collector</span>
            <strong>{lot.collector}</strong>
          </div>

          <div>
            <span>Current stage</span>
            <strong>{getCurrentStage(lot.status)}</strong>
          </div>

          <div>
            <span>Weight</span>
            <strong>{Number(lot.weight).toFixed(1)} kg</strong>
          </div>
        </div>

        {lot.criticalMineral && (
          <div className="trace-critical-card">
            <div className="trace-critical-icon">
              <ShieldCheck size={21} />
            </div>

            <div>
              <strong>
                Potential critical mineral detected
              </strong>

              <p>
                This category is flagged for extra traceability
                handling. A photograph does not prove exact
                elemental composition.
              </p>
            </div>
          </div>
        )}

        <div className="trace-timeline-section">
          <div className="trace-section-heading">
            <div>
              <h3>Material Journey</h3>

              <p>Every recorded stage for this lot.</p>
            </div>

            <FileCheck2 size={21} />
          </div>

          <div className="trace-timeline">
            {journey.map(
              (step: JourneyStep, index: number) => (
                <div
                  className={`trace-event ${
                    step.status === "current"
                      ? "trace-event-current"
                      : ""
                  }`}
                  key={step.id}
                >
                  <div className="trace-event-rail">
                    <div
                      className={`trace-event-icon ${
                        step.status === "completed"
                          ? "trace-event-icon-completed"
                          : step.status === "current"
                          ? "trace-event-icon-current"
                          : "trace-event-icon-pending"
                      }`}
                    >
                      {step.status === "pending" ? (
                        <Clock3 size={18} />
                      ) : step.status === "current" &&
                        lot.status === "Rejected" ? (
                        <FileCheck2 size={18} />
                      ) : step.id === "collection" ? (
                        <Package size={18} />
                      ) : (
                        <CheckCircle2 size={18} />
                      )}
                    </div>

                    {index < journey.length - 1 && (
                      <div
                        className={`trace-event-line ${
                          step.status === "completed"
                            ? "trace-event-line-completed"
                            : ""
                        }`}
                      />
                    )}
                  </div>

                  <div className="trace-event-content">
                    <div className="trace-event-title">
                      <strong>{step.title}</strong>

                      {step.status === "completed" && (
                        <CheckCircle2 size={16} />
                      )}

                      {step.status === "current" && (
                        <span>Current</span>
                      )}

                      {step.status === "pending" && (
                        <span>Pending</span>
                      )}
                    </div>

                    <p>{step.description}</p>
                  </div>
                </div>
              )
            )}
          </div>
        </div>
      </div>
    </section>
  );
}

/* ============================================================
   TRACEABILITY LIST PAGE
   ============================================================ */

function TraceabilityList({
  lots,
  search,
  setSearch,
}: {
  lots: Lot[];
  search: string;
  setSearch: React.Dispatch<React.SetStateAction<string>>;
}) {
  const navigate = useNavigate();

  const filteredLots = useMemo(() => {
    const query = search.trim().toLowerCase();

    return lots.filter((lot: Lot) => {
      if (!query) {
        return true;
      }

      return (
        lot.id.toLowerCase().includes(query) ||
        lot.material.toLowerCase().includes(query) ||
        lot.collector.toLowerCase().includes(query)
      );
    });
  }, [lots, search]);

  const totalLots = lots.length;

  const processingLots = lots.filter(
    (lot: Lot) =>
      lot.status === "Pending" ||
      lot.status === "Accepted" ||
      lot.status === "Handover"
  ).length;

  const completedLots = lots.filter(
    (lot: Lot) => lot.status === "Completed"
  ).length;

  const criticalMineralLots = lots.filter(
    (lot: Lot) => lot.criticalMineral
  ).length;

  const openJourney = (lot: Lot) => {
    navigate(`/traceability/${encodeURIComponent(lot.id)}`);
  };

  return (
    <section className="page-content traceability-page">
      <div className="page-heading">
        <div>
          <p className="breadcrumb">
            Recycler Portal / Traceability
          </p>

          <h2>Traceability</h2>

          <p>
            Track the journey of collected material from
            collection through verification, handover,
            processing and completion.
          </p>
        </div>
      </div>

      <div className="lot-summary-grid">
        <div className="lot-summary-card">
          <div className="summary-icon">
            <Package size={20} />
          </div>

          <div>
            <span>Total Lots</span>
            <strong>{totalLots}</strong>
          </div>
        </div>

        <div className="lot-summary-card">
          <div className="summary-icon warning">
            <Clock3 size={20} />
          </div>

          <div>
            <span>In Processing</span>
            <strong>{processingLots}</strong>
          </div>
        </div>

        <div className="lot-summary-card">
          <div className="summary-icon success">
            <CheckCircle2 size={20} />
          </div>

          <div>
            <span>Completed</span>
            <strong>{completedLots}</strong>
          </div>
        </div>

        <div className="lot-summary-card">
          <div className="summary-icon">
            <ShieldCheck size={20} />
          </div>

          <div>
            <span>Critical Mineral Lots</span>
            <strong>{criticalMineralLots}</strong>
          </div>
        </div>
      </div>

      <div className="lot-toolbar">
        <div className="search-box">
          <Search size={17} />

          <input
            type="text"
            placeholder="Search lot ID, collector or material..."
            value={search}
            onChange={(event) =>
              setSearch(event.target.value)
            }
          />
        </div>
      </div>

      <div className="lots-table-card">
        <table>
          <thead>
            <tr>
              <th>LOT ID</th>
              <th>MATERIAL</th>
              <th>COLLECTOR</th>
              <th>CURRENT STAGE</th>
              <th>WEIGHT</th>
              <th>STATUS</th>
              <th>LAST UPDATED</th>
              <th>ACTION</th>
            </tr>
          </thead>

          <tbody>
            {filteredLots.map((lot: Lot) => (
              <tr key={lot.id}>
                <td>
                  <strong>{lot.id}</strong>
                </td>

                <td>
                  <span className="material-pill">
                    {lot.material}
                  </span>
                </td>

                <td>{lot.collector}</td>

                <td>{getCurrentStage(lot.status)}</td>

                <td>
                  {Number(lot.weight).toFixed(1)} kg
                </td>

                <td>
                  <span
                    className={`status-pill ${String(
                      lot.status
                    )
                      .toLowerCase()
                      .replace(/\s+/g, "-")}`}
                  >
                    {lot.status}
                  </span>
                </td>

                <td>{lot.createdAt}</td>

                <td>
                  <button
                    type="button"
                    className="view-lot-button"
                    onClick={() => openJourney(lot)}
                  >
                    <FileCheck2 size={16} />
                    View Journey
                    <ChevronRight size={15} />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {filteredLots.length === 0 && (
          <div className="empty-state">
            <Search size={28} />

            <strong>No lots found</strong>

            <span>
              Try another lot ID, collector or material.
            </span>
          </div>
        )}
      </div>
    </section>
  );
}

/* ============================================================
   MAIN COMPONENT
   ============================================================ */

export default function Traceability() {
  const { lotId } = useParams<{ lotId?: string }>();

  const [lots, setLots] = useState<Lot[]>(() =>
    getStoredLots()
  );

  const [search, setSearch] = useState("");

  useEffect(() => {
    const refreshLots = () => {
      setLots(getStoredLots());
    };

    window.addEventListener(
      "kabadiwala-lots-updated",
      refreshLots
    );

    return () => {
      window.removeEventListener(
        "kabadiwala-lots-updated",
        refreshLots
      );
    };
  }, []);

  useEffect(() => {
    let active = true;

    const syncFromBackend = async () => {
      try {
        const response = await fetch(
          `${API_BASE}/traceability`
        );

        if (!response.ok) {
          return;
        }

        const data = await response.json();

        const records = Array.isArray(data.records)
          ? data.records
          : [];

        const backendLots = records
          .map((item: unknown) => normalizeLot(item))
          .filter((item: Lot | null): item is Lot => item !== null);

        if (active && backendLots.length > 0) {
          // Prefer live backend records over stale localStorage mocks.
          setLots(backendLots);
        }
      } catch {
        // LocalStorage remains the fallback.
      }
    };

    syncFromBackend();

    return () => {
      active = false;
    };
  }, []);

  /*
   * If /traceability/:lotId is opened,
   * show ONLY the detail page.
   */
  if (lotId) {
    const decodedLotId = decodeURIComponent(lotId);

    const selectedLot =
      lots.find((lot: Lot) => lot.id === decodedLotId) ??
      null;

    if (!selectedLot) {
      return (
        <section className="page-content traceability-page">
          <div className="trace-detail-panel">
            <div className="trace-detail-header">
              <div>
                <p className="breadcrumb">
                  Recycler Portal / Traceability
                </p>

                <h3>Lot Not Found</h3>

                <p>
                  The requested lot could not be found in the
                  current traceability records.
                </p>
              </div>
            </div>

            <button
              type="button"
              className="trace-back-button"
              onClick={() =>
                window.history.back()
              }
            >
              <ArrowLeft size={17} />
              Back to Traceability
            </button>
          </div>
        </section>
      );
    }

    return <TraceabilityDetail lot={selectedLot} />;
  }

  return (
    <TraceabilityList
      lots={lots}
      search={search}
      setSearch={setSearch}
    />
  );
}