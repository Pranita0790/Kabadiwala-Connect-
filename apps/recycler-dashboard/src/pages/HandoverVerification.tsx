import {
    ArrowLeft,
    CheckCircle2,
    ClipboardCheck,
    MapPin,
    Package,
    ShieldCheck,
    User,
    Weight,
    XCircle,
  } from "lucide-react";
  
  import {
    useEffect,
    useState,
  } from "react";
  
  import {
    useLocation,
    useNavigate,
  } from "react-router-dom";
  
  import type { Lot } from "../data/mockLots";
  
  import {
    getStoredLots,
    refreshLotsFromBackend,
    updateLotStatus,
  } from "../data/lotsStore";
  import { confirmHandover } from "../lib/api";
  import { matchesHandoverPin } from "../lib/handoverPin";
  
  function HandoverVerification() {
    const location = useLocation();
    const navigate = useNavigate();
  
    const [lots, setLots] = useState<Lot[]>(
      getStoredLots
    );
  
    const [physicalWeight, setPhysicalWeight] =
      useState("");

    const [collectorPin, setCollectorPin] =
      useState("");

    const [paymentMethod, setPaymentMethod] =
      useState("");
  
    const [collectorVerified, setCollectorVerified] =
      useState(false);
  
    const [materialVerified, setMaterialVerified] =
      useState(false);
  
    const [weightVerified, setWeightVerified] =
      useState(false);
  
    const [error, setError] = useState("");
  
    const [completed, setCompleted] =
      useState(false);
  
    /* =========================
       LOT ID
    ========================== */
  
    const pathParts = location.pathname
      .split("/")
      .filter(Boolean);
  
    const lotId =
      pathParts[pathParts.length - 1];
  
    const lot = lots.find(
      (item) => item.id === lotId
    );
  
    /* =========================
       SYNC
    ========================== */
  
    useEffect(() => {
      refreshLotsFromBackend()
        .then(setLots)
        .catch(() => setLots(getStoredLots()));

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
  
            <h2>
              Lot not found
            </h2>
  
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
       COMPLETE HANDOVER
    ========================== */
  
    const handleCompleteHandover = async () => {
      setError("");
  
      const measuredWeight =
        Number(physicalWeight);

      const enteredPin = collectorPin.trim();

      if (!/^\d{6}$/.test(enteredPin)) {
        setError(
          "Enter the 6-digit PIN shown on the collector app."
        );
        return;
      }

      // Collector PIN is derived from offline lot UUID (clientReference).
      // Also accept publicId / lot number for older rows.
      if (
        !matchesHandoverPin(
          enteredPin,
          lot.clientReference,
          lot.publicId,
          lot.id
        )
      ) {
        setError(
          "Incorrect collector PIN. Ask the collector to show the PIN from their app."
        );
        return;
      }
  
      if (
        !physicalWeight ||
        Number.isNaN(measuredWeight) ||
        measuredWeight <= 0
      ) {
        setError(
          "Please enter a valid physical weight."
        );
  
        return;
      }
  
      if (!collectorVerified) {
        setError(
          "Please verify the collector identity."
        );
  
        return;
      }
  
      if (!materialVerified) {
        setError(
          "Please verify the material."
        );
  
        return;
      }
  
      if (!weightVerified) {
        setError(
          "Please confirm the physical weight."
        );
  
        return;
      }

      if (paymentMethod !== "CASH" && paymentMethod !== "UPI") {
        setError(
          "Select Cash or UPI, then pay the collector before completing."
        );
        return;
      }
  
      try {
        // Prefer offline lot UUID so backend finds the collector handover.
        const handoverRef =
          lot.clientReference || lot.publicId || lot.id;
        const finalAmount =
          lot.estimatedValue != null && Number(lot.estimatedValue) > 0
            ? Number(lot.estimatedValue)
            : undefined;

        await confirmHandover(handoverRef, {
          completeBoth: true,
          paymentMethod,
          finalAmount,
        });

        // Confirm already settles + completes; status patch is best-effort.
        try {
          const updatedLots = await updateLotStatus(lot.id, "Completed");
          setLots(updatedLots);
        } catch {
          /* confirm succeeded — ignore idempotent status patch failures */
        }
        setCompleted(true);
      } catch (err) {
        setError(
          err instanceof Error
            ? err.message
            : "Could not complete handover on the server."
        );
      }
    };
  
    /* =========================
       WEIGHT DIFFERENCE
    ========================== */
  
    const measuredWeight =
      Number(physicalWeight);
  
    const weightDifference =
      physicalWeight &&
      !Number.isNaN(measuredWeight)
        ? measuredWeight - lot.weight
        : null;
  
    /* =========================
       COMPLETED SCREEN
    ========================== */
  
    if (completed) {
      return (
        <main className="page-content">
  
          <div className="details-page">
  
            <div className="verification-complete">
  
              <div className="verification-success-icon">
                <CheckCircle2 size={42} />
              </div>
  
              <span className="section-label">
                HANDOVER COMPLETED
              </span>
  
              <h1>
                Handover Successfully Completed
              </h1>
  
              <p>
                Lot <strong>{lot.id}</strong> has been
                verified and successfully handed over
                to the recycler facility.
              </p>
  
              <div className="completed-summary">
  
                <div>
                  <span>
                    Lot ID
                  </span>
  
                  <strong>
                    {lot.id}
                  </strong>
                </div>
  
                <div>
                  <span>
                    Material
                  </span>
  
                  <strong>
                    {lot.material}
                  </strong>
                </div>
  
                <div>
                  <span>
                    Collector
                  </span>
  
                  <strong>
                    {lot.collector}
                  </strong>
                </div>
  
                <div>
                  <span>
                    Verified Weight
                  </span>
  
                  <strong>
                    {physicalWeight} kg
                  </strong>
                </div>
  
              </div>
  
              <div className="completion-actions">
  
                <button
                  type="button"
                  className="primary-button"
                  onClick={() =>
                    navigate("/incoming-lots")
                  }
                >
                  <Package size={18} />
  
                  View Incoming Lots
                </button>
  
                <button
                  type="button"
                  className="secondary-button"
                  onClick={() =>
                    navigate(
                      `/incoming-lots/${lot.id}`
                    )
                  }
                >
                  <ArrowLeft size={18} />
  
                  Back to Lot Details
                </button>
  
              </div>
  
            </div>
  
          </div>
  
        </main>
      );
    }
  
    /* =========================
       MAIN VERIFICATION SCREEN
    ========================== */
  
    return (
      <main className="page-content">
  
        <div className="details-page">
  
          {/* BACK */}
  
          <button
            type="button"
            className="back-button"
            onClick={() =>
              navigate(
                `/incoming-lots/${lot.id}`
              )
            }
          >
            <ArrowLeft size={18} />
  
            Back to Lot Details
          </button>
  
          {/* HEADER */}
  
          <div className="details-header">
  
            <div>
  
              <div className="breadcrumb">
                Recycler Portal / Operations / Handover
                Verification
              </div>
  
              <h1>
                Handover Verification
              </h1>
  
              <p>
                Verify the physical collection before
                completing the recycler handover.
              </p>
  
            </div>
  
            <span className="status-badge status-handover">
              Handover
            </span>
  
          </div>
  
          {/* GRID */}
  
          <div className="verification-grid">
  
            {/* LEFT */}
  
            <div className="verification-main">
  
              {/* LOT IDENTITY */}
  
              <section className="details-card">
  
                <div className="section-heading">
  
                  <div className="heading-icon">
                    <ClipboardCheck size={20} />
                  </div>
  
                  <div>
                    <h2>
                      Lot Identity
                    </h2>
  
                    <p>
                      Confirm that the physical lot
                      matches the submitted collection.
                    </p>
                  </div>
  
                </div>
  
                <div className="verification-info-grid">
  
                  <div className="verification-info-item">
                    <span>
                      Lot ID
                    </span>
  
                    <strong>
                      {lot.id}
                    </strong>
                  </div>
  
                  <div className="verification-info-item">
                    <span>
                      Material
                    </span>
  
                    <strong>
                      {lot.material}
                    </strong>
                  </div>
  
                  <div className="verification-info-item">
                    <span>
                      Collector
                    </span>
  
                    <strong>
                      {lot.collector}
                    </strong>
                  </div>
  
                  <div className="verification-info-item">
                    <span>
                      Collection Location
                    </span>
  
                    <strong>
                      <MapPin size={15} />
                      {lot.location}
                    </strong>
                  </div>
  
                </div>
  
              </section>
  
              {/* COLLECTOR PIN */}

              <section className="details-card">
                <div className="section-heading">
                  <div className="heading-icon">
                    <ShieldCheck size={20} />
                  </div>
                  <div>
                    <h2>Collector PIN</h2>
                    <p>
                      Ask the collector for the 6-digit
                      PIN from the Kabadiwala Connect app.
                      This replaces QR scanning when the
                      recycler uses the website.
                    </p>
                  </div>
                </div>

                <div className="weight-input-block">
                  <label htmlFor="collector-pin">
                    6-digit handover PIN
                  </label>
                  <div className="weight-input">
                    <input
                      id="collector-pin"
                      type="text"
                      inputMode="numeric"
                      pattern="[0-9]*"
                      maxLength={6}
                      placeholder="••••••"
                      value={collectorPin}
                      onChange={(event) => {
                        const digits = event.target.value
                          .replace(/\D/g, "")
                          .slice(0, 6);
                        setCollectorPin(digits);
                        setError("");
                      }}
                      autoComplete="one-time-code"
                    />
                  </div>
                </div>
              </section>
  
              {/* PHYSICAL WEIGHT */}
  
              <section className="details-card">
  
                <div className="section-heading">
  
                  <div className="heading-icon">
                    <Weight size={20} />
                  </div>
  
                  <div>
                    <h2>
                      Physical Weight Verification
                    </h2>
  
                    <p>
                      Enter the weight measured at the
                      recycler facility.
                    </p>
                  </div>
  
                </div>
  
                <div className="weight-comparison">
  
                  <div className="expected-weight">
  
                    <span>
                      Expected Weight
                    </span>
  
                    <strong>
                      {lot.weight} kg
                    </strong>
  
                  </div>
  
                  <div className="weight-input-block">
  
                    <label htmlFor="physical-weight">
                      Physical Weight
                    </label>
  
                    <div className="weight-input">
  
                      <input
                        id="physical-weight"
                        type="number"
                        min="0"
                        step="0.1"
                        placeholder="Enter weight"
                        value={physicalWeight}
                        onChange={(event) => {
                          setPhysicalWeight(
                            event.target.value
                          );
  
                          setWeightVerified(false);
                          setError("");
                        }}
                      />
  
                      <span>
                        kg
                      </span>
  
                    </div>
  
                  </div>
  
                </div>
  
                {weightDifference !== null && (
                  <div
                    className={`weight-difference ${
                      Math.abs(
                        weightDifference
                      ) <= 0.5
                        ? "within-tolerance"
                        : "outside-tolerance"
                    }`}
                  >
  
                    {Math.abs(
                      weightDifference
                    ) <= 0.5 ? (
                      <CheckCircle2 size={18} />
                    ) : (
                      <XCircle size={18} />
                    )}
  
                    <span>
  
                      Difference:
  
                      {" "}
  
                      {weightDifference > 0
                        ? "+"
                        : ""}
  
                      {weightDifference.toFixed(1)}
                      {" "}
                      kg
  
                      {" — "}
  
                      {Math.abs(
                        weightDifference
                      ) <= 0.5
                        ? "Within verification tolerance"
                        : "Please re-check the physical lot"}
  
                    </span>
  
                  </div>
                )}
  
              </section>
  
              {/* CHECKLIST */}
  
              <section className="details-card">
  
                <div className="section-heading">
  
                  <div className="heading-icon">
                    <ShieldCheck size={20} />
                  </div>
  
                  <div>
                    <h2>
                      Verification Checklist
                    </h2>
  
                    <p>
                      Confirm each item before completing
                      the handover.
                    </p>
                  </div>
  
                </div>
  
                <div className="verification-checklist">
  
                  {/* COLLECTOR */}
  
                  <label
                    className={`verification-check ${
                      collectorVerified
                        ? "checked"
                        : ""
                    }`}
                  >
  
                    <input
                      type="checkbox"
                      checked={
                        collectorVerified
                      }
                      onChange={(event) =>
                        setCollectorVerified(
                          event.target.checked
                        )
                      }
                    />
  
                    <div className="check-icon">
                      <User size={18} />
                    </div>
  
                    <div className="check-content">
  
                      <strong>
                        Collector identity verified
                      </strong>
  
                      <span>
                        {lot.collector}
                      </span>
  
                    </div>
  
                    {collectorVerified && (
                      <CheckCircle2
                        size={20}
                        className="check-complete"
                      />
                    )}
  
                  </label>
  
                  {/* MATERIAL */}
  
                  <label
                    className={`verification-check ${
                      materialVerified
                        ? "checked"
                        : ""
                    }`}
                  >
  
                    <input
                      type="checkbox"
                      checked={
                        materialVerified
                      }
                      onChange={(event) =>
                        setMaterialVerified(
                          event.target.checked
                        )
                      }
                    />
  
                    <div className="check-icon">
                      <Package size={18} />
                    </div>
  
                    <div className="check-content">
  
                      <strong>
                        Material verified
                      </strong>
  
                      <span>
                        {lot.material} — {lot.condition}
                      </span>
  
                    </div>
  
                    {materialVerified && (
                      <CheckCircle2
                        size={20}
                        className="check-complete"
                      />
                    )}
  
                  </label>
  
                  {/* WEIGHT */}
  
                  <label
                    className={`verification-check ${
                      weightVerified
                        ? "checked"
                        : ""
                    }`}
                  >
  
                    <input
                      type="checkbox"
                      checked={
                        weightVerified
                      }
                      onChange={(event) =>
                        setWeightVerified(
                          event.target.checked
                        )
                      }
                    />
  
                    <div className="check-icon">
                      <Weight size={18} />
                    </div>
  
                    <div className="check-content">
  
                      <strong>
                        Physical weight confirmed
                      </strong>
  
                      <span>
                        Expected: {lot.weight} kg
                        {physicalWeight
                          ? ` • Measured: ${physicalWeight} kg`
                          : ""}
                      </span>
  
                    </div>
  
                    {weightVerified && (
                      <CheckCircle2
                        size={20}
                        className="check-complete"
                      />
                    )}
  
                  </label>
  
                </div>
  
              </section>
  
            </div>
  
            {/* RIGHT SIDEBAR */}
  
            <aside className="details-sidebar">
  
              {/* SUMMARY */}
  
              <section className="details-card">
  
                <span className="section-label">
                  HANDOVER SUMMARY
                </span>
  
                <div className="summary-row">
                  <span>
                    Lot ID
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
                    Collector
                  </span>
  
                  <strong>
                    {lot.collector}
                  </strong>
                </div>
  
                <div className="summary-row">
                  <span>
                    Expected Weight
                  </span>
  
                  <strong>
                    {lot.weight} kg
                  </strong>
                </div>
  
                <div className="summary-row">
                  <span>
                    Estimated Value
                  </span>
  
                  <strong>
                    {lot.estimatedValue === null
                      ? "—"
                      : `₹${lot.estimatedValue.toLocaleString(
                          "en-IN"
                        )}`}
                  </strong>
                </div>
  
                <div className="summary-row">
                  <span>
                    Verification
                  </span>
  
                  <strong className="text-warning">
                    In Progress
                  </strong>
                </div>
  
              </section>
  
              {/* PAY COLLECTOR */}

              <section className="details-card">
                <h3>Pay collector</h3>
                <p>
                  After the PIN matches, settle payment
                  here. The collector app then shows a
                  receipt and updates earnings.
                </p>
                <div className="weight-comparison" style={{ marginTop: 12 }}>
                  <button
                    type="button"
                    className={paymentMethod === "CASH" ? "accept-button" : "secondary-button"}
                    onClick={() => {
                      setPaymentMethod("CASH");
                      setError("");
                    }}
                  >
                    Cash
                  </button>
                  <button
                    type="button"
                    className={paymentMethod === "UPI" ? "accept-button" : "secondary-button"}
                    onClick={() => {
                      setPaymentMethod("UPI");
                      setError("");
                    }}
                  >
                    UPI
                  </button>
                </div>
              </section>
  
              {/* COMPLETE */}
  
              <section className="details-card action-card">
  
                <h3>
                  Complete Handover
                </h3>
  
                <p>
                  PIN, checks, and payment must be
                  completed before the lot is marked paid.
                </p>
  
                {error && (
                  <div className="verification-error">
  
                    <XCircle size={17} />
  
                    <span>
                      {error}
                    </span>
  
                  </div>
                )}
  
                <button
                  type="button"
                  className="accept-button"
                  onClick={
                    handleCompleteHandover
                  }
                >
                  <CheckCircle2 size={18} />
  
                  Complete Handover
                </button>
  
                <button
                  type="button"
                  className="reject-button"
                  onClick={() =>
                    navigate(
                      `/incoming-lots/${lot.id}`
                    )
                  }
                >
                  <ArrowLeft size={17} />
  
                  Back to Lot
                </button>
  
              </section>
  
            </aside>
  
          </div>
  
        </div>
  
      </main>
    );
  }
  
  export default HandoverVerification;