/**
 * 6-digit handover PIN — must match collector
 * `Handover.deriveHandoverPin` (Dart).
 *
 * Algorithm: strip dashes, lowercase, keep first 8 chars with non-hex
 * replaced by `0`, parse as hex, mod 1_000_000, pad to 6 digits.
 *
 * Collector apps derive from the offline lot UUID (`clientReference`).
 * The website must accept that seed (not only the server `publicId`).
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

/** True if [enteredPin] matches any candidate lot identifier seed. */
export function matchesHandoverPin(
  enteredPin: string,
  ...candidateIds: Array<string | null | undefined>
): boolean {
  const entered = enteredPin.trim();
  if (!/^\d{6}$/.test(entered)) return false;
  for (const id of candidateIds) {
    if (!id) continue;
    if (deriveHandoverPin(id) === entered) return true;
  }
  return false;
}
