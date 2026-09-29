import {
  BarChart3,
  Bell,
  ChevronDown,
  CircleDollarSign,
  ClipboardCheck,
  Clock3,
  FileCheck2,
  LayoutDashboard,
  MapPin,
  PackageCheck,
  Recycle,
  Settings,
  ShieldCheck,
  Truck,
  Wallet,
} from "lucide-react";

import {
  NavLink,
  useLocation,
} from "react-router-dom";

import {
  lazy,
  Suspense,
  useEffect,
  useState,
} from "react";

import "./App.css";

import {
  getStoredLots,
} from "./data/lotsStore";


/* =========================================================
   LAZY PAGE IMPORTS
   ========================================================= */

const IncomingLots = lazy(
  () => import("./pages/IncomingLots")
);

const LotDetails = lazy(
  () => import("./pages/LotDetails")
);

const HandoverVerification = lazy(
  () => import("./pages/HandoverVerification")
);

const Transactions = lazy(
  () => import("./pages/Transactions")
);

const Traceability = lazy(
  () => import("./pages/Traceability")
);

const RateBoard = lazy(
  () => import("./pages/RateBoard")
);


/* =========================================================
   TYPES
   ========================================================= */

type Lot = ReturnType<typeof getStoredLots>[number];


/* =========================================================
   LOADING COMPONENT
   ========================================================= */

function PageLoading() {
  return (
    <div
      style={{
        minHeight: "400px",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: "16px",
        color: "#52756a",
      }}
    >
      Loading...
    </div>
  );
}


/* =========================================================
   DASHBOARD
   ========================================================= */

