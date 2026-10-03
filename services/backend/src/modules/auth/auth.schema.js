/*
|--------------------------------------------------------------------------
| AUTH SCHEMAS
|--------------------------------------------------------------------------
| Request shapes for the auth endpoints, validated by
| middleware/validate.js.
|
| Sign-up accepts a phone in Indian formats: 10 digits, optionally prefixed
| with +91 / 91 / 0, optionally with spaces or dashes.
|--------------------------------------------------------------------------
*/

const { z } = require("zod");

const { userRole } = require("../../config/constants");

/*
 | Accepts the formats an Indian mobile number is actually typed in: 10
 | digits, with or without a 91 / +91 / 0 prefix, and with spaces or dashes
 | anywhere between digits.
 |
 | The separators must be allowed throughout, not just after the country
 | code, or this pattern rejects input that `normalisePhone` happily accepts.
 | A collector typing "+91 98765 43210" would pass one and fail the other,
 | and which one runs first decides whether sign-up works. tests/unit/
 | phone-normalisation.test.js asserts the two agree.
 */
const phonePattern = /^(?:\+?91[\s-]?|0)?[6-9](?:[\s-]?\d){9}$/;

const phone = z
  .string()
  .trim()
  .regex(phonePattern, "Must be a valid 10-digit Indian mobile number");

const email = z.string().trim().toLowerCase().email("Must be a valid email");

const password = z
  .string()
  .min(8, "Password must be at least 8 characters")
  .max(128, "Password must not exceed 128 characters");

const fullName = z
  .string()
  .trim()
  .min(2, "Name must be at least 2 characters")
  .max(120, "Name must not exceed 120 characters");

const identifier = z
  .string()
  .trim()
  .min(3, "Enter your phone number or email")
  .max(160, "Identifier is too long");

const otpCode = z
  .string()
  .trim()
  .regex(/^\d{6}$/, "OTP must be exactly 6 digits");

/**
 * Normalise an Indian mobile number to E.164 so lookups are consistent.
 *
 * Accepted input: a bare 10-digit number, 0-prefixed, or 91-prefixed with or
 * without +, optionally with spaces or dashes.
 *
 * Returns `null` for anything else rather than passing the digits through.
 * That is deliberate: this function is now the only thing standing between a
 * Firebase-asserted phone_number claim and a new platform account, because
 * the token's phone claim never passes through the zod phonePattern. A
 * pass-through fallback would let a Firebase account holding, say, a US
 * number create an account on a platform that only issues to Indian mobiles.
 *
 * Indian mobile numbers are 10 digits beginning 6-9.
 */
function normalisePhone(value) {
  const trimmed = String(value).trim();
  const digits = trimmed.replace(/\D/g, "");

  if (!digits) {
    return null;
  }

  // Explicit international form, e.g. +91 98765 43210. The country code is
  // matched here rather than inferred, so no other country can pass.
  if (trimmed.startsWith("+")) {
    if (digits.length === 12 && digits.startsWith("91")) {
      return isIndianMobile(`+${digits}`) ? `+${digits}` : null;
    }

    return null;
  }

  if (digits.length === 10) {
    return isIndianMobile(`+91${digits}`) ? `+91${digits}` : null;
  }

  if (digits.length === 12 && digits.startsWith("91")) {
    return isIndianMobile(`+${digits}`) ? `+${digits}` : null;
  }

  if (digits.length === 11 && digits.startsWith("0")) {
    const national = digits.slice(1);

    return isIndianMobile(`+91${national}`) ? `+91${national}` : null;
  }

  return null;
}

/** The digit body an Indian mobile number normalises to, for validation. */
function isIndianMobile(e164) {
  return typeof e164 === "string" && /^91[6-9]\d{9}$/.test(e164.replace("+", ""));
}

const register = {
  body: z
    .object({
      fullName,
      phone,
      email: email.optional(),
      password,
      role: z.enum([userRole.COLLECTOR]).default(userRole.COLLECTOR),
    })
    .strict(),
};

const login = {
  body: z
    .object({
      identifier,
      password: z.string().min(1, "Password is required").max(128),
    })
    .strict(),
};

const requestOtp = {
  body: z
    .object({
      identifier,
      channel: z.enum(["SMS", "EMAIL"]).optional(),
    })
    .strict(),
};

const verifyOtp = {
  body: z
    .object({
      identifier,
      code: otpCode,
    })
    .strict(),
};

const refresh = {
  body: z
    .object({
      refreshToken: z.string().min(10, "refreshToken is required"),
    })
    .strict(),
};

const logout = {
  body: z
    .object({
      refreshToken: z.string().optional(),
      allDevices: z.boolean().default(false),
    })
    .strict(),
};

const changePassword = {
  body: z
    .object({
      currentPassword: z.string().min(1),
      newPassword: password,
    })
    .strict(),
};

const updateProfile = {
  body: z
    .object({
      fullName: fullName.optional(),
      email: email.optional(),
    })
    .strict()
    .refine((value) => Object.keys(value).length > 0, {
      message: "Provide at least one field to update",
    }),
};

const registerRecycler = {
  body: z
    .object({
      fullName,
      phone,
      email: email.optional(),
      password,
      organisationName: z
        .string()
        .trim()
        .min(2, "Organisation name is required")
        .max(160),
      address: z.string().trim().max(400).optional(),
      city: z.string().trim().max(120).optional(),
      region: z.string().trim().max(80).optional(),
    })
    .strict(),
};

/**
 * Firebase phone sign-in.
 *
 * `idToken` is the Firebase ID token the device obtained after verifying the
 * SMS code. It is a JWT of roughly 1-2 KB, so the cap is generous; it is never
 * logged (see the auth controller and lib/logger redaction).
 *
 * `fullName` is accepted only because Firebase Phone Auth carries no name and
 * the collector app collects one during sign-up. An existing account's name is
 * never overwritten by a later sign-in.
 */
const firebaseSignIn = {
  body: z
    .object({
      idToken: z
        .string()
        .trim()
        .min(20, "idToken is required")
        .max(8192, "idToken is too large"),
      fullName: z.string().trim().min(2).max(120).optional(),
    })
    .strict(),
};

module.exports = {
  register,
  login,
  requestOtp,
  verifyOtp,
  refresh,
  logout,
  changePassword,
  updateProfile,
  registerRecycler,
  firebaseSignIn,
  normalisePhone,
  isIndianMobile,
  phonePattern,
};
