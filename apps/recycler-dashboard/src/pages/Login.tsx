import { FormEvent, useState } from "react";
import { Building2, Lock, Phone, Recycle } from "lucide-react";
import { loginWithPassword } from "../lib/api";

type LoginProps = {
  onSuccess: () => void;
  onSwitchToSignup: () => void;
};

export default function Login({ onSuccess, onSwitchToSignup }: LoginProps) {
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setError("");
    setLoading(true);

    try {
      const result = await loginWithPassword(identifier.trim(), password);

      if (!result.success) {
        setError(result.message || "Login failed");
        return;
      }

      onSuccess();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Unable to reach the backend"
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-shell">
      <div className="auth-hero">
        <div className="auth-hero-badge">
          <Recycle size={28} />
        </div>
        <h1>Formal recycling, quietly run.</h1>
        <p>
          One portal for incoming lots, QR handover, settlement, and rate
          intelligence — built for authorised recyclers.
        </p>
        <ul className="auth-hero-list">
          <li>Review collector lots in real time</li>
          <li>Accept, reject, and complete handovers</li>
          <li>Track settlements and rate board updates</li>
        </ul>
      </div>

      <form className="auth-card" onSubmit={handleSubmit}>
        <div className="auth-tabs">
          <button type="button" className="auth-tab active">
            Sign in
          </button>
          <button
            type="button"
            className="auth-tab"
            onClick={onSwitchToSignup}
          >
            Sign up
          </button>
        </div>

        <h2>Welcome back</h2>
        <p className="auth-subtitle">
          Sign in with your recycler organisation account.
        </p>

        <label className="auth-label">
          <Phone size={15} />
          Phone or email
        </label>
        <input
          className="auth-input"
          value={identifier}
          onChange={(e) => setIdentifier(e.target.value)}
          placeholder="9876543210 or you@facility.com"
          required
          autoComplete="username"
        />

        <label className="auth-label">
          <Lock size={15} />
          Password
        </label>
        <input
          className="auth-input"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="At least 8 characters"
          required
          minLength={8}
          autoComplete="current-password"
        />

        {error ? <p className="auth-error">{error}</p> : null}

        <button className="auth-submit" type="submit" disabled={loading}>
          {loading ? "Signing in…" : "Sign in to dashboard"}
        </button>

        <p className="auth-footer">
          New facility?{" "}
          <button type="button" className="auth-link" onClick={onSwitchToSignup}>
            Create a recycler account
          </button>
        </p>

        <div className="auth-note">
          <Building2 size={16} />
          <span>
            Use the same backend account your facility registered with. Collector
            lots appear under Incoming Lots after sync.
          </span>
        </div>
      </form>
    </div>
  );
}
