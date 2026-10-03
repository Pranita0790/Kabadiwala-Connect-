/**
 * 6-digit handover PIN — must match collector
 * `Handover.deriveHandoverPin` (Dart).
 *
 * Algorithm: strip dashes, lowercase, keep first 8 chars with non-hex
 * replaced by `0`, parse as hex, mod 1_000_000, pad to 6 digits.
 */
export function deriveHandoverPin(id: string): string {
  const cleaned = id.replace(/-/g, "").toLowerCase();
  let seed = "";
  for (let i = 0; i < cleaned.length && seed.length < 8; i++) {
    const c = cleaned[i];
    seed += /[0-9a-f]/.test(c) ? c : "0";
  }
  seed = seed.padEnd(8, "0");
  const value = Number.parseInt(seed, 16) % 1_000_000;
  return value.toString().padStart(6, "0");
}
