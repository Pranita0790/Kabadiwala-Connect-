import type { Lot } from "./mockLots";

const STORAGE_KEY = "kabadiwala-lots";

/**
 * Get the currently stored lots.
 * If nothing is stored yet, use the mock lots as the initial data.
 */
export function getStoredLots(): Lot[] {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);

    if (!stored) {
      return [...mockLots];
    }

    const parsed = JSON.parse(stored);

    if (!Array.isArray(parsed)) {
      return [...mockLots];
    }

    return parsed as Lot[];
  } catch (error) {
    console.error("Failed to read stored lots:", error);
    return [...mockLots];
  }
}

/**
 * Save the complete lot list to localStorage.
 */
export function saveLots(lots: Lot[]): void {
  try {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify(lots)
    );
  } catch (error) {
    console.error("Failed to save lots:", error);
  }
}

/**
 * Update one lot's status.
 */
export function updateLotStatus(
  lotId: string,
  newStatus: Lot["status"]
): Lot[] {
  const lots = getStoredLots();

  const updatedLots = lots.map((lot) =>
    lot.id === lotId
      ? {
          ...lot,
          status: newStatus,
        }
      : lot
  );

  saveLots(updatedLots);

  window.dispatchEvent(
    new Event("kabadiwala-lots-updated")
  );

  return updatedLots;
}

/**
 * Reset stored lots back to the original mock data.
 * Useful during development/testing.
 */
export function resetStoredLots(): Lot[] {
  const lots = [...mockLots];

  saveLots(lots);

  window.dispatchEvent(
    new Event("kabadiwala-lots-updated")
  );

  return lots;
}

/**
 * Initial mock data.
 *
 * These are only used when localStorage does not
 * already contain lot data.
 */
const mockLots: Lot[] = [
  {
    id: "KC-2026-0148",
    material: "PCB",
    collector: "Ramesh Kumar",
    location: "Dharavi, Mumbai",
    weight: 12.5,
    aiConfidence: 0.991,
    estimatedValue: 5604,
    status: "Pending",
    criticalMineral: true,
    createdAt: "17 Sep 2026, 09:42 AM",
    condition: "Scrap",
  },
  {
    id: "KC-2026-0147",
    material: "Battery",
    collector: "Suresh Patil",
    location: "Kurla, Mumbai",
    weight: 8,
    aiConfidence: 0.998,
    estimatedValue: 800,
    status: "Accepted",
    criticalMineral: true,
    createdAt: "17 Sep 2026, 08:25 AM",
    condition: "Scrap",
  },
  {
    id: "KC-2026-0146",
    material: "Cable",
    collector: "Amit Shah",
    location: "Sion, Mumbai",
    weight: 15.2,
    aiConfidence: 0.642,
    estimatedValue: 6027,
    status: "Handover",
    criticalMineral: false,
    createdAt: "16 Sep 2026, 05:18 PM",
    condition: "Scrap",
  },
  {
    id: "KC-2026-0145",
    material: "LCD Panel",
    collector: "Vijay More",
    location: "Chembur, Mumbai",
    weight: 10,
    aiConfidence: 0.829,
    estimatedValue: null,
    status: "Pending",
    criticalMineral: false,
    createdAt: "16 Sep 2026, 03:41 PM",
    condition: "Scrap",
  },
  {
    id: "KC-2026-0144",
    material: "CRT",
    collector: "Mahesh Jadhav",
    location: "Wadala, Mumbai",
    weight: 18,
    aiConfidence: 0.905,
    estimatedValue: null,
    status: "Pending",
    criticalMineral: false,
    createdAt: "16 Sep 2026, 01:16 AM",
    condition: "Scrap",
  },
  {
    id: "KC-2026-0143",
    material: "PCB",
    collector: "Ravi Yadav",
    location: "Kurla, Mumbai",
    weight: 6.5,
    aiConfidence: 0.987,
    estimatedValue: 2914,
    status: "Accepted",
    criticalMineral: true,
    createdAt: "16 Sep 2026, 11:08 AM",
    condition: "Scrap",
  },
];