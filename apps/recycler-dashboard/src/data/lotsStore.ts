import {
    mockLots,
    type Lot,
    type LotStatus,
  } from "./mockLots";
  
  export const LOTS_STORAGE_KEY = "kabadiwala-lots";
  
  export function getStoredLots(): Lot[] {
    try {
      const storedLots =
        localStorage.getItem(LOTS_STORAGE_KEY);
  
      if (storedLots) {
        return JSON.parse(storedLots) as Lot[];
      }
    } catch {
      // Fall back to mock data
    }
  
    return mockLots;
  }
  
  export function saveLots(lots: Lot[]) {
    localStorage.setItem(
      LOTS_STORAGE_KEY,
      JSON.stringify(lots)
    );
  
    window.dispatchEvent(
      new Event("kabadiwala-lots-updated")
    );
  }
  
  export function updateLotStatus(
    lotId: string,
    status: LotStatus
  ): Lot[] {
    const currentLots = getStoredLots();
  
    const updatedLots = currentLots.map((lot) =>
      lot.id === lotId
        ? {
            ...lot,
            status,
          }
        : lot
    );
  
    saveLots(updatedLots);
  
    return updatedLots;
  }