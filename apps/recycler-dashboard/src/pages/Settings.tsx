import { useEffect, useState } from "react";
import {
  Building2,
  Globe2,
  LogOut,
  Mail,
  Phone,
  RefreshCw,
  ShieldCheck,
  User,
} from "lucide-react";
import {
  clearSession,
  fetchBackendHealth,
  getApiBase,
  getStoredUser,
} from "../lib/api";

type SettingsProps = {
  onSignedOut: () => void;
};

export default function Settings({ onSignedOut }: SettingsProps) {
  const user = getStoredUser();
  const [health, setHealth] = useState("Checking…");
  const [checking, setChecking] = useState(false);

  const checkHealth = async () => {
    setChecking(true);
    const result = await fetchBackendHealth();
    setHealth(result.message);
    setChecking(false);
  };

  useEffect(() => {
    void checkHealth();
  }, []);

  return (
    <section className="page-content settings-page">
      <div className="settings-grid">
        <div className="settings-card">
          <div className="settings-card-header">
            <User size={18} />
            <h3>Account</h3>
          </div>
          <div className="settings-row">
            <span>Name</span>
            <strong>{user?.fullName || "—"}</strong>
          </div>
          <div className="settings-row">
            <span>Role</span>
            <strong>{user?.role || "RECYCLER"}</strong>
          </div>
          <div className="settings-row">
            <span>
              <Phone size={14} /> Phone
            </span>
            <strong>{user?.phone || "—"}</strong>
          </div>
          <div className="settings-row">
            <span>
              <Mail size={14} /> Email
            </span>
            <strong>{user?.email || "Not set"}</strong>
          </div>
        </div>

        <div className="settings-card">
          <div className="settings-card-header">
            <Building2 size={18} />
            <h3>Facility</h3>
          </div>
          <div className="settings-row">
            <span>Organisation</span>
            <strong>{user?.organisationName || "—"}</strong>
          </div>
          <div className="settings-row">
            <span>Recycler profile id</span>
            <strong className="mono">{user?.recyclerId || "—"}</strong>
          </div>
          <div className="settings-row">
            <span>
              <ShieldCheck size={14} /> Authorisation
            </span>
            <strong>
              {user?.recyclerId
                ? "Profile linked — admin may still need to authorise"
                : "Missing recycler profile"}
            </strong>
          </div>
        </div>

        <div className="settings-card">
          <div className="settings-card-header">
            <Globe2 size={18} />
            <h3>Backend connection</h3>
          </div>
          <div className="settings-row">
            <span>API base</span>
            <strong className="mono">{getApiBase()}</strong>
          </div>
          <div className="settings-row">
            <span>Health</span>
            <strong>{health}</strong>
          </div>
          <button
            type="button"
            className="secondary-button"
            onClick={() => void checkHealth()}
            disabled={checking}
          >
            <RefreshCw size={16} />
            {checking ? "Checking…" : "Recheck connection"}
          </button>
        </div>

        <div className="settings-card">
          <div className="settings-card-header">
            <LogOut size={18} />
            <h3>Session</h3>
          </div>
          <p className="settings-help">
            Sign out clears the JWT from this browser. Unsaved local lot cache
            stays until the next successful sync.
          </p>
          <button
            type="button"
            className="danger-button"
            onClick={() => {
              clearSession();
              onSignedOut();
            }}
          >
            <LogOut size={16} />
            Sign out
          </button>
        </div>
      </div>
    </section>
  );
}
