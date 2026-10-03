export type LotStatus =
  | "Pending"
  | "Accepted"
  | "Rejected"
  | "Handover"
  | "Completed";

export interface Lot {
  id: string;
  /** Backend public UUID — used for PATCH /lots/:id/status when present. */
  publicId?: string;
  /** Offline collector lot UUID — PIN seed used by the Flutter app. */
  clientReference?: string | null;
  material: string;
  collector: string;
  location: string;
  weight: number;
  aiConfidence: number;
  estimatedValue: number | null;
  status: LotStatus;
  criticalMineral: boolean;
  createdAt: string;
  condition: string;
}

export const mockLots: Lot[] = [
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
    weight: 8.0,
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
    weight: 10.0,
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
    weight: 18.0,
    aiConfidence: 0.905,
    estimatedValue: null,
    status: "Pending",
    criticalMineral: false,
    createdAt: "16 Sep 2026, 01:16 PM",
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