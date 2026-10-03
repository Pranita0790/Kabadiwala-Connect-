import { FormEvent, useState } from "react";
import {
  BatteryCharging,
  Building2,
  Cpu,
  Laptop,
  Leaf,
  Lock,
  Mail,
  MapPin,
  Phone,
  Recycle,
  Smartphone,
  Sparkles,
  User,
  Zap,
} from "lucide-react";
import { loginWithPassword, registerRecyclerAccount } from "../lib/api";

type SignupProps = {
  onSuccess: () => void;
  onSwitchToLogin: () => void;
};

export default function Signup({ onSuccess, onSwitchToLogin }: SignupProps) {
  const [fullName, setFullName] = useState("");
  const [organisationName, setOrganisationName] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [address, setAddress] = useState("");
  const [city, setCity] = useState("");
  const [region, setRegion] = useState("IN-MH");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setError("");

    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }

    if (password !== confirmPassword) {
      setError("Passwords do not match.");
      return;
    }

    setLoading(true);

    try {
      const registered = await registerRecyclerAccount({
        fullName: fullName.trim(),
        organisationName: organisationName.trim(),
        phone: phone.trim(),
        email: email.trim() || undefined,
        address: address.trim() || undefined,
        city: city.trim() || undefined,
        region: region.trim() || undefined,
        password,
      });

      if (!registered.success) {
        setError(registered.message || "Registration failed");
        return;
      }

      const session = await loginWithPassword(phone.trim(), password);
      if (!session.success) {
        setError(
          session.message ||
            "Account created, but automatic sign-in failed. Please sign in."
        );
        onSwitchToLogin();
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
        {/* Floating 3D Clay Objects & Capsules */}
        <div className="clay-floating-pill clay-float-phone" aria-hidden="true">
          <Smartphone size={16} />
          <span>Old phone</span>
        </div>
        <div className="clay-floating-pill clay-float-battery" aria-hidden="true">
          <BatteryCharging size={16} />
          <span>Battery</span>
        </div>
        <div className="clay-floating-pill clay-float-laptop" aria-hidden="true">
          <Laptop size={16} />
          <span>Laptop</span>
        </div>
        <div className="clay-floating-pill clay-float-circuit" aria-hidden="true">
          <Cpu size={16} />
          <span>Circuit board</span>
        </div>
        <div className="clay-floating-pill clay-float-charger" aria-hidden="true">
          <Zap size={16} />
          <span>Charger</span>
        </div>

        <div className="auth-hero-badge">
          <Recycle size={32} />
        </div>
        <h1>
          Join the formal <br />
          <em>circular network.</em>
        </h1>
        <p>
          Register your facility once. Collectors find you. Lots, handover,
          and settlement stay in one quiet workspace.
        </p>
        <ul className="auth-hero-list">
          <li>Organisation profile for matching</li>
          <li>Incoming lot workflow</li>
          <li>Traceability and settlement visibility</li>
        </ul>
      </div>

      <form className="auth-card auth-card-wide" onSubmit={handleSubmit}>
        <div className="auth-tabs">
          <button
            type="button"
            className="auth-tab"
            onClick={onSwitchToLogin}
          >
            Sign in
          </button>
          <button type="button" className="auth-tab active">
            Sign up
          </button>
        </div>

        <h2>Create recycler account</h2>
        <p className="auth-subtitle">
          All fields marked required are needed for facility onboarding.
        </p>

        <div className="auth-grid">
          <div>
            <label className="auth-label">
              <User size={15} />
              Contact person *
            </label>
            <input
              className="auth-input"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              placeholder="Ramesh Patil"
              required
              minLength={2}
            />
          </div>

          <div>
            <label className="auth-label">
              <Building2 size={15} />
              Organisation name *
            </label>
            <input
              className="auth-input"
              value={organisationName}
              onChange={(e) => setOrganisationName(e.target.value)}
              placeholder="EcoCycle Maharashtra"
              required
              minLength={2}
            />
          </div>

          <div>
            <label className="auth-label">
              <Phone size={15} />
              Mobile number *
            </label>
            <input
              className="auth-input"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="9876543210"
              required
            />
          </div>

          <div>
            <label className="auth-label">
              <Mail size={15} />
              Work email
            </label>
            <input
              className="auth-input"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="ops@facility.com"
            />
          </div>

          <div className="auth-span-2">
            <label className="auth-label">
              <MapPin size={15} />
              Facility address
            </label>
            <input
              className="auth-input"
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              placeholder="Plot 12, MIDC Industrial Area"
            />
          </div>

          <div>
            <label className="auth-label">City</label>
            <input
              className="auth-input"
              value={city}
              onChange={(e) => setCity(e.target.value)}
              placeholder="Nagpur"
            />
          </div>

          <div>
            <label className="auth-label">Region</label>
            <input
              className="auth-input"
              value={region}
              onChange={(e) => setRegion(e.target.value)}
              placeholder="IN-MH"
            />
          </div>

          <div>
            <label className="auth-label">
              <Lock size={15} />
              Password *
            </label>
            <input
              className="auth-input"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Min 8 characters"
              required
              minLength={8}
              autoComplete="new-password"
            />
          </div>

          <div>
            <label className="auth-label">
              <Lock size={15} />
              Confirm password *
            </label>
            <input
              className="auth-input"
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              placeholder="Repeat password"
              required
              minLength={8}
              autoComplete="new-password"
            />
          </div>
        </div>

        {error ? <p className="auth-error">{error}</p> : null}

        <button className="auth-submit" type="submit" disabled={loading}>
          {loading ? "Creating account…" : "Create account & continue"}
        </button>

        <p className="auth-footer">
          Already registered?{" "}
          <button type="button" className="auth-link" onClick={onSwitchToLogin}>
            Sign in
          </button>
        </p>
      </form>
    </div>
  );
}
