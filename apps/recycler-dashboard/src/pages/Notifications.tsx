import { useEffect, useMemo, useState } from "react";
import {
  Bell,
  CheckCircle2,
  Clock3,
  Package,
  RefreshCw,
  XCircle,
} from "lucide-react";
import { useNavigate } from "react-router-dom";
import type { Lot } from "../data/mockLots";
import {
  getStoredLots,
  refreshLotsFromBackend,
} from "../data/lotsStore";

type Notice = {
  id: string;
  title: string;
  body: string;
  tone: "pending" | "success" | "danger" | "info";
  lotId?: string;
  createdAt: string;
};

function buildNotices(lots: Lot[]): Notice[] {
  return lots
    .slice()
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    .slice(0, 20)
    .map((lot) => {
      if (lot.status === "Pending") {
        return {
          id: `n-${lot.id}-pending`,
          title: `New lot ${lot.id}`,
          body: `${lot.collector} sent ${lot.weight} kg of ${lot.material} for review.`,
          tone: "pending" as const,
          lotId: lot.id,
          createdAt: lot.createdAt,
        };
      }
      if (lot.status === "Accepted") {
        return {
          id: `n-${lot.id}-accepted`,
          title: `Lot ${lot.id} accepted`,
          body: "Ready for physical handover verification.",
          tone: "info" as const,
          lotId: lot.id,
          createdAt: lot.createdAt,
        };
      }
      if (lot.status === "Handover") {
        return {
          id: `n-${lot.id}-handover`,
          title: `Handover in progress`,
          body: `${lot.id} is waiting at verification.`,
          tone: "info" as const,
          lotId: lot.id,
          createdAt: lot.createdAt,
        };
      }
      if (lot.status === "Rejected") {
        return {
          id: `n-${lot.id}-rejected`,
          title: `Lot ${lot.id} rejected`,
          body: "Collector was notified of the rejection.",
          tone: "danger" as const,
          lotId: lot.id,
          createdAt: lot.createdAt,
        };
      }
      return {
        id: `n-${lot.id}-done`,
        title: `Lot ${lot.id} completed`,
        body: "Settlement recorded for this handover.",
        tone: "success" as const,
        lotId: lot.id,
        createdAt: lot.createdAt,
      };
    });
}

export default function Notifications() {
  const navigate = useNavigate();
  const [lots, setLots] = useState<Lot[]>(getStoredLots);
  const [loading, setLoading] = useState(false);

  const notices = useMemo(() => buildNotices(lots), [lots]);

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

  const iconFor = (tone: Notice["tone"]) => {
    if (tone === "success") return <CheckCircle2 size={18} />;
    if (tone === "danger") return <XCircle size={18} />;
    if (tone === "pending") return <Clock3 size={18} />;
    return <Package size={18} />;
  };

  return (
    <section className="page-content notifications-page">
      <div className="page-toolbar">
        <div>
          <h3>Notifications</h3>
          <p>Lot workflow updates from collectors and your team actions.</p>
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

      {notices.length === 0 ? (
        <div className="empty-state">
          <Bell size={42} />
          <strong>No notifications yet</strong>
          <p>When collectors sync lots, updates will appear here.</p>
        </div>
      ) : (
        <div className="notice-list">
          {notices.map((notice) => (
            <button
              key={notice.id}
              type="button"
              className={`notice-card tone-${notice.tone}`}
              onClick={() => {
                if (notice.lotId) {
                  navigate(`/incoming-lots/${notice.lotId}`);
                }
              }}
            >
              <div className="notice-icon">{iconFor(notice.tone)}</div>
              <div className="notice-body">
                <strong>{notice.title}</strong>
                <span>{notice.body}</span>
                <em>{notice.createdAt}</em>
              </div>
            </button>
          ))}
        </div>
      )}
    </section>
  );
}
