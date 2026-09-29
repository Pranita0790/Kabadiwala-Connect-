import {
    BarChart3,
    CircleDollarSign,
    Pencil,
    RefreshCw,
    Save,
    TrendingUp,
    X,
  } from "lucide-react";
  
  import {
    useEffect,
    useMemo,
    useState,
  } from "react";
  
  type Rate = {
    id: string;
    material: string;
    category: string;
    ratePerKg: number;
    unit: string;
    updatedAt: string;
  };
  
  const API_BASE = "https://kabadiwala-backend-69wr.onrender.com/api";
  
  export default function RateBoard() {
    const [rates, setRates] = useState<Rate[]>([]);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState("");
  
    const [editingId, setEditingId] =
      useState<string | null>(null);
  
    const [editRate, setEditRate] =
      useState("");
  
    /* =========================================================
       LOAD RATES
       ========================================================= */
  
    const loadRates = async () => {
      try {
        setLoading(true);
        setError("");
  
        const response = await fetch(
          `${API_BASE}/rates`
        );
  
        if (!response.ok) {
          throw new Error(
            "Failed to fetch rates"
          );
        }
  
        const data = await response.json();
  
        setRates(
          Array.isArray(data)
            ? data
            : data.rates || []
        );
      } catch (err) {
        console.error(
          "Rate Board error:",
          err
        );
  
        setError(
          "Unable to load rates from backend."
        );
      } finally {
        setLoading(false);
      }
    };
  
    useEffect(() => {
      loadRates();
    }, []);
  
    /* =========================================================
       START EDIT
       ========================================================= */
  
    const startEditing = (rate: Rate) => {
      setEditingId(rate.id);
      setEditRate(
        String(rate.ratePerKg)
      );
    };
  
    /* =========================================================
       CANCEL EDIT
       ========================================================= */
  
    const cancelEditing = () => {
      setEditingId(null);
      setEditRate("");
    };
  
    /* =========================================================
       SAVE RATE
       ========================================================= */
  
    const saveRate = async (
      rate: Rate
    ) => {
      const numericRate =
        Number(editRate);
  
      if (
        !Number.isFinite(
          numericRate
        ) ||
        numericRate < 0
      ) {
        setError(
          "Please enter a valid rate."
        );
  
        return;
      }
  
      try {
        setSaving(true);
        setError("");
  
        const response = await fetch(
          `${API_BASE}/rates/${encodeURIComponent(
            rate.id
          )}`,
          {
            method: "PUT",
  
            headers: {
              "Content-Type":
                "application/json",
            },
  
            body: JSON.stringify({
              ratePerKg:
                numericRate,
            }),
          }
        );
  
        if (!response.ok) {
          throw new Error(
            "Failed to update rate"
          );
        }
  
        const updatedRate =
          await response.json();
  
        setRates((current) =>
          current.map((item) =>
            item.id === rate.id
              ? updatedRate
              : item
          )
        );
  
        cancelEditing();
      } catch (err) {
        console.error(
          "Failed to save rate:",
          err
        );
  
        setError(
          "Failed to update the rate."
        );
      } finally {
        setSaving(false);
      }
    };
  
    /* =========================================================
       SUMMARY
       ========================================================= */
  
    const averageRate =
      useMemo(() => {
        if (rates.length === 0) {
          return 0;
        }
  
        return (
          rates.reduce(
            (sum, rate) =>
              sum + Number(rate.ratePerKg),
            0
          ) / rates.length
        );
      }, [rates]);
  
    const highestRate =
      useMemo(() => {
        if (rates.length === 0) {
          return null;
        }
  
        return rates.reduce(
          (highest, current) =>
            current.ratePerKg >
            highest.ratePerKg
              ? current
              : highest
        );
      }, [rates]);
  
    const lowestRate =
      useMemo(() => {
        if (rates.length === 0) {
          return null;
        }
  
        return rates.reduce(
          (lowest, current) =>
            current.ratePerKg <
            lowest.ratePerKg
              ? current
              : lowest
        );
      }, [rates]);
  
    /* =========================================================
       RENDER
       ========================================================= */
  
    return (
      <section className="page-content rate-board-page">
  
        {/* =====================================================
            HEADER
            ===================================================== */}
  
        <div className="page-heading">
  
          <div>
  
            <p className="breadcrumb">
              Recycler Portal / Rate Board
            </p>
  
            <h2>
              Rate Board
            </h2>
  
            <p>
              Manage current material rates used
              for valuation and recycler transactions.
            </p>
  
          </div>
  
          <button
            type="button"
            className="rate-refresh-button"
            onClick={loadRates}
            disabled={loading}
          >
            <RefreshCw
              size={17}
              className={
                loading
                  ? "rate-refresh-spin"
                  : ""
              }
            />
  
            Refresh Rates
          </button>
  
        </div>
  
  
        {/* =====================================================
            ERROR
            ===================================================== */}
  
        {error && (
          <div className="rate-error">
            {error}
          </div>
        )}
  
  
        {/* =====================================================
            SUMMARY CARDS
            ===================================================== */}
  
        <div className="rate-summary-grid">
  
          <div className="rate-summary-card">
  
            <div className="rate-summary-icon">
              <BarChart3 size={21} />
            </div>
  
            <div>
              <span>
                Materials Covered
              </span>
  
              <strong>
                {rates.length}
              </strong>
            </div>
  
          </div>
  
  
          <div className="rate-summary-card">
  
            <div className="rate-summary-icon">
              <CircleDollarSign size={21} />
            </div>
  
            <div>
              <span>
                Average Rate
              </span>
  
              <strong>
                ₹
                {averageRate.toLocaleString(
                  "en-IN",
                  {
                    maximumFractionDigits: 0,
                  }
                )}
                /kg
              </strong>
            </div>
  
          </div>
  
  
          <div className="rate-summary-card">
  
            <div className="rate-summary-icon">
              <TrendingUp size={21} />
            </div>
  
            <div>
              <span>
                Highest Rate
              </span>
  
              <strong>
                {highestRate
                  ? `₹${Number(
                      highestRate.ratePerKg
                    ).toLocaleString(
                      "en-IN"
                    )}/kg`
                  : "—"}
              </strong>
  
              {highestRate && (
                <small>
                  {highestRate.material}
                </small>
              )}
            </div>
  
          </div>
  
  
          <div className="rate-summary-card">
  
            <div className="rate-summary-icon">
              <CircleDollarSign size={21} />
            </div>
  
            <div>
              <span>
                Lowest Rate
              </span>
  
              <strong>
                {lowestRate
                  ? `₹${Number(
                      lowestRate.ratePerKg
                    ).toLocaleString(
                      "en-IN"
                    )}/kg`
                  : "—"}
              </strong>
  
              {lowestRate && (
                <small>
                  {lowestRate.material}
                </small>
              )}
            </div>
  
          </div>
  
        </div>
  
  
        {/* =====================================================
            TOOLBAR
            ===================================================== */}
  
        <div className="rate-toolbar">
  
          <div>
  
            <h3>
              Current Material Rates
            </h3>
  
            <p>
              Rates are maintained by the recycler
              and used for estimated valuation.
            </p>
  
          </div>
  
          <div className="rate-disclaimer">
  
            <span>
              Rates shown are indicative
              market values.
            </span>
  
          </div>
  
        </div>
  
  
        {/* =====================================================
            TABLE
            ===================================================== */}
  
        <div className="table-card rate-table-card">
  
          {loading ? (
  
            <div className="rate-loading">
              Loading current rates...
            </div>
  
          ) : rates.length === 0 ? (
  
            <div className="rate-empty">
              <BarChart3 size={32} />
  
              <strong>
                No rates available
              </strong>
  
              <span>
                Add rate data through the backend.
              </span>
            </div>
  
          ) : (
  
            <table>
  
              <thead>
  
                <tr>
  
                  <th>
                    MATERIAL
                  </th>
  
                  <th>
                    CATEGORY
                  </th>
  
                  <th>
                    CURRENT RATE
                  </th>
  
                  <th>
                    UNIT
                  </th>
  
                  <th>
                    LAST UPDATED
                  </th>
  
                  <th>
                    ACTION
                  </th>
  
                </tr>
  
              </thead>
  
  
              <tbody>
  
                {rates.map(
                  (rate) => (
  
                    <tr key={rate.id}>
  
                      <td>
  
                        <strong>
                          {rate.material}
                        </strong>
  
                      </td>
  
  
                      <td>
  
                        <span className="material-pill">
                          {rate.category}
                        </span>
  
                      </td>
  
  
                      <td>
  
                        {editingId === rate.id ? (
  
                          <div className="rate-edit-cell">
  
                            <span>
                              ₹
                            </span>
  
                            <input
                              type="number"
                              min="0"
                              step="1"
                              value={editRate}
                              onChange={(event) =>
                                setEditRate(
                                  event.target.value
                                )
                              }
                              autoFocus
                            />
  
                          </div>
  
                        ) : (
  
                          <strong className="rate-value">
                            ₹
                            {Number(
                              rate.ratePerKg
                            ).toLocaleString(
                              "en-IN",
                              {
                                maximumFractionDigits: 0,
                              }
                            )}
                          </strong>
  
                        )}
  
                      </td>
  
  
                      <td>
                        {rate.unit}
                      </td>
  
  
                      <td>
                        {rate.updatedAt}
                      </td>
  
  
                      <td>
  
                        {editingId === rate.id ? (
  
                          <div className="rate-action-group">
  
                            <button
                              type="button"
                              className="rate-save-button"
                              onClick={() =>
                                saveRate(rate)
                              }
                              disabled={saving}
                            >
                              <Save size={15} />
  
                              Save
                            </button>
  
                            <button
                              type="button"
                              className="rate-cancel-button"
                              onClick={
                                cancelEditing
                              }
                              disabled={saving}
                            >
                              <X size={15} />
  
                              Cancel
                            </button>
  
                          </div>
  
                        ) : (
  
                          <button
                            type="button"
                            className="rate-edit-button"
                            onClick={() =>
                              startEditing(rate)
                            }
                          >
                            <Pencil size={15} />
  
                            Edit
                          </button>
  
                        )}
  
                      </td>
  
                    </tr>
  
                  )
                )}
  
              </tbody>
  
            </table>
  
          )}
  
        </div>
  
  
        {/* =====================================================
            FOOTNOTE
            ===================================================== */}
  
        <div className="rate-board-note">
  
          <CircleDollarSign size={18} />
  
          <p>
            Rate Board values are used as reference
            rates for material valuation. Final settlement
            may depend on material condition, quality,
            weight verification and recycler approval.
          </p>
  
        </div>
  
      </section>
    );
  }