import {
  ArrowLeft,
  CheckCircle2,
  Clock3,
  MapPin,
  Package,
  ShieldCheck,
  User,
  XCircle,
} from "lucide-react";

import { useEffect, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";

import type {
  Lot,
  LotStatus,
} from "../data/mockLots";

import {
  getStoredLots,
  updateLotStatus as updateStoredLotStatus,
} from "../data/lotsStore";

function LotDetails() {
  const location = useLocation();
  const navigate = useNavigate();

  const [lots, setLots] = useState<Lot[]>(
    getStoredLots
  );

  /*
   * Extract lot ID from the current URL.
   *
   * Example:
   * /incoming-lots/KC-2026-0148
   *
   * becomes:
   * KC-2026-0148
   */

  const pathParts = location.pathname
    .split("/")
    .filter(Boolean);

  const lotId = pathParts[pathParts.length - 1];

  const lot = lots.find(
    (item) => item.id === lotId
  );

  /*
   * Keep this page synchronized with the
   * shared lot store.
   */

  useEffect(() => {
    const handleLotsUpdated = () => {
      setLots(getStoredLots());
    };

    window.addEventListener(
      "kabadiwala-lots-updated",
      handleLotsUpdated
    );

    return () => {
      window.removeEventListener(
        "kabadiwala-lots-updated",
        handleLotsUpdated
      );
    };
  }, []);

  /* =========================
     LOT NOT FOUND
  ========================== */

  if (!lot) {
    return (
      <main className="page-content">
        <div className="empty-state">
          <Package size={42} />

          <h2>Lot not found</h2>

          <p>
            The requested lot could not be found.
          </p>

          <button
            type="button"
            className="primary-button"
            onClick={() =>
              navigate("/incoming-lots")
            }
          >
            <ArrowLeft size={18} />
            Back to Incoming Lots
          </button>
        </div>
      </main>
    );
  }

  /* =========================
     UPDATE STATUS
  ========================== */

  const handleStatusUpdate = (
    newStatus: LotStatus
  ) => {
    const updatedLots =
      updateStoredLotStatus(
        lot.id,
        newStatus
      );

    setLots(updatedLots);
  };

  /* =========================
     ACCEPT LOT
  ========================== */

  const handleAccept = () => {
    handleStatusUpdate("Accepted");
  };

  /* =========================
     REJECT LOT
  ========================== */

  const handleReject = () => {
    const confirmed = window.confirm(
      `Are you sure you want to reject lot ${lot.id}?`
    );

    if (!confirmed) {
      return;
    }

    handleStatusUpdate("Rejected");
  };

  /* =========================
     START HANDOVER
  ========================== */

  const handleStartHandover = () => {
    handleStatusUpdate("Handover");
  };

  /* =========================
     AI CONFIDENCE
  ========================== */

  const confidencePercent = Math.round(
    lot.aiConfidence * 100
  );

  /* =========================
     CURRENCY FORMAT
  ========================== */

  const formattedValue =
    lot.estimatedValue !== null
      ? `₹${lot.estimatedValue.toLocaleString(
          "en-IN",
          {
            maximumFractionDigits: 0,
          }
        )}`
      : "Not available";

  /* =========================
     RENDER
  ========================== */

  return (
    <main className="page-content">
      <div className="details-page">

        {/* =========================
            BACK BUTTON
        ========================== */}

        <button
          type="button"
          className="back-button"
          onClick={() =>
            navigate("/incoming-lots")
          }
        >
          <ArrowLeft size={18} />
          Back to Incoming Lots
        </button>

        {/* =========================
            HEADER
        ========================== */}

        <div className="details-header">
          <div>
            <div className="breadcrumb">
              Recycler Portal / Operations / Lot Details
            </div>

            <h1>{lot.id}</h1>

            <p>
              Review collection request and verify
              material details before acceptance.
            </p>
          </div>

          <span
            className={`status-badge status-${lot.status
              .toLowerCase()
              .replace(" ", "-")}`}
          >
            {lot.status}
          </span>
        </div>

        {/* =========================
            MAIN GRID
        ========================== */}

        <div className="details-grid">

          {/* =========================
              LEFT COLUMN
          ========================== */}

          <div className="details-main">

            {/* =========================
                MATERIAL CARD
            ========================== */}

            <section className="details-card">

              <div className="card-title-row">

                <div>
                  <span className="section-label">
                    MATERIAL
                  </span>

                  <h2>
                    {lot.material}
                  </h2>
                </div>

                <div className="material-icon">
                  <Package size={25} />
                </div>

              </div>

              <div className="info-grid">

                {/* CONDITION */}

                <div className="info-item">
                  <span>
                    Condition
                  </span>

                  <strong>
                    {lot.condition}
                  </strong>
                </div>

                {/* WEIGHT */}

                <div className="info-item">
                  <span>
                    Approx. Weight
                  </span>

                  <strong>
                    <Package size={16} />
                    {lot.weight} kg
                  </strong>
                </div>

                {/* ESTIMATED VALUE */}

                <div className="info-item">
                  <span>
                    Estimated Value
                  </span>

                  <strong>
                    {formattedValue}
                  </strong>
                </div>

                {/* COLLECTION TIME */}

                <div className="info-item">
                  <span>
                    Collection Time
                  </span>

                  <strong>
                    <Clock3 size={16} />
                    {lot.createdAt}
                  </strong>
                </div>

              </div>
            </section>

            {/* =========================
                AI MATERIAL INTELLIGENCE
            ========================== */}

            <section className="details-card">

              <div className="section-heading">

                <div className="heading-icon">
                  <ShieldCheck size={20} />
                </div>

                <div>
                  <h2>
                    AI Material Intelligence
                  </h2>

                  <p>
                    Automated screening result from
                    the material analysis service.
                  </p>
                </div>

              </div>

              <div className="ai-result">

                {/* DETECTED MATERIAL */}

                <div className="ai-material">
                  <span>
                    Detected Material
                  </span>

                  <strong>
                    {lot.material}
                  </strong>
                </div>

                {/* AI CONFIDENCE */}

                <div className="confidence-block">

                  <div className="confidence-header">

                    <span>
                      AI Confidence
                    </span>

                    <strong>
                      {confidencePercent}%
                    </strong>

                  </div>

                  <div className="confidence-track">

                    <div
                      className="confidence-fill"
                      style={{
                        width: `${confidencePercent}%`,
                      }}
                    />

                  </div>

                </div>

              </div>

              {/* CRITICAL MINERAL ALERT */}

              {lot.criticalMineral && (
                <div className="critical-alert">

                  <ShieldCheck size={21} />

                  <div>

                    <strong>
                      Potential
                      critical-mineral-associated
                      material
                    </strong>

                    <p>
                      This lot has been flagged for
                      additional verification before
                      processing.
                    </p>

                  </div>

                </div>
              )}

            </section>

            {/* =========================
                COLLECTOR INFORMATION
            ========================== */}

            <section className="details-card">

              <div className="section-heading">

                <div className="heading-icon">
                  <User size={20} />
                </div>

                <div>
                  <h2>
                    Collector Information
                  </h2>

                  <p>
                    Registered collection partner
                  </p>
                </div>

              </div>

              <div className="collector-details">

                <div className="collector-avatar">

                  {lot.collector
                    .split(" ")
                    .map(
                      (name) => name[0]
                    )
                    .join("")
                    .slice(0, 2)
                    .toUpperCase()}

                </div>

                <div>

                  <strong>
                    {lot.collector}
                  </strong>

                  <div className="location-row">

                    <MapPin size={15} />

                    {lot.location}

                  </div>

                </div>

              </div>

            </section>

          </div>

          {/* =========================
              RIGHT SIDEBAR
          ========================== */}

          <aside className="details-sidebar">

            {/* =========================
                LOT SUMMARY
            ========================== */}

            <section className="details-card">

              <span className="section-label">
                LOT SUMMARY
              </span>

              <div className="summary-row">
                <span>
                  Reference ID
                </span>

                <strong>
                  {lot.id}
                </strong>
              </div>

              <div className="summary-row">
                <span>
                  Material
                </span>

                <strong>
                  {lot.material}
                </strong>
              </div>

              <div className="summary-row">
                <span>
                  Weight
                </span>

                <strong>
                  {lot.weight} kg
                </strong>
              </div>

              <div className="summary-row">
                <span>
                  AI Confidence
                </span>

                <strong>
                  {confidencePercent}%
                </strong>
              </div>

              <div className="summary-row">
                <span>
                  Critical Mineral Flag
                </span>

                <strong
                  className={
                    lot.criticalMineral
                      ? "text-warning"
                      : "text-success"
                  }
                >
                  {lot.criticalMineral
                    ? "Flagged"
                    : "Not Flagged"}
                </strong>
              </div>

              <div className="summary-row">
                <span>
                  Status
                </span>

                <strong
                  className={
                    lot.status === "Rejected"
                      ? "text-warning"
                      : lot.status === "Accepted" ||
                        lot.status === "Handover"
                      ? "text-success"
                      : ""
                  }
                >
                  {lot.status}
                </strong>
              </div>

              <div className="summary-row total-row">
                <span>
                  Estimated Value
                </span>

                <strong>
                  {lot.estimatedValue !== null
                    ? formattedValue
                    : "—"}
                </strong>
              </div>

            </section>

            {/* =========================
                REVIEW ACTIONS
            ========================== */}

            <section className="details-card action-card">

              <h3>
                Review this lot
              </h3>

              <p>
                Verify the submitted material and
                collection information before
                proceeding.
              </p>

              {/* =========================
                  PENDING
              ========================== */}

              {lot.status === "Pending" && (
                <>
                  <button
                    type="button"
                    className="accept-button"
                    onClick={handleAccept}
                  >
                    <CheckCircle2 size={18} />
                    Accept Lot
                  </button>

                  <button
                    type="button"
                    className="reject-button"
                    onClick={handleReject}
                  >
                    <XCircle size={18} />
                    Reject Lot
                  </button>
                </>
              )}

              {/* =========================
                  ACCEPTED
              ========================== */}

              {lot.status === "Accepted" && (
                <>
                  <div className="action-status accepted-action">

                    <CheckCircle2 size={20} />

                    <div>

                      <strong>
                        Lot Accepted
                      </strong>

                      <span>
                        The lot has been accepted and
                        is ready for physical handover.
                      </span>

                    </div>

                  </div>

                  <button
                    type="button"
                    className="handover-button"
                    onClick={handleStartHandover}
                  >
                    <Package size={18} />
                    Start Handover
                  </button>
                </>
              )}

              {/* =========================
                  REJECTED
              ========================== */}

              {lot.status === "Rejected" && (
                <div className="action-status rejected-action">

                  <XCircle size={20} />

                  <div>

                    <strong>
                      Lot Rejected
                    </strong>

                    <span>
                      This lot has been marked as
                      rejected and will not proceed
                      to handover.
                    </span>

                  </div>

                </div>
              )}

              {/* =========================
                  HANDOVER
              ========================== */}

              {lot.status === "Handover" && (
                <>
                  <div className="action-status handover-action">

                    <Package size={20} />

                    <div>

                      <strong>
                        Handover in Progress
                      </strong>

                      <span>
                        Complete the physical handover
                        verification.
                      </span>

                    </div>

                  </div>

                  <button
                    type="button"
                    className="handover-button"
                    onClick={() =>
                      navigate(
                        `/verification/${lot.id}`
                      )
                    }
                  >
                    <ShieldCheck size={18} />
                    Verify Handover
                  </button>
                </>
              )}

            </section>

          </aside>

        </div>
      </div>
    </main>
  );
}

export default LotDetails;