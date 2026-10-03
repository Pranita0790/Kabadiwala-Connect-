import type { Lot, LotStatus } from "./mockLots";
import {
  fetchLotsFromApi,
  getAccessToken,
  patchLotStatus,
} from "../lib/api";

const STORAGE_KEY = "kabadiwala-lots";

/**
 * Get the currently stored lots (local cache).
 * Prefer [refreshLotsFromBackend] for live data.
 */
export function getStoredLots(): Lot[] {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);

    if (!stored) {
      return [];
    }

    const parsed = JSON.parse(stored);

    if (!Array.isArray(parsed)) {
      return [];
    }

    return parsed as Lot[];
  } catch (error) {
    console.error("Failed to read stored lots:", error);
    return [];
  }
}

/**
 * Save the complete lot list to localStorage.
 */
export function saveLots(lots: Lot[]): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(lots));
  } catch (error) {
    console.error("Failed to save lots:", error);
  }
}

function notifyLotsUpdated(): void {
  window.dispatchEvent(new Event("kabadiwala-lots-updated"));
}

/**
 * Pull live lots from GET /api/lots (requires recycler JWT).
 * Falls back to the local cache when offline / unauthorized.
 */
export async function refreshLotsFromBackend(): Promise<Lot[]> {
  if (!getAccessToken()) {
    const cached = getStoredLots();
    notifyLotsUpdated();
    return cached;
  }

  try {
    const lots = await fetchLotsFromApi();
    saveLots(lots);
    notifyLotsUpdated();
    return lots;
  } catch (error) {
    console.error("Failed to refresh lots from backend:", error);
    const cached = getStoredLots();
    notifyLotsUpdated();
    return cached;
  }
}

/**
 * Update one lot's status locally and on the backend.
 */
export async function updateLotStatus(
  lotId: string,
  newStatus: LotStatus
): Promise<Lot[]> {
  const lots = getStoredLots();
  const target = lots.find((lot) => lot.id === lotId || lot.publicId === lotId);

  const identifier = target?.publicId || target?.id || lotId;

  try {
    await patchLotStatus(identifier, newStatus);
  } catch (error) {
    console.error("Backend status update failed:", error);
    throw error;
  }

  const updatedLots = lots.map((lot) =>
    lot.id === lotId || lot.publicId === lotId
      ? { ...lot, status: newStatus }
      : lot
  );

  saveLots(updatedLots);
  notifyLotsUpdated();

  // Re-fetch so collector/dashboard stay aligned with server state.
  try {
    return await refreshLotsFromBackend();
  } catch {
    return updatedLots;
  }
}

/**
 * Reset stored lots (clears local cache only).
 */
export function resetStoredLots(): Lot[] {
  saveLots([]);
  notifyLotsUpdated();
  return [];
}
