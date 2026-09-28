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

import { useEffect, useState } from "react";

import "./App.css";

import IncomingLots from "./pages/IncomingLots";
import LotDetails from "./pages/LotDetails";
import HandoverVerification from "./pages/HandoverVerification";
import Transactions from "./pages/Transactions";

import {
  getStoredLots,
} from "./data/lotsStore";


/* =========================================================
   DASHBOARD STATS
   ========================================================= */

const stats = [
  {
    label: "Total Lots",
    value: "128",
    change: "+12 this month",
    icon: PackageCheck,
  },
  {
    label: "Pending Requests",
    value: "14",
    change: "5 require action",
    icon: Clock3,
  },
  {
    label: "Completed",
    value: "96",
    change: "+18% this month",
    icon: ClipboardCheck,
  },
  {
    label: "Total Payments",
    value: "₹2.84L",
    change: "+₹42,500 this month",
    icon: CircleDollarSign,
  },
];


function App() {
  const location = useLocation();

  const [lots, setLots] = useState(
    getStoredLots
  );


  /* =========================================================
     ROUTE DETECTION
     ========================================================= */

  const isIncomingLots =
    location.pathname === "/incoming-lots";

  const isTransactions =
    location.pathname === "/transactions";

  const isLotDetails =
    location.pathname.startsWith(
      "/incoming-lots/"
    );

  const isVerification =
    location.pathname.startsWith(
      "/verification/"
    );


  /* =========================================================
     SYNC LOT DATA
     ========================================================= */

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


  /* =========================================================
     DASHBOARD RECENT LOTS
     ========================================================= */

  const recentLots = lots.slice(0, 4);


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
            <h1>Kabadiwala</h1>
            <span>CONNECT</span>
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
                  isActive ? "active" : ""
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
                  isActive || isLotDetails
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
                      lot.status === "Pending"
                  ).length
                }
              </span>

            </NavLink>


            {/* TRANSACTIONS */}

            <NavLink
              to="/transactions"
              className={({ isActive }) =>
                `nav-item ${
                  isActive ? "active" : ""
                }`
              }
            >
              <Wallet size={19} />

              <span>
                Transactions
              </span>

            </NavLink>


            {/* TRACEABILITY */}

            <button
              type="button"
              className="nav-item"
            >
              <FileCheck2 size={19} />

              <span>
                Traceability
              </span>
            </button>


            {/* RATE BOARD */}

            <button
              type="button"
              className="nav-item"
            >
              <BarChart3 size={19} />

              <span>
                Rate Board
              </span>
            </button>

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
                lots.some(
                  (lot) =>
                    lot.status === "Handover"
                )
                  ? `/verification/${
                      lots.find(
                        (lot) =>
                          lot.status ===
                          "Handover"
                      )?.id
                    }`
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

              {isVerification
                ? "Operations / Handover Verification"
                : isLotDetails
                ? "Operations / Lot Details"
                : isIncomingLots
                ? "Operations"
                : isTransactions
                ? "Finance"
                : "Overview"}

            </p>


            <h2>

              {isVerification
                ? "Handover Verification"
                : isLotDetails
                ? "Lot Details"
                : isIncomingLots
                ? "Incoming Lots"
                : isTransactions
                ? "Transactions"
                : "Dashboard"}

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
            ROUTE CONTENT
            =================================================== */}

        {isVerification ? (

          <HandoverVerification />

        ) : isLotDetails ? (

          <LotDetails />

        ) : isIncomingLots ? (

          <IncomingLots />

        ) : isTransactions ? (

          <Transactions />

        ) : (

          /* =================================================
             DASHBOARD
             ================================================= */

          <section className="dashboard-content">


            {/* WELCOME */}

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

              {stats.map((stat) => {

                const Icon = stat.icon;

                return (

                  <div
                    className="stat-card"
                    key={stat.label}
                  >

                    <div className="stat-top">

                      <div className="stat-icon">
                        <Icon size={20} />
                      </div>

                    </div>

                    <p>
                      {stat.label}
                    </p>

                    <h4>
                      {stat.value}
                    </h4>

                    <span className="stat-change">
                      {stat.change}
                    </span>

                  </div>

                );

              })}

            </div>


            {/* =================================================
                RECENT LOTS
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


            {/* RECENT LOTS TABLE */}

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

                  {recentLots.map(
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
                          {lot.weight.toFixed(1)} kg
                        </td>


                        <td>

                          {lot.estimatedValue ===
                          null
                            ? "—"
                            : `₹${lot.estimatedValue.toLocaleString(
                                "en-IN",
                                {
                                  maximumFractionDigits: 0,
                                }
                              )}`}

                        </td>


                        <td>

                          <span
                            className={`status-pill ${lot.status
                              .toLowerCase()
                              .replace(
                                " ",
                                "-"
                              )}`}
                          >
                            {lot.status}
                          </span>

                        </td>

                      </tr>

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
                      18 / 25
                    </strong>

                  </div>


                  <div className="progress-track">

                    <div
                      className="progress-fill"
                      style={{
                        width: "72%",
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
                      12 / 18
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
                    {
                      lots.filter(
                        (lot) =>
                          lot.criticalMineral
                      ).length
                    }
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

        )}

      </main>

    </div>
  );
}

export default App;