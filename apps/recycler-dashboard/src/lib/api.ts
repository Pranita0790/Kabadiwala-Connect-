const API_BASE =
  import.meta.env.VITE_API_BASE_URL ??
  "https://kabadiwala-backend-69wr.onrender.com/api";

const TOKEN_KEY = "kabadiwala-access-token";
const REFRESH_KEY = "kabadiwala-refresh-token";
const USER_KEY = "kabadiwala-auth-user";

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

export async function apiFetch<T = unknown>(
  path: string,
  options: RequestInit = {}
): Promise<{ ok: boolean; status: number; data: T; raw: unknown }> {
  const headers = new Headers(options.headers || {});
  if (!headers.has("Content-Type") && options.body) {
    headers.set("Content-Type", "application/json");
  }

  const token = getAccessToken();
  if (token) {
    headers.set("Authorization", `Bearer ${token}`);
  }

  const response = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
  });

  let raw: unknown = null;
  try {
    raw = await response.json();
  } catch {
    raw = null;
  }

  return {
    ok: response.ok,
    status: response.status,
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
    data?: {
      accessToken?: string;
      refreshToken?: string;
      user?: AuthUser;
    };
  }>("/auth/login", {
    method: "POST",
    body: JSON.stringify({ identifier, password }),
  });

  const body = result.data;
  const access = body?.data?.accessToken;
  const user = body?.data?.user;

  if (!result.ok || !access || !user) {
    return {
      success: false,
      message: body?.message || "Login failed",
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
    refreshToken: body?.data?.refreshToken,
    user,
  });

  return { success: true, user };
}

export type BackendLot = {
  id: string;
  lotNumber?: string;
  lot_number?: string;
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

export async function confirmHandover(handoverId: string) {
  return apiFetch(`/handovers/${encodeURIComponent(handoverId)}/confirm`, {
    method: "POST",
  });
}
