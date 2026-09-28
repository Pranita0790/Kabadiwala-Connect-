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
import "./App.css";

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

const recentLots = [
  {
    id: "KC-2026-0148",
    material: "PCB",
    collector: "Ramesh Kumar",
    weight: "12.5 kg",
    value: "₹5,604",
    status: "Pending",
  },
  {
    id: "KC-2026-0147",
    material: "Battery",
    collector: "Suresh Patil",
    weight: "8.0 kg",
    value: "₹800",
    status: "Accepted",
  },
  {
    id: "KC-2026-0146",
    material: "Cable",
    collector: "Amit Shah",
    weight: "15.2 kg",
    value: "₹6,030",
    status: "Handover",
  },
  {
    id: "KC-2026-0145",
    material: "LCD Panel",
    collector: "Vijay More",
    weight: "10.0 kg",
    value: "—",
    status: "Pending",
  },
];

function App() {
  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-icon">
            <Recycle size={24} />
          </div>

          <div>
            <h1>Kabadiwala</h1>
            <span>CONNECT</span>
          </div>
        </div>

        <div className="sidebar-section">
          <p className="sidebar-label">MAIN MENU</p>

          <nav className="nav-list">
            <button className="nav-item active">
              <LayoutDashboard size={19} />
              <span>Dashboard</span>
            </button>

            <button className="nav-item">
              <Truck size={19} />
              <span>Incoming Lots</span>
              <span className="nav-badge">14</span>
            </button>

            <button className="nav-item">
              <Wallet size={19} />
              <span>Transactions</span>
            </button>

            <button className="nav-item">
              <FileCheck2 size={19} />
              <span>Traceability</span>
            </button>

            <button className="nav-item">
              <BarChart3 size={19} />
              <span>Rate Board</span>
            </button>
          </nav>
        </div>

        <div className="sidebar-section">
          <p className="sidebar-label">ACCOUNT</p>

          <nav className="nav-list">
            <button className="nav-item">
              <ShieldCheck size={19} />
              <span>Verification</span>
            </button>

            <button className="nav-item">
              <Settings size={19} />
              <span>Settings</span>
            </button>
          </nav>
        </div>

        <div className="sidebar-bottom">
          <div className="verified-card">
            <div className="verified-icon">
              <ShieldCheck size={18} />
            </div>

            <div>
              <strong>Verified Recycler</strong>
              <span>Authorization active</span>
            </div>
          </div>
        </div>
      </aside>

      <main className="main-content">
        <header className="topbar">
          <div>
            <p className="breadcrumb">Recycler Portal / Overview</p>
            <h2>Dashboard</h2>
          </div>

          <div className="topbar-actions">
            <button className="icon-button">
              <Bell size={20} />
              <span className="notification-dot" />
            </button>

            <div className="profile">
              <div className="avatar">EC</div>

              <div className="profile-info">
                <strong>EcoCycle Recycler</strong>
                <span>Mumbai Facility</span>
              </div>

              <ChevronDown size={17} />
            </div>
          </div>
        </header>

        <section className="dashboard-content">
          <div className="welcome-row">
            <div>
              <h3>Good morning, EcoCycle 👋</h3>
              <p>
                Here's what's happening with your recycling operations today.
              </p>
            </div>

            <div className="location-chip">
              <MapPin size={16} />
              Mumbai
            </div>
          </div>

          <div className="stats-grid">
            {stats.map((stat) => {
              const Icon = stat.icon;

              return (
                <div className="stat-card" key={stat.label}>
                  <div className="stat-top">
                    <div className="stat-icon">
                      <Icon size={20} />
                    </div>
                  </div>

                  <p>{stat.label}</p>
                  <h4>{stat.value}</h4>
                  <span className="stat-change">{stat.change}</span>
                </div>
              );
            })}
          </div>

          <div className="section-header">
            <div>
              <h3>Recent Incoming Lots</h3>
              <p>Latest collection requests from registered collectors.</p>
            </div>

            <button className="text-button">
              View all lots →
            </button>
          </div>

          <div className="table-card">
            <table>
              <thead>
                <tr>
                  <th>LOT ID</th>
                  <th>MATERIAL</th>
                  <th>COLLECTOR</th>
                  <th>WEIGHT</th>
                  <th>EST. VALUE</th>
                  <th>STATUS</th>
                </tr>
              </thead>

              <tbody>
                {recentLots.map((lot) => (
                  <tr key={lot.id}>
                    <td>
                      <strong>{lot.id}</strong>
                    </td>

                    <td>
                      <span className="material-pill">{lot.material}</span>
                    </td>

                    <td>{lot.collector}</td>

                    <td>{lot.weight}</td>

                    <td>{lot.value}</td>

                    <td>
                      <span
                        className={`status-pill ${lot.status
                          .toLowerCase()
                          .replace(" ", "-")}`}
                      >
                        {lot.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="bottom-grid">
            <div className="info-card">
              <div className="info-card-header">
                <div>
                  <h3>Today's Operations</h3>
                  <p>Current processing activity</p>
                </div>

                <PackageCheck size={22} />
              </div>

              <div className="progress-row">
                <div>
                  <span>Lots received</span>
                  <strong>18 / 25</strong>
                </div>

                <div className="progress-track">
                  <div className="progress-fill" style={{ width: "72%" }} />
                </div>
              </div>

              <div className="progress-row">
                <div>
                  <span>Handovers completed</span>
                  <strong>12 / 18</strong>
                </div>

                <div className="progress-track">
                  <div className="progress-fill" style={{ width: "67%" }} />
                </div>
              </div>
            </div>

            <div className="info-card critical-card">
              <div className="critical-header">
                <div className="critical-icon">
                  <ShieldCheck size={21} />
                </div>

                <div>
                  <h3>Material Intelligence</h3>
                  <p>AI-assisted screening</p>
                </div>
              </div>

              <div className="critical-stat">
                <strong>7</strong>
                <span>potential critical-mineral-associated lots</span>
              </div>

              <p className="critical-note">
                Review flagged lots before processing and maintain the
                traceability record.
              </p>
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}

export default App;