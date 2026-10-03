import {
  AlertTriangle,
  CheckCircle2,
  Clock3,
  Eye,
  Filter,
  MapPin,
  Search,
  ShieldCheck,
  Truck,
} from "lucide-react";

import {
  useEffect,
  useMemo,
  useState,
} from "react";

import { useNavigate } from "react-router-dom";

import type { LotStatus } from "../data/mockLots";

import {
  getStoredLots,
  refreshLotsFromBackend,
} from "../data/lotsStore";

const statusOptions: Array<"All" | LotStatus> = [
  "All",
  "Pending",
  "Accepted",
  "Rejected",
  "Handover",
  "Completed",
];
function IncomingLots() {
  const navigate = useNavigate();

  /* =========================
     LOT DATA
  ========================== */

  const [lots, setLots] = useState(() => getStoredLots());

  /* =========================
     SEARCH
  ========================== */

  const [search, setSearch] = useState("");

  /* =========================
     STATUS FILTER
  ========================== */

  const [status, setStatus] =
    useState<"All" | LotStatus>("All");

  /* =========================
     SYNC LOT DATA
  ========================== */

  useEffect(() => {
    refreshLotsFromBackend()
      .then(setLots)
      .catch(() => setLots(getStoredLots()));

    const interval = window.setInterval(() => {
      refreshLotsFromBackend().then(setLots).catch(() => {});
    }, 12000);

    const handleLotsUpdated = () => {
      setLots(getStoredLots());
    };

    window.addEventListener(
      "kabadiwala-lots-updated",
      handleLotsUpdated
    );

    return () => {
      window.clearInterval(interval);
      window.removeEventListener(
        "kabadiwala-lots-updated",
        handleLotsUpdated
      );
    };
  }, []);

  /* =========================
     FILTER LOTS
  ========================== */

  const filteredLots = useMemo(() => {
    return lots.filter((lot) => {
      const searchValue =
        search.toLowerCase().trim();

      const matchesSearch =
        lot.id
          .toLowerCase()
          .includes(searchValue) ||
        lot.collector
          .toLowerCase()
          .includes(searchValue) ||
        lot.material
          .toLowerCase()
          .includes(searchValue);

      const matchesStatus =
        status === "All" ||
        String(lot.status).toLowerCase() === status.toLowerCase();

      return (
        matchesSearch &&
        matchesStatus
      );
    });
  }, [lots, search, status]);

  /* =========================
     SUMMARY COUNTS
  ========================== */

  const totalIncoming = lots.length;

  const pendingCount = lots.filter(
    (lot) => lot.status === "Pending"
  ).length;

  const acceptedCount = lots.filter(
    (lot) => lot.status === "Accepted"
  ).length;

  const criticalMineralCount =
    lots.filter(
      (lot) => lot.criticalMineral
    ).length;

  /* =========================
     RENDER
  ========================== */

  return (
    <section className="page-content">

      {/* =========================
          PAGE HEADER
      ========================== */}

      <div className="page-heading">

        <div>

          <p>
            Review collection requests received from
            registered collectors.
          </p>

        </div>

        <div className="pending-summary">

          <Clock3 size={17} />

          <span>

            <strong>
              {pendingCount}
            </strong>{" "}

            pending requests

          </span>

        </div>

      </div>

      {/* =========================
          SUMMARY CARDS
      ========================== */}

      <div className="lot-summary-grid">

        {/* TOTAL INCOMING */}

        <div className="lot-summary-card">

          <div className="summary-icon">
            <Truck size={20} />
          </div>

          <div>

            <span>
              Total incoming
            </span>

            <strong>
              {totalIncoming}
            </strong>

          </div>

        </div>

        {/* PENDING */}

        <div className="lot-summary-card">

          <div className="summary-icon warning">
            <Clock3 size={20} />
          </div>

          <div>

            <span>
              Pending review
            </span>

            <strong>
              {pendingCount}
            </strong>

          </div>

        </div>

        {/* ACCEPTED */}

        <div className="lot-summary-card">

          <div className="summary-icon success">
            <CheckCircle2 size={20} />
          </div>

          <div>

            <span>
              Accepted
            </span>

            <strong>
              {acceptedCount}
            </strong>

          </div>

        </div>

        {/* CRITICAL MINERAL */}

        <div className="lot-summary-card">

          <div className="summary-icon">
            <ShieldCheck size={20} />
          </div>

          <div>

            <span>
              Critical-mineral flags
            </span>

            <strong>
              {criticalMineralCount}
            </strong>

          </div>

        </div>

      </div>

      {/* =========================
          SEARCH + FILTER TOOLBAR
      ========================== */}

      <div className="lot-toolbar">

        {/* SEARCH */}

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

        {/* STATUS FILTER */}

        <div className="filter-group">

          <Filter size={16} />

          {statusOptions.map(
            (option) => (
              <button
                type="button"
                key={option}
                className={
                  status === option
                    ? "filter-active"
                    : ""
                }
                onClick={() =>
                  setStatus(option)
                }
              >
                {option}
              </button>
            )
          )}

        </div>

      </div>

      {/* =========================
          LOTS TABLE
      ========================== */}

      <div className="lots-table-card">

        <table>

          <thead>

            <tr>

              <th>
                LOT
              </th>

              <th>
                MATERIAL
              </th>

              <th>
                COLLECTOR
              </th>

              <th>
                WEIGHT
              </th>

              <th>
                AI CONFIDENCE
              </th>

              <th>
                EST. VALUE
              </th>

              <th>
                STATUS
              </th>

              <th>
                ACTION
              </th>

            </tr>

          </thead>

          <tbody>

            {filteredLots.map(
              (lot) => (

                <tr key={lot.id}>

                  {/* LOT */}

                  <td>

                    <strong>
                      {lot.id}
                    </strong>

                    <span className="lot-date">
                      {lot.createdAt}
                    </span>

                  </td>

                  {/* MATERIAL */}

                  <td>

                    <span className="material-pill">
                      {lot.material}
                    </span>

                    {lot.criticalMineral && (
                      <span className="critical-mini">

                        <AlertTriangle
                          size={11}
                        />

                        Flagged

                      </span>
                    )}

                  </td>

                  {/* COLLECTOR */}

                  <td>

                    <strong className="collector-name">
                      {lot.collector}
                    </strong>

                    <span className="location-text">

                      <MapPin size={11} />

                      {lot.location}

                    </span>

                  </td>

                  {/* WEIGHT */}

                  <td>
                    {lot.weight.toFixed(1)} kg
                  </td>

                  {/* AI CONFIDENCE */}

                  <td>

                    <div className="confidence-cell">

                      <div className="confidence-track">

                        <div
                          className="confidence-fill"
                          style={{
                            width: `${lot.aiConfidence * 100}%`,
                          }}
                        />

                      </div>

                      <span>
                        {(
                          lot.aiConfidence * 100
                        ).toFixed(1)}
                        %
                      </span>

                    </div>

                  </td>

                  {/* ESTIMATED VALUE */}

                  <td>

                    {lot.estimatedValue === null
                      ? "—"
                      : `₹${lot.estimatedValue.toLocaleString(
                          "en-IN",
                          {
                            maximumFractionDigits: 0,
                          }
                        )}`}

                  </td>

                  {/* STATUS */}

                  <td>

                    <span
                      className={`status-pill ${lot.status
                        .toLowerCase()
                        .replace(" ", "-")}`}
                    >
                      {lot.status}
                    </span>

                  </td>

                  {/* VIEW */}

                  <td>

                    <button
                      type="button"
                      className="view-lot-button"
                      onClick={() =>
                        navigate(
                          `/incoming-lots/${lot.id}`
                        )
                      }
                    >

                      <Eye size={16} />

                      View

                    </button>

                  </td>

                </tr>

              )
            )}

          </tbody>

        </table>

        {/* =========================
            EMPTY STATE
        ========================== */}

        {filteredLots.length === 0 && (

          <div className="empty-state">

            <Search size={28} />

            <strong>
              No lots found
            </strong>

            <span>
              {lots.length === 0
                ? "No lots on the server yet. Login in the collector app, save a lot, tap Sync, then click All (new lots are Pending, not Accepted)."
                : "Try All instead of Accepted — new lots arrive as Pending until you accept them."}
            </span>

          </div>

        )}

      </div>

    </section>
  );
}

export default IncomingLots;