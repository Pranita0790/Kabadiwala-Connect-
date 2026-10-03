/*
|--------------------------------------------------------------------------
| TOKENS
|--------------------------------------------------------------------------
| Access tokens: short lived, signed JWTs. Refresh tokens: opaque random
| strings stored hashed in PostgreSQL, so they can be revoked server side.
|
| A JWT is signed, not encrypted: it carries only an id, role and
| organisation id, never personal data (AGENTS.md section 9).
|--------------------------------------------------------------------------
*/

const crypto = require("node:crypto");
const jwt = require("jsonwebtoken");

const config = require("../config/env");
const { AuthenticationError } = require("./errors");

const SIGNING_ALGORITHM = "HS256";

/*
|--------------------------------------------------------------------------
| ACCESS TOKEN
|--------------------------------------------------------------------------
*/

/**
 * Build the access token payload from a user DTO.
 *
 * The DTO produced by the repositories uses camelCase (`publicId`,
 * `fullName`), which is the single shape used everywhere else in the backend.
 * The public id is what goes into `sub` — it is the identifier clients see
 * and it is stable, whereas the internal primary key is not exposed.
 *
 * A missing public id is a programming error, not a runtime condition to
 * paper over: signing a token with `sub: undefined` would produce a token
 * that verifies but can never be resolved to a user.
 */
function buildAccessPayload(user) {
  if (!user?.publicId) {
    throw new Error(
      "signAccessToken requires a user DTO with a publicId; got: " +
        JSON.stringify(user)
    );
  }

  const payload = {
    sub: user.publicId,
    role: user.role,
    name: user.fullName ?? null,
  };

  if (user.recyclerId) {
    payload.rid = user.recyclerId;
  }

  return payload;
}

function signAccessToken(user) {
  return jwt.sign(buildAccessPayload(user), config.auth.jwtSecret, {
    algorithm: SIGNING_ALGORITHM,
    expiresIn: config.auth.accessTokenTtl,
    issuer: config.auth.issuer,
    audience: config.auth.audience,
  });
}

function verifyAccessToken(token) {
  try {
    return jwt.verify(token, config.auth.jwtSecret, {
      algorithms: [SIGNING_ALGORITHM],
      issuer: config.auth.issuer,
      audience: config.auth.audience,
    });
  } catch (error) {
    if (error.name === "TokenExpiredError") {
      throw new AuthenticationError(
        "Access token has expired",
        "TOKEN_EXPIRED"
      );
    }

    throw new AuthenticationError("Invalid access token", "TOKEN_INVALID");
  }
}

/**
 * Read a bearer token from the Authorization header.
 * Also accepts the header, because the Flutter http client is sometimes
 * configured to send the raw token without the "Bearer " prefix.
 */
function extractBearerToken(req) {
  const header = req.get("authorization");

  if (!header) {
    return null;
  }

  const [scheme, ...rest] = header.split(" ");

  if (!scheme) {
    return null;
  }

  if (scheme.toLowerCase() === "bearer") {
    return rest.join(" ").trim() || null;
  }

  // A bare token with no scheme.
  return scheme.trim() || null;
}

/*
|--------------------------------------------------------------------------
| REFRESH TOKEN
|--------------------------------------------------------------------------
*/

function generateRefreshToken() {
  const token = crypto.randomBytes(48).toString("base64url");

  return {
    // The plaintext is handed to the client exactly once; only the hash is
    // stored, so a database dump cannot be replayed as a session.
    token,
    tokenHash: hashRefreshToken(token),
  };
}

function hashRefreshToken(token) {
  return crypto.createHash("sha256").update(token).digest("hex");
}

function refreshTokenExpiry(now = new Date()) {
  return new Date(
    now.getTime() + config.auth.refreshTokenTtlDays * 24 * 60 * 60 * 1000
  );
}

/*
|--------------------------------------------------------------------------
| OTP
|--------------------------------------------------------------------------
*/

function generateOtpCode(digits = 6) {
  const max = 10 ** digits - 1;
  // randomInt avoids the modulo bias of Math.random() * max.
  return String(crypto.randomInt(0, max + 1)).padStart(digits, "0");
}

function hashOtpCode(code) {
  return crypto.createHash("sha256").update(String(code)).digest("hex");
}

function otpExpiry(now = new Date()) {
  return new Date(now.getTime() + 10 * 60 * 1000);
}

function isOtpExpired(expiresAt, now = new Date()) {
  return new Date(expiresAt).getTime() <= now.getTime();
}

module.exports = {
  signAccessToken,
  buildAccessPayload,
  verifyAccessToken,
  extractBearerToken,
  generateRefreshToken,
  hashRefreshToken,
  refreshTokenExpiry,
  generateOtpCode,
  hashOtpCode,
  otpExpiry,
  isOtpExpired,
};