function Dashboard({
  lots,
}: {
  lots: Lot[];
}) {
  const recentLots = lots.slice(0, 4);

  const totalLots = lots.length;

  const pendingLots = lots.filter(
    (lot) => lot.status === "Pending"
  ).length;

  const completedLots = lots.filter(
    (lot) =>
      lot.status === "Completed" ||
      lot.status === "Accepted"
  ).length;

  const totalValue = lots.reduce(
    (sum, lot) =>
      sum +
      (typeof lot.estimatedValue === "number"
        ? lot.estimatedValue
        : 0),
    0
  );

  const criticalLots = lots.filter(
    (lot) => Boolean(lot.criticalMineral)
  ).length;


  return (
    <section className="dashboard-content">

      {/* =================================================
          WELCOME
          ================================================= */}

      <div className="welcome-row">

        <div>

          <h3>
            Good morning, EcoCycle 👋
          </h3>

          <p>
            Here's what's happening with
            your recycling operations today.
          </p>

        </div>


        <div className="location-chip">

          <MapPin size={16} />

          Mumbai

        </div>

      </div>


      {/* =================================================
          STAT CARDS
          ================================================= */}

      <div className="stats-grid">

        {/* TOTAL LOTS */}

        <div className="stat-card">

          <div className="stat-top">

            <div className="stat-icon">
              <PackageCheck size={20} />
            </div>

          </div>

          <p>
            Total Lots
          </p>

          <h4>
            {totalLots}
          </h4>

          <span className="stat-change">
            Live from backend
          </span>

        </div>


        {/* PENDING */}

        <div className="stat-card">

          <div className="stat-top">

            <div className="stat-icon">
              <Clock3 size={20} />
            </div>

          </div>

          <p>
            Pending Requests
          </p>

          <h4>
            {pendingLots}
          </h4>

          <span className="stat-change">
            Requires action
          </span>

        </div>


        {/* COMPLETED */}

        <div className="stat-card">

          <div className="stat-top">

            <div className="stat-icon">
              <ClipboardCheck size={20} />
            </div>

          </div>

          <p>
            Completed
          </p>

          <h4>
            {completedLots}
          </h4>

          <span className="stat-change">
            Completed lots
          </span>

        </div>


        {/* PAYMENTS */}

        <div className="stat-card">

          <div className="stat-top">

            <div className="stat-icon">
              <CircleDollarSign size={20} />
            </div>

          </div>

          <p>
            Total Payments
          </p>

          <h4>
            ₹
            {totalValue.toLocaleString(
              "en-IN",
              {
                maximumFractionDigits: 0,
              }
            )}
          </h4>

          <span className="stat-change">
            Estimated lot value
          </span>

        </div>

      </div>


      {/* =================================================
          RECENT LOTS HEADER
          ================================================= */}

      <div className="section-header">

        <div>

          <h3>
            Recent Incoming Lots
          </h3>

          <p>
            Latest collection requests
            from registered collectors.
          </p>

        </div>


        <NavLink
          to="/incoming-lots"
          className="text-button"
        >
          View all lots →
        </NavLink>

      </div>


      {/* =================================================
          RECENT LOTS TABLE
          ================================================= */}

      <div className="table-card">

        <table>

          <thead>

            <tr>

              <th>
                LOT ID
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
                EST. VALUE
              </th>

              <th>
                STATUS
              </th>

            </tr>

          </thead>


          <tbody>

            {recentLots.length === 0 ? (

              <tr>

                <td
                  colSpan={6}
                  style={{
                    textAlign: "center",
                    padding: "40px",
                  }}
                >
                  No lots available.
                </td>

              </tr>

            ) : (

              recentLots.map(
                (lot) => (

                  <tr key={lot.id}>

                    <td>

                      <strong>
                        {lot.id}
                      </strong>

                    </td>


                    <td>

                      <span className="material-pill">
                        {lot.material}
                      </span>

                    </td>


                    <td>
                      {lot.collector}
                    </td>


                    <td>
                      {Number(lot.weight).toFixed(1)} kg
                    </td>


                    <td>

                      {lot.estimatedValue === null ||
                      lot.estimatedValue === undefined
                        ? "—"
                        : `₹${Number(
                            lot.estimatedValue
                          ).toLocaleString(
                            "en-IN",
                            {
                              maximumFractionDigits: 0,
                            }
                          )}`}

                    </td>


                    <td>

                      <span
                        className={`status-pill ${String(
                          lot.status
                        )
                          .toLowerCase()
                          .replace(
                            /\s+/g,
                            "-"
                          )}`}
                      >
                        {lot.status}
                      </span>

                    </td>

                  </tr>

                )
              )

            )}

          </tbody>

        </table>

      </div>


      {/* =================================================
          BOTTOM GRID
          ================================================= */}

      <div className="bottom-grid">


        {/* TODAY'S OPERATIONS */}

        <div className="info-card">

          <div className="info-card-header">

            <div>

              <h3>
                Today's Operations
              </h3>

              <p>
                Current processing activity
              </p>

            </div>

            <PackageCheck size={22} />

          </div>


          {/* LOTS RECEIVED */}

          <div className="progress-row">

            <div>

              <span>
                Lots received
              </span>

              <strong>
                {totalLots}
              </strong>

            </div>


            <div className="progress-track">

              <div
                className="progress-fill"
                style={{
                  width:
                    totalLots > 0
                      ? "72%"
                      : "0%",
                }}
              />

            </div>

          </div>


          {/* HANDOVERS */}

          <div className="progress-row">

            <div>

              <span>
                Handovers completed
              </span>

              <strong>
                {
                  lots.filter(
                    (lot) =>
                      lot.status === "Handover"
                  ).length
                }
              </strong>

            </div>


            <div className="progress-track">

              <div
                className="progress-fill"
                style={{
                  width: "67%",
                }}
              />

            </div>

          </div>

        </div>


        {/* MATERIAL INTELLIGENCE */}

        <div className="info-card critical-card">

          <div className="critical-header">

            <div className="critical-icon">

              <ShieldCheck size={21} />

            </div>

            <div>

              <h3>
                Material Intelligence
              </h3>

              <p>
                AI-assisted screening
              </p>

            </div>

          </div>


          <div className="critical-stat">

            <strong>
              {criticalLots}
            </strong>

            <span>
              potential
              critical-mineral-associated
              lots
            </span>

          </div>


          <p className="critical-note">

            Review flagged lots before
            processing and maintain the
            traceability record.

          </p>

        </div>

      </div>

    </section>
  );
}


/* =========================================================
   APP
   ========================================================= */

function App() {

  const location = useLocation();


  const [
    lots,
    setLots,
  ] = useState<Lot[]>(
    getStoredLots
  );


  /* =========================================================
     ROUTES
     ========================================================= */

  const isDashboard =
    location.pathname === "/";

  const isIncomingLots =
    location.pathname === "/incoming-lots";

  const isTransactions =
    location.pathname === "/transactions";

  const isTraceability =
    location.pathname === "/traceability";

  const isRateBoard =
    location.pathname === "/rate-board";

  const isLotDetails =
    location.pathname.startsWith(
      "/incoming-lots/"
    );

  const isVerification =
    location.pathname.startsWith(
      "/verification"
    );


  /* =========================================================
     SYNC LOT DATA
     ========================================================= */

  useEffect(() => {

    const handleLotsUpdated = () => {

      try {

        setLots(
          getStoredLots()
        );

      } catch (error) {

        console.error(
          "Failed to load stored lots:",
          error
        );

      }

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


  /* =========================================================
     CURRENT VERIFICATION LOT
     ========================================================= */

  const handoverLot = lots.find(
    (lot) =>
      lot.status === "Handover"
  );


  /* =========================================================
     PAGE TITLE
     ========================================================= */

  const getPageTitle = () => {

    if (isVerification) {
      return "Handover Verification";
    }

    if (isLotDetails) {
      return "Lot Details";
    }

    if (isIncomingLots) {
      return "Incoming Lots";
    }

    if (isTransactions) {
      return "Transactions";
    }

    if (isTraceability) {
      return "Traceability";
    }

    if (isRateBoard) {
      return "Rate Board";
    }

    return "Dashboard";

  };


  /* =========================================================
     BREADCRUMB
     ========================================================= */

  const getBreadcrumb = () => {

    if (isVerification) {
      return "Operations / Handover Verification";
    }

    if (isLotDetails) {
      return "Operations / Lot Details";
    }

    if (isIncomingLots) {
      return "Operations";
    }

    if (isTransactions) {
      return "Finance";
    }

    if (isTraceability) {
      return "Traceability";
    }

    if (isRateBoard) {
      return "Finance / Rate Board";
    }

    return "Overview";

  };


  /* =========================================================
     RENDER
     ========================================================= */

  return (

    <div className="app-shell">


      {/* =====================================================
          SIDEBAR
          ===================================================== */}

      <aside className="sidebar">


        {/* BRAND */}

        <div className="brand">

          <div className="brand-icon">

            <Recycle size={24} />

          </div>


          <div>

            <h1>
              Kabadiwala
            </h1>

            <span>
              CONNECT
            </span>

          </div>

        </div>


        {/* ===================================================
            MAIN MENU
            =================================================== */}

        <div className="sidebar-section">

          <p className="sidebar-label">
            MAIN MENU
          </p>


          <nav className="nav-list">


            {/* DASHBOARD */}

            <NavLink
              to="/"
              className={({ isActive }) =>
                `nav-item ${
                  isActive
                    ? "active"
                    : ""
                }`
              }
            >

              <LayoutDashboard size={19} />

              <span>
                Dashboard
              </span>

            </NavLink>


            {/* INCOMING LOTS */}

            <NavLink
              to="/incoming-lots"
              className={({ isActive }) =>
                `nav-item ${
                  isActive ||
                  isLotDetails
                    ? "active"
                    : ""
                }`
              }
            >

              <Truck size={19} />

              <span>
                Incoming Lots
              </span>


              <span className="nav-badge">

                {
                  lots.filter(
                    (lot) =>
                      lot.status ===
                      "Pending"
                  ).length
                }

              </span>

            </NavLink>


            {/* TRANSACTIONS */}

            <NavLink
              to="/transactions"
              className={({ isActive }) =>
                `nav-item ${
                  isActive
                    ? "active"
                    : ""
                }`
              }
            >

              <Wallet size={19} />

              <span>
                Transactions
              </span>

            </NavLink>


            {/* TRACEABILITY */}

            <NavLink
              to="/traceability"
              className={({ isActive }) =>
                `nav-item ${
                  isActive
                    ? "active"
                    : ""
                }`
              }
            >

              <FileCheck2 size={19} />

              <span>
                Traceability
              </span>

            </NavLink>


            {/* RATE BOARD */}

            <NavLink
              to="/rate-board"
              className={({ isActive }) =>
                `nav-item ${
                  isActive
                    ? "active"
                    : ""
                }`
              }
            >

              <BarChart3 size={19} />

              <span>
                Rate Board
              </span>

            </NavLink>

          </nav>

        </div>


        {/* ===================================================
            ACCOUNT
            =================================================== */}

        <div className="sidebar-section">

          <p className="sidebar-label">
            ACCOUNT
          </p>


          <nav className="nav-list">


            {/* VERIFICATION */}

            <NavLink
              to={
                handoverLot
                  ? `/verification/${handoverLot.id}`
                  : "/verification"
              }
              className={() =>
                `nav-item ${
                  isVerification
                    ? "active"
                    : ""
                }`
              }
            >

              <ShieldCheck size={19} />

              <span>
                Verification
              </span>

            </NavLink>


            {/* SETTINGS */}

            <button
              type="button"
              className="nav-item"
              onClick={() => {
                alert(
                  "Settings module is coming next."
                );
              }}
            >

              <Settings size={19} />

              <span>
                Settings
              </span>

            </button>

          </nav>

        </div>


        {/* ===================================================
            SIDEBAR BOTTOM
            =================================================== */}

        <div className="sidebar-bottom">

          <div className="verified-card">

            <div className="verified-icon">

              <ShieldCheck size={18} />

            </div>


            <div>

              <strong>
                Verified Recycler
              </strong>

              <span>
                Authorization active
              </span>

            </div>

          </div>

        </div>

      </aside>


      {/* =====================================================
          MAIN CONTENT
          ===================================================== */}

      <main className="main-content">


        {/* ===================================================
            TOP BAR
            =================================================== */}

        <header className="topbar">

          <div>

            <p className="breadcrumb">

              Recycler Portal /{" "}

              {getBreadcrumb()}

            </p>


            <h2>
              {getPageTitle()}
            </h2>

          </div>


          <div className="topbar-actions">


            {/* NOTIFICATIONS */}

            <button
              type="button"
              className="icon-button"
              aria-label="Notifications"
            >

              <Bell size={20} />

              <span className="notification-dot" />

            </button>


            {/* PROFILE */}

            <div className="profile">

              <div className="avatar">
                EC
              </div>


              <div className="profile-info">

                <strong>
                  EcoCycle Recycler
                </strong>

                <span>
                  Mumbai Facility
                </span>

              </div>


              <ChevronDown size={17} />

            </div>

          </div>

        </header>


        {/* ===================================================
            PAGE CONTENT
            =================================================== */}

        <Suspense fallback={<PageLoading />}>

          {isLotDetails ? (

            <LotDetails />

          ) : isVerification ? (

            <HandoverVerification />

          ) : isIncomingLots ? (

            <IncomingLots />

          ) : isTransactions ? (

            <Transactions />

          ) : isTraceability ? (

            <Traceability />

          ) : isRateBoard ? (

            <RateBoard />

          ) : isDashboard ? (

            <Dashboard
              lots={lots}
            />

          ) : (

            <Dashboard
              lots={lots}
            />

          )}

        </Suspense>

      </main>

    </div>
  );
}


export default App;