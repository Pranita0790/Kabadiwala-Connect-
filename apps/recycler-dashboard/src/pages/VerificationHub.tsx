import { useEffect, useMemo, useState } from "react";
import {
  ArrowRight,
  ClipboardCheck,
  Package,
  RefreshCw,
  ShieldCheck,
} from "lucide-react";
import { useNavigate } from "react-router-dom";
import type { Lot } from "../data/mockLots";
import {
  getStoredLots,
  refreshLotsFromBackend,
} from "../data/lotsStore";

export default function VerificationHub() {
  const navigate = useNavigate();
  const [lots, setLots] = useState<Lot[]>(getStoredLots);
  const [loading, setLoading] = useState(false);

  const queue = useMemo(
    () =>
      lots.filter(
        (lot) => lot.status === "Handover" || lot.status === "Accepted"
      ),
    [lots]
  );

  const refresh = async () => {
    setLoading(true);
    const next = await refreshLotsFromBackend();
    setLots(next);
    setLoading(false);
  };

  useEffect(() => {
    void refresh();
    const onUpdate = () => setLots(getStoredLots());
    window.addEventListener("kabadiwala-lots-updated", onUpdate);
    return () => window.removeEventListener("kabadiwala-lots-updated", onUpdate);
  }, []);

  return (
    <section className="page-content verification-hub">
      <div className="page-toolbar">
        <div>
          <p>
            Confirm physical delivery for accepted lots. Ask the collector for
            the 6-digit PIN from the app, then complete verification to move a
            lot to Completed and create settlement records.
          </p>
        </div>
        <button
          type="button"
          className="secondary-button"
          onClick={() => void refresh()}
          disabled={loading}
        >
          <RefreshCw size={16} />
          {loading ? "Refreshing…" : "Refresh"}
        </button>
      </div>

      <div className="stats-grid" style={{ marginBottom: 18 }}>
        <div className="stat-card">
          <div className="stat-top">
            <div className="stat-icon">
              <ClipboardCheck size={20} />
            </div>
          </div>
          <p>Ready for verification</p>
          <h4>{queue.length}</h4>
          <span className="stat-change">Accepted or handover status</span>
        </div>
      </div>

      {queue.length === 0 ? (
        <div className="empty-state">
          <ShieldCheck size={42} />
          <strong>No lots waiting for verification</strong>
          <p>
            Accept an incoming lot first, then start handover to see it here.
          </p>
          <button
            type="button"
            className="primary-button"
            onClick={() => navigate("/incoming-lots")}
          >
            Go to Incoming Lots
          </button>
        </div>
      ) : (
        <div className="verification-list">
          {queue.map((lot) => (
            <div key={lot.id} className="verification-card">
              <div className="verification-card-main">
                <div className="verification-card-icon">
                  <Package size={20} />
                </div>
                <div>
                  <strong>{lot.id}</strong>
                  <p>
                    {lot.material} · {lot.weight} kg · {lot.collector}
                  </p>
                  <span className={`status-badge status-${lot.status.toLowerCase()}`}>
                    {lot.status}
                  </span>
                </div>
              </div>
              <button
                type="button"
                className="primary-button"
                onClick={() => navigate(`/verification/${lot.id}`)}
              >
                Open verification
                <ArrowRight size={16} />
              </button>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}
