import { useState } from "react";
import Login from "./Login";
import Signup from "./Signup";

type AuthGateProps = {
  onSuccess: () => void;
};

export default function AuthGate({ onSuccess }: AuthGateProps) {
  const [mode, setMode] = useState<"login" | "signup">("login");

  if (mode === "signup") {
    return (
      <Signup
        onSuccess={onSuccess}
        onSwitchToLogin={() => setMode("login")}
      />
    );
  }

  return (
    <Login
      onSuccess={onSuccess}
      onSwitchToSignup={() => setMode("signup")}
    />
  );
}
