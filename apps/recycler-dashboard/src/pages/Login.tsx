import { FormEvent, useState } from "react";
import { Recycle } from "lucide-react";
import { loginWithPassword } from "../lib/api";

type LoginProps = {
  onSuccess: () => void;
};

export default function Login({ onSuccess }: LoginProps) {
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setError("");
    setLoading(true);

    try {
      const result = await loginWithPassword(
        identifier.trim(),
        password
      );

      if (!result.success) {
        setError(result.message || "Login failed");
        return;
      }

      onSuccess();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Unable to reach the backend"
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        background:
          "linear-gradient(160deg, #e8f5ef 0%, #f7faf8 45%, #eef6f2 100%)",
        padding: "24px",
      }}
    >
      <form
        onSubmit={handleSubmit}
        style={{
          width: "100%",
          maxWidth: 420,
          background: "#fff",
          border: "1px solid #d7e5dd",
          borderRadius: 16,
          padding: "32px 28px",
          boxShadow: "0 12px 40px rgba(20, 60, 40, 0.08)",
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 12,
            marginBottom: 20,
          }}
        >
          <div
            style={{
              width: 44,
              height: 44,
              borderRadius: 12,
              background: "#0f6b4c",
              display: "grid",
              placeItems: "center",
              color: "#fff",
            }}
          >
            <Recycle size={22} />
          </div>
          <div>
            <h1
              style={{
                margin: 0,
                fontSize: 22,
                color: "#123528",
              }}
            >
              Kabadiwala Connect
            </h1>
            <p
              style={{
                margin: "4px 0 0",
                color: "#52756a",
                fontSize: 14,
              }}
            >
              Recycler dashboard sign-in
            </p>
          </div>
        </div>

        <label
          style={{
            display: "block",
            fontSize: 13,
            color: "#35584b",
            marginBottom: 6,
          }}
        >
          Phone or email
        </label>
        <input
          value={identifier}
          onChange={(e) => setIdentifier(e.target.value)}
          placeholder="9876543210 or you@facility.com"
          required
          style={{
            width: "100%",
            marginBottom: 14,
            padding: "12px 14px",
            borderRadius: 10,
            border: "1px solid #c9ddd2",
            fontSize: 15,
          }}
        />

        <label
          style={{
            display: "block",
            fontSize: 13,
            color: "#35584b",
            marginBottom: 6,
          }}
        >
          Password
        </label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="At least 8 characters"
          required
          minLength={8}
          style={{
            width: "100%",
            marginBottom: 18,
            padding: "12px 14px",
            borderRadius: 10,
            border: "1px solid #c9ddd2",
            fontSize: 15,
          }}
        />

        {error ? (
          <p
            style={{
              color: "#b42318",
              background: "#fff1f0",
              border: "1px solid #f3c1bc",
              borderRadius: 8,
              padding: "10px 12px",
              fontSize: 13,
              marginBottom: 14,
            }}
          >
            {error}
          </p>
        ) : null}

        <button
          type="submit"
          disabled={loading}
          style={{
            width: "100%",
            padding: "12px 16px",
            border: "none",
            borderRadius: 10,
            background: loading ? "#6f9f8a" : "#0f6b4c",
            color: "#fff",
            fontWeight: 600,
            fontSize: 15,
            cursor: loading ? "wait" : "pointer",
          }}
        >
          {loading ? "Signing in…" : "Sign in"}
        </button>

        <p
          style={{
            marginTop: 16,
            fontSize: 12,
            color: "#6b857a",
            lineHeight: 1.5,
          }}
        >
          Use a recycler account registered via{" "}
          <code>POST /api/auth/recyclers/register</code>. Collector
          lots appear under Incoming Lots after sync.
        </p>
      </form>
    </div>
  );
}
