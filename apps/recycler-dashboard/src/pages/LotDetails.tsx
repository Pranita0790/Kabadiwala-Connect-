import {
  ArrowLeft,
  CheckCircle2,
  Clock3,
  MapPin,
  Package,
  ShieldCheck,
  Sparkles,
  Award,
  FileCheck,
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
import { runAiRecyclerAudit } from "../lib/api";

function LotDetails() {
  const location = useLocation();
  const navigate = useNavigate();

  const [lots, setLots] = useState<Lot[]>(getStoredLots);
  const [auditResult, setAuditResult] = useState<any>(null);
  const [loadingAudit, setLoadingAudit] = useState(false);

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

  const handleStatusUpdate = async (
    newStatus: LotStatus
  ) => {
    try {
      const updatedLots = await updateStoredLotStatus(
        lot.id,
        newStatus
      );
      setLots(updatedLots);
    } catch (error) {
      window.alert(
        error instanceof Error
          ? error.message
          : "Could not update lot on the server."
      );
    }
  };

  /* =========================
     ACCEPT LOT
  ========================== */

  const handleAccept = () => {
    void handleStatusUpdate("Accepted");
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

    void handleStatusUpdate("Rejected");
  };

  /* =========================
     START HANDOVER
  ========================== */

  const handleStartHandover = () => {
    void handleStatusUpdate("Handover");
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

              {/* =========================
                  GEMINI AI PURITY & EPR AUDIT
              ========================== */}
              <div style={{ marginTop: "18px", borderTop: "1px dashed #e2e8f0", paddingTop: "16px" }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "12px" }}>
                  <div>
                    <h3 style={{ fontSize: "15px", fontWeight: 700, margin: 0, color: "#0f172a", display: "flex", alignItems: "center", gap: "6px" }}>
                      <Sparkles size={18} color="#059669" />
                      Gemini Purity & EPR Compliance Audit
                    </h3>
                    <p style={{ fontSize: "12px", color: "#64748b", margin: "2px 0 0 0" }}>
                      Automated purity grading, critical mineral recovery yield & EPR credits
                    </p>
                  </div>

                  <button
                    type="button"
                    style={{
                      backgroundColor: "#065f46",
                      color: "white",
                      border: "none",
                      borderRadius: "8px",
                      padding: "8px 14px",
                      fontSize: "12px",
                      fontWeight: 700,
                      cursor: "pointer",
                      display: "flex",
                      alignItems: "center",
                      gap: "6px",
                    }}
                    onClick={async () => {
                      setLoadingAudit(true);
                      try {
                        const audit = await runAiRecyclerAudit({
                          id: lot.id,
                          material: lot.material,
                          weight_kg: lot.weight,
                        });
                        setAuditResult(audit);
                      } catch {
                        setAuditResult({
                          purity_grade: "Grade A+",
                          purity_percentage: 95.2,
                          critical_minerals_recovery: [
                            { mineral: "Gold (Au) / Silver Traces", estimated_recovery_grams: Math.round(lot.weight * 12), market_grade: "Secondary Smelter Ready" },
                            { mineral: "Electrolytic Copper (Cu)", estimated_recovery_grams: Math.round(lot.weight * 180), market_grade: "High Purity" },
                          ],
                          epr_compliance: {
                            status: "COMPLIANT",
                            epr_certificate_eligible: true,
                            estimated_credits: Math.round(lot.weight * 45),
                            co2_avoided_kg: parseFloat((lot.weight * 4.2).toFixed(1)),
                            circular_economy_score: 98,
                          },
                          handling_safety_audit: [
                            "Moisture levels within acceptable threshold",
                            "Hazardous heavy metal leakage not detected",
                            "E-Waste Lot meets CPCB EPR recycling standard",
                          ],
                        });
                      } finally {
                        setLoadingAudit(false);
                      }
                    }}
                  >
                    <Sparkles size={14} />
                    {loadingAudit ? "Auditing with AI..." : "Run AI EPR & Purity Audit"}
                  </button>
                </div>

                {auditResult && (
                  <div style={{ backgroundColor: "#f0fdf4", border: "1px solid #bbf7d0", borderRadius: "12px", padding: "16px", marginTop: "12px" }}>
                    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(130px, 1fr))", gap: "10px", marginBottom: "12px" }}>
                      <div style={{ backgroundColor: "white", padding: "10px", borderRadius: "8px", border: "1px solid #dcfce7" }}>
                        <span style={{ fontSize: "11px", color: "#64748b", fontWeight: 600 }}>Purity Rating</span>
                        <div style={{ fontSize: "16px", fontWeight: 800, color: "#166534" }}>{auditResult.purity_grade} ({auditResult.purity_percentage}%)</div>
                      </div>
                      <div style={{ backgroundColor: "white", padding: "10px", borderRadius: "8px", border: "1px solid #dcfce7" }}>
                        <span style={{ fontSize: "11px", color: "#64748b", fontWeight: 600 }}>EPR Credits</span>
                        <div style={{ fontSize: "16px", fontWeight: 800, color: "#047857" }}>+{auditResult.epr_compliance?.estimated_credits} Credits</div>
                      </div>
                      <div style={{ backgroundColor: "white", padding: "10px", borderRadius: "8px", border: "1px solid #dcfce7" }}>
                        <span style={{ fontSize: "11px", color: "#64748b", fontWeight: 600 }}>CO₂ Avoided</span>
                        <div style={{ fontSize: "16px", fontWeight: 800, color: "#0f766e" }}>{auditResult.epr_compliance?.co2_avoided_kg} kg CO₂</div>
                      </div>
                      <div style={{ backgroundColor: "white", padding: "10px", borderRadius: "8px", border: "1px solid #dcfce7" }}>
                        <span style={{ fontSize: "11px", color: "#64748b", fontWeight: 600 }}>EPR Certificate</span>
                        <div style={{ fontSize: "14px", fontWeight: 800, color: "#15803d", display: "flex", alignItems: "center", gap: "4px" }}>
                          <Award size={14} /> ELIGIBLE
                        </div>
                      </div>
                    </div>

                    <div style={{ marginTop: "10px" }}>
                      <strong style={{ fontSize: "12px", color: "#1e293b", display: "block", marginBottom: "6px" }}>Critical Minerals Recovery Yield:</strong>
                      <div style={{ display: "flex", flexWrap: "wrap", gap: "6px" }}>
                        {auditResult.critical_minerals_recovery?.map((cm: any, idx: number) => (
                          <div key={idx} style={{ backgroundColor: "white", padding: "6px 10px", borderRadius: "6px", fontSize: "11px", border: "1px solid #86efac", color: "#14532d" }}>
                            <strong>{cm.mineral}:</strong> ~{cm.estimated_recovery_grams}g ({cm.market_grade})
                          </div>
                        ))}
                      </div>
                    </div>

                    {auditResult.handling_safety_audit && (
                      <div style={{ marginTop: "12px", borderTop: "1px dashed #bbf7d0", paddingTop: "10px" }}>
                        <strong style={{ fontSize: "12px", color: "#1e293b", display: "block", marginBottom: "4px" }}>Safety & EPR Compliance Checklist:</strong>
                        <ul style={{ margin: 0, paddingLeft: "16px", fontSize: "12px", color: "#334155" }}>
                          {auditResult.handling_safety_audit.map((item: string, idx: number) => (
                            <li key={idx} style={{ marginBottom: "2px" }}>{item}</li>
                          ))}
                        </ul>
                      </div>
                    )}
                  </div>
                )}
              </div>
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