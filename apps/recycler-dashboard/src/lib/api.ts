const API_BASE =
  import.meta.env.VITE_API_BASE_URL ??
  `http://${typeof window !== "undefined" && window.location.hostname ? window.location.hostname : "localhost"}:5001/api`;

export async function runAiRecyclerAudit(lotData: {
  id?: string;
  material?: string;
  weight_kg?: number;
}) {
  const result = await apiFetch<{
    success: boolean;
    data: {
      lot_id: string;
      purity_grade: string;
      purity_percentage: number;
      critical_minerals_recovery: Array<{
        mineral: string;
        estimated_recovery_grams: number;
        market_grade: string;
      }>;
      epr_compliance: {
        status: string;
        epr_certificate_eligible: boolean;
        estimated_credits: number;
        co2_avoided_kg: number;
        circular_economy_score: number;
      };
      handling_safety_audit: string[];
    };
  }>("/ai/recycler-audit", {
    method: "POST",
    body: JSON.stringify(lotData),
  });

  return result.data?.data;
}

export async function runAiCopilot(payload: {
  message?: string;
  language?: string;
  imageBase64?: string | null;
  mimetype?: string;
  context?: Record<string, unknown>;
}) {
  const result = await apiFetch<{
    success: boolean;
    data: {
      reply: string;
      detected_material?: string;
      category_name?: string;
      estimated_weight_kg?: number;
      suggested_rate_per_kg?: number;
      total_estimated_value_inr?: number;
      best_paying_recycler?: {
        name: string;
        rate_per_kg: number;
        distance_km: number;
        address: string;
        reason: string;
      };
      suggested_actions?: string[];
      can_create_lot?: boolean;
    };
  }>("/ai/copilot", {
    method: "POST",
    body: JSON.stringify(payload),
  });

  return result.data?.data;
}

export async function fetchRatesIndex() {
  const result = await apiFetch<{
    success: boolean;
    data: {
      rates: Record<string, { min: number; max: number; avg: number }>;
      critical_minerals: Record<
        string,
        {
          minerals: string[];
          epr_credits_per_kg: number;
          co2_offset_kg_per_kg: number;
        }
      >;
      timestamp: string;
    };
  }>("/ai/rates-index");

  return result.data?.data;
}

const TOKEN_KEY = "kabadiwala-access-token";
const REFRESH_KEY = "kabadiwala-refresh-token";
const USER_KEY = "kabadiwala-auth-user";

let refreshInFlight: Promise<boolean> | null = null;

export type AuthUser = {
  id: string;
  fullName: string;
  phone: string | null;
  email: string | null;
  role: string;
  recyclerId: string | null;
  organisationName: string | null;
};

export function getApiBase(): string {
  return API_BASE;
}

export function getAccessToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function getStoredUser(): AuthUser | null {
  try {
    const raw = localStorage.getItem(USER_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as AuthUser;
  } catch {
    return null;
  }
}

export function clearSession(): void {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_KEY);
  localStorage.removeItem(USER_KEY);
}

export function saveSession(payload: {
  accessToken: string;
  refreshToken?: string;
  user: AuthUser;
}): void {
  localStorage.setItem(TOKEN_KEY, payload.accessToken);
  if (payload.refreshToken) {
    localStorage.setItem(REFRESH_KEY, payload.refreshToken);
  }
  localStorage.setItem(USER_KEY, JSON.stringify(payload.user));
}

async function refreshAccessToken(): Promise<boolean> {
  if (refreshInFlight) {
    return refreshInFlight;
  }

  refreshInFlight = (async () => {
    const refreshToken = localStorage.getItem(REFRESH_KEY);
    if (!refreshToken) {
      return false;
    }

    try {
      const response = await fetch(`${API_BASE}/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refreshToken }),
      });
      const body = (await response.json().catch(() => null)) as {
        data?: { accessToken?: string; refreshToken?: string };
        accessToken?: string;
        refreshToken?: string;
      } | null;

      const access =
        body?.data?.accessToken ?? body?.accessToken ?? null;
      const nextRefresh =
        body?.data?.refreshToken ?? body?.refreshToken ?? null;

      if (!response.ok || !access) {
        return false;
      }

      localStorage.setItem(TOKEN_KEY, access);
      if (nextRefresh) {
        localStorage.setItem(REFRESH_KEY, nextRefresh);
      }
      return true;
    } catch {
      return false;
    } finally {
      refreshInFlight = null;
    }
  })();

  return refreshInFlight;
}

const PUBLIC_AUTH_PATHS = new Set([
  "/auth/login",
  "/auth/register",
  "/auth/recyclers/register",
  "/auth/refresh",
]);

export async function apiFetch<T = unknown>(
  path: string,
  options: RequestInit = {},
  allowRetry = true
): Promise<{ ok: boolean; status: number; data: T; raw: unknown }> {
  const headers = new Headers(options.headers || {});
  if (!headers.has("Content-Type") && options.body) {
    headers.set("Content-Type", "application/json");
  }

  const token = getAccessToken();
  if (token && !PUBLIC_AUTH_PATHS.has(path)) {
    headers.set("Authorization", `Bearer ${token}`);
  }

  let response: Response;
  try {
    response = await fetch(`${API_BASE}${path}`, {
      ...options,
      headers,
      cache: "no-store",
    });
  } catch {
    throw new Error(
      "Cannot reach backend. Confirm the API is running on http://localhost:5000."
    );
  }

  let raw: unknown = null;
  let status = response.status;
  let ok = response.ok;

  try {
    raw = await response.json();
  } catch {
    raw = null;
  }

  const code =
    raw && typeof raw === "object" && "code" in raw
      ? String((raw as { code?: string }).code || "")
      : "";

  if (
    allowRetry &&
    status === 401 &&
    !PUBLIC_AUTH_PATHS.has(path) &&
    (code === "TOKEN_EXPIRED" || code === "UNAUTHORIZED" || !code)
  ) {
    const refreshed = await refreshAccessToken();
    if (refreshed) {
      return apiFetch<T>(path, options, false);
    }
  }

  return {
    ok,
    status,
    data: raw as T,
    raw,
  };
}

export async function loginWithPassword(
  identifier: string,
  password: string
): Promise<{ success: boolean; message?: string; user?: AuthUser }> {
  const result = await apiFetch<{
    success?: boolean;
    message?: string;
    code?: string;
    data?: {
      accessToken?: string;
      refreshToken?: string;
      user?: AuthUser;
    };
    accessToken?: string;
    refreshToken?: string;
    user?: AuthUser;
  }>("/auth/login", {
    method: "POST",
    body: JSON.stringify({ identifier, password }),
  });

  const body = result.data;
  const access = body?.data?.accessToken ?? body?.accessToken;
  const user = body?.data?.user ?? body?.user;

  if (!result.ok || !access || !user) {
    return {
      success: false,
      message: body?.message || body?.code || "Login failed",
    };
  }

  if (user.role !== "RECYCLER" && user.role !== "ADMIN") {
    return {
      success: false,
      message: "This dashboard is for recycler accounts only.",
    };
  }

  saveSession({
    accessToken: access,
    refreshToken: body?.data?.refreshToken ?? body?.refreshToken,
    user,
  });

  return { success: true, user };
}

export type RecyclerSignupInput = {
  fullName: string;
  phone: string;
  email?: string;
  password: string;
  organisationName: string;
  address?: string;
  city?: string;
  region?: string;
};

export async function registerRecyclerAccount(
  input: RecyclerSignupInput
): Promise<{ success: boolean; message?: string }> {
  const result = await apiFetch<{
    success?: boolean;
    message?: string;
    code?: string;
  }>("/auth/recyclers/register", {
    method: "POST",
    body: JSON.stringify(input),
  });

  if (!result.ok) {
    return {
      success: false,
      message:
        (result.data as { message?: string; code?: string })?.message ||
        (result.data as { code?: string })?.code ||
        "Registration failed",
    };
  }

  return {
    success: true,
    message:
      (result.data as { message?: string })?.message ||
      "Account created. You can sign in now.",
  };
}

export async function fetchBackendHealth(): Promise<{
  ok: boolean;
  message: string;
}> {
  try {
    const root = API_BASE.replace(/\/api\/?$/, "");
    const response = await fetch(`${root}/health`, {
      method: "GET",
    });
    if (!response.ok) {
      return { ok: false, message: `Health check failed (${response.status})` };
    }
    return { ok: true, message: "Backend is reachable" };
  } catch {
    return { ok: false, message: "Cannot reach backend" };
  }
}

export type BackendLot = {
  id: string;
  lotNumber?: string;
  lot_number?: string;
  clientReference?: string | null;
  client_reference?: string | null;
  material?: string;
  materialId?: string;
  categoryName?: string;
  collector?: string;
  collectionAddress?: string;
  location?: string;
  weightKg?: number;
  weight?: number;
  aiConfidence?: number | null;
  estimatedValue?: number | null;
  status?: string;
  statusLabel?: string;
  criticalMineral?: boolean;
  createdAt?: string;
  condition?: string;
};

export function mapBackendLotToUi(lot: BackendLot) {
  const statusLabel =
    lot.statusLabel ||
    (lot.status
      ? lot.status.charAt(0) + lot.status.slice(1).toLowerCase()
      : "Pending");

  return {
    id: lot.lotNumber || lot.lot_number || lot.id,
    publicId: lot.id,
    clientReference: lot.clientReference || lot.client_reference || null,
    material:
      lot.categoryName ||
      lot.material ||
      lot.materialId ||
      "E-Waste",
    collector: lot.collector || "Collector",
    location: lot.collectionAddress || lot.location || "—",
    weight: Number(lot.weightKg ?? lot.weight ?? 0),
    aiConfidence: Number(lot.aiConfidence ?? 0),
    estimatedValue:
      lot.estimatedValue === null || lot.estimatedValue === undefined
        ? null
        : Number(lot.estimatedValue),
    status: statusLabel as
      | "Pending"
      | "Accepted"
      | "Rejected"
      | "Handover"
      | "Completed",
    criticalMineral: Boolean(lot.criticalMineral),
    createdAt: lot.createdAt
      ? new Date(lot.createdAt).toLocaleString()
      : "—",
    condition: lot.condition || "Scrap",
  };
}

export async function fetchLotsFromApi() {
  const result = await apiFetch<{
    lots?: BackendLot[];
    data?: { lots?: BackendLot[] };
  }>("/lots?limit=100");

  if (!result.ok) {
    throw new Error("Failed to fetch lots");
  }

  const lots =
    result.data?.data?.lots ||
    result.data?.lots ||
    [];

  return lots.map(mapBackendLotToUi);
}

export async function patchLotStatus(
  lotIdentifier: string,
  status: string
) {
  const result = await apiFetch(`/lots/${encodeURIComponent(lotIdentifier)}/status`, {
    method: "PATCH",
    body: JSON.stringify({ status }),
  });

  if (!result.ok) {
    const message =
      (result.data as { message?: string })?.message ||
      "Failed to update lot status";
    throw new Error(message);
  }

  return result.data;
}

export async function fetchMyTransactions() {
  const result = await apiFetch<{
    transactions?: Array<Record<string, unknown>>;
    data?: { transactions?: Array<Record<string, unknown>> };
  }>("/transactions/my");

  if (!result.ok) {
    throw new Error("Failed to fetch transactions");
  }

  return (
    result.data?.data?.transactions ||
    result.data?.transactions ||
    []
  );
}

export async function confirmHandover(
  handoverId: string,
  body: {
    completeBoth?: boolean;
    paymentMethod?: string;
    finalAmount?: number;
  } = {}
) {
  const result = await apiFetch(`/handovers/${encodeURIComponent(handoverId)}/confirm`, {
    method: "POST",
    body: JSON.stringify({
      completeBoth: body.completeBoth ?? true,
      paymentMethod: body.paymentMethod,
      finalAmount: body.finalAmount,
    }),
  });

  if (!result.ok) {
    const message =
      (result.data as { message?: string })?.message ||
      "Could not confirm handover on the server.";
    throw new Error(message);
  }

  return result;
}
