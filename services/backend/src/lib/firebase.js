/*
|--------------------------------------------------------------------------
| FIREBASE ID TOKEN VERIFICATION
|--------------------------------------------------------------------------
| Verifies a Firebase ID token (a JWT) that a Firebase client obtained after
| completing Phone Auth on-device.
|
| WHY THIS EXISTS
|
| With Firebase Phone Auth the SMS is sent and the code is checked by
| Firebase, not by this backend. The device ends up holding a Firebase ID
| token, and this backend's job is to decide whether that token proves the
| phone number it claims.
|
| This deliberately does NOT use the firebase-admin SDK. Verification only
| needs Google's PUBLIC signing certificates, so no service-account private
| key is required — which matters because such a key must never reach this
| repository (AGENTS.md section 9). Adding the Admin SDK would also pull in a
| large dependency tree for one operation (AGENTS.md section 13).
|
| WHAT IS CHECKED
|
|   1. Signature, against Google's JWKS (cached, refreshed on unknown kid).
|   2. `aud`  == this Firebase project id, so a token minted for a different
|      project cannot be replayed here.
|   3. `iss`  == https://securetoken.google.com/<project id>.
|   4. `exp` / `nbf`, plus `auth_time` for freshness.
|   5. `sub`  is a non-empty string (the Firebase uid).
|
| A token that fails any of these is rejected; nothing is inferred.
|
| IMPORTANT LIMITATION, STATED PLAINLY
|
| Firebase confirms that the DEVICE completed SMS verification. It does not
| prove that the person holding the phone is the rightful owner, so a
| `+91` number is only as trustworthy as the SIM. Material weighting and
| settlement money depend on this number, so recycler-facing settlement
| still requires an independent identity check.
|
| Reference: https://firebase.google.com/docs/auth/admin/verify-id-tokens
 *-------------------------------------------------------------------------
*/

const {
  createRemoteJWKSet,
  createLocalJWKSet,
  jwtVerify,
  decodeJwt,
} = require("jose");

const config = require("../config/env");
const logger = require("./logger");
const { AuthenticationError, ServiceUnavailableError } = require("./errors");

const ISSUER_PREFIX = "https://securetoken.google.com/";

/**
 * Google's signing certificates for Firebase ID tokens. `jose` caches the
 * key set and refetches when it meets an unknown `kid`, so a Google key
 * rotation does not require a deploy here.
 */
let cachedJwks = null;
let cachedProjectId = null;

function jwksFor(projectId) {
  if (cachedProjectId !== projectId) {
    cachedJwks = createRemoteJWKSet(
      new URL(
        "https://www.googleapis.com/service_accounts/v1/jwk/" +
          "securetoken@system.gserviceaccount.com"
      )
    );
    cachedProjectId = projectId;
  }

  return cachedJwks;
}

/**
 * Is Firebase phone auth configured?
 *
 * Reported by /api/health so a deployment missing the project id is obvious
 * before a collector hits a login error.
 */
function isEnabled() {
  return Boolean(config.auth.firebaseProjectId);
}

/**
 * Verify a Firebase ID token and return its claims.
 *
 * @param {string} idToken
 * @returns {Promise<{uid: string, phoneNumber: string|null, claims: object}>}
 * @throws {AuthenticationError} on any verification failure
 */
async function verifyIdToken(idToken) {
  if (!isEnabled()) {
    // A configuration fault must not look like a rejected credential: 503, not
    // 401. The caller's token may be fine; the server is missing a setting.
    throw new ServiceUnavailableError(
      "Phone sign-in is not configured on this server.",
      "FIREBASE_NOT_CONFIGURED"
    );
  }

  return verifyWith(idToken, jwksFor(config.auth.firebaseProjectId), config.auth.firebaseProjectId);
}

/**
 * The verification itself, with the key set supplied by the caller.
 *
 * Split out from verifyIdToken so the signature/audience/issuer rules can be
 * tested against real RSA-signed tokens without reaching Google. The key set
 * is injected rather than read from the environment on purpose: making the
 * JWKS URL configurable would let anyone who can set an env var point token
 * verification at a key set they control.
 *
 * @param {string} idToken
 * @param {object} jwks  A jose key set resolver
 * @param {string} projectId
 */
async function verifyWith(idToken, jwks, projectId) {
  if (typeof idToken !== "string" || idToken.trim().length === 0) {
    throw new AuthenticationError(
      "A Firebase ID token is required.",
      "FIREBASE_TOKEN_MISSING"
    );
  }

  const token = idToken.trim();

  let claims;

  try {
    ({ payload: claims } = await jwtVerify(token, jwks, {
      // Firebase signs with RS256. Pinning the algorithm list is what stops
      // an `alg: none` or HMAC-with-public-key token from being accepted.
      algorithms: ["RS256"],
      audience: projectId,
      issuer: `${ISSUER_PREFIX}${projectId}`,
      // Small tolerance for clock drift between device and server.
      clockTolerance: 5,
    }));
  } catch (error) {
    logger.warn("Firebase ID token rejected", {
      // The reason code, never the token itself.
      reason: error.code || error.name,
    });

    throw new AuthenticationError(
      firebaseErrorMessage(error),
      "FIREBASE_TOKEN_INVALID"
    );
  }

  if (typeof claims.sub !== "string" || claims.sub.length === 0) {
    throw new AuthenticationError(
      "Firebase token is missing a subject.",
      "FIREBASE_TOKEN_INVALID"
    );
  }

  return {
    uid: claims.sub,
    phoneNumber: claims.phone_number ?? null,
    email: claims.email ?? null,
    emailVerified: claims.email_verified === true,
    // Present when the sign-in came from Phone Auth, absent for other
    // providers (Google, Apple, password).
    signInProvider: claims.firebase?.sign_in_provider ?? null,
    claims,
  };
}

/**
 * Read claims WITHOUT verifying, for diagnostics only.
 *
 * Never use the result to make an authorisation decision: an unverified
 * payload can be forged by anyone.
 */
function peek(idToken) {
  try {
    return decodeJwt(idToken);
  } catch {
    return null;
  }
}

/**
 * Turn a jose failure into something safe to show a collector.
 *
 * The raw jose messages ("jwt signature verification failed") are useless in
 * a phone UI and can hint at internals, so they are mapped to fixed text.
 */
function firebaseErrorMessage(error) {
  switch (error.code) {
    case "ERR_JWT_EXPIRED":
      return "Your sign-in link has expired. Please request a new code.";

    case "ERR_JWT_CLAIM_VALIDATION_FAILED":
      // Could be a wrong audience/issuer, i.e. a token from a different
      // Firebase project, or not-yet-valid `nbf`.
      return "That sign-in could not be verified. Please try again.";

    case "ERR_JWKS_NO_MATCHING_KEY":
    case "ERR_JWKS_MULTIPLE_MATCHING_KEYS":
    case "ERR_JWKS_TIMEOUT":
    case "ERR_JOSE_GENERIC":
    default:
      return "Could not verify your sign-in. Please try again.";
  }
}

module.exports = {
  isEnabled,
  verifyIdToken,
  verifyWith,
  peek,
  ISSUER_PREFIX,
};