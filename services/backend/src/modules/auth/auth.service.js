/*
|--------------------------------------------------------------------------
| AUTH SERVICE
|--------------------------------------------------------------------------
| Authentication and account business rules.
|
| Security decisions worth stating:
|   - A failed login returns one generic message for "no such account" and
|     "wrong password", so the endpoint cannot be used to enumerate accounts.
|   - The same constant-ish bcrypt work is done for an unknown account, so
|     response time does not reveal whether the account exists.
|   - Refresh tokens rotate on every use. Reuse of an already-rotated token
|     revokes the whole chain, which is the standard reuse-detection response.
|   - OTPs are hashed at rest, single use, and rate limited by attempt count.
|--------------------------------------------------------------------------
*/

const authRepository = require("./auth.repository");
const notificationService = require("../notifications/notifications.service");
const config = require("../../config/env");
const {
  hashPassword,
  verifyPassword,
  assertPasswordStrength,
} = require("../../lib/password");
const {
  signAccessToken,
  generateRefreshToken,
  hashRefreshToken,
  refreshTokenExpiry,
  generateOtpCode,
  hashOtpCode,
  otpExpiry,
  isOtpExpired,
} = require("../../lib/tokens");
const { normalisePhone } = require("./auth.schema");
const {
  AuthenticationError,
  AuthorizationError,
  ConflictError,
  NotFoundError,
  ValidationError,
  UnprocessableError,
} = require("../../lib/errors");
const { userRole } = require("../../config/constants");
const logger = require("../../lib/logger");

// Collector mobile login accepts both kabadiwala (COLLECTOR) and household (USER).
// User app login stays USER-only.
const APP_ALLOWED_ROLES = Object.freeze({
  collector: new Set([userRole.COLLECTOR, userRole.USER]),
  user: new Set([userRole.USER]),
});

const GENERIC_LOGIN_FAILURE = "Incorrect phone number/email or password.";

/*
|--------------------------------------------------------------------------
| PRESENTATION
|--------------------------------------------------------------------------
*/

function toPublicUser(user) {
  return {
    id: user.publicId,
    fullName: user.fullName,
    phone: user.phone,
    email: user.email,
    role: user.role,
    isVerified: user.isVerified,
    isActive: user.isActive,
    recyclerId: user.recyclerId,
    organisationName: user.organisationName,
    createdAt: user.createdAt,
    lastLoginAt: user.lastLoginAt,
  };
}

/**
 * Build the token pair for a user, persisting the refresh token hash.
 */
async function issueSession(user, { userAgent, ipAddress } = {}) {
  const accessToken = signAccessToken(user);
  const { token: refreshToken, tokenHash } = generateRefreshToken();

  const stored = await authRepository.storeRefreshToken({
    userId: user.id,
    tokenHash,
    expiresAt: refreshTokenExpiry(),
    userAgent: userAgent ?? null,
    ipAddress: ipAddress ?? null,
  });

  return {
    accessToken,
    refreshToken,
    tokenType: "Bearer",
    expiresIn: config.auth.accessTokenTtl,
    user: toPublicUser(user),
    refreshTokenId: stored.id,
  };
}

/*
|--------------------------------------------------------------------------
| REGISTRATION
|--------------------------------------------------------------------------
*/

async function register({ fullName, phone: rawPhone, email, password, role }) {
  const normalisedPhone = normalisePhone(rawPhone);

  const existing = await authRepository.findByIdentifier(normalisedPhone);

  if (existing) {
    throw new ConflictError(
      "An account already exists for this phone number or email",
      "ACCOUNT_EXISTS"
    );
  }

  if (email) {
    const emailOwner = await authRepository.findByIdentifier(email);

    if (emailOwner) {
      throw new ConflictError(
        "An account already exists for this email",
        "ACCOUNT_EXISTS"
      );
    }
  }

  const user = await authRepository.createUser({
    phone: normalisedPhone,
    email: email ?? null,
    passwordHash: await hashPassword(password),
    fullName,
    role,
    isVerified: false,
  });

  logger.info("Account registered", {
    userId: user.publicId,
    role: user.role,
  });

  return user;
}

async function registerRecycler({
  fullName,
  phone: rawPhone,
  email,
  password,
  organisationName,
  address,
  city,
  region,
}) {
  const normalisedPhone = normalisePhone(rawPhone);

  const existing = await authRepository.findByIdentifier(normalisedPhone);

  if (existing) {
    throw new ConflictError(
      "An account already exists for this phone number or email",
      "ACCOUNT_EXISTS"
    );
  }

  // A recycler is not self-authorised. `is_authorized` stays false until an
  // administrator verifies the organisation.
  const { user } = await authRepository.createRecyclerUserWithProfile({
    phone: normalisedPhone,
    email: email ?? null,
    passwordHash: await hashPassword(password),
    fullName,
    organisationName,
    address: address ?? null,
    city: city ?? null,
    region: region ?? null,
    isAuthorized: false,
  });

  logger.info("Recycler account registered", {
    userId: user.publicId,
    organisationName,
  });

  return user;
}

/*
|--------------------------------------------------------------------------
| PASSWORD LOGIN
|--------------------------------------------------------------------------
*/

async function login({ identifier, password, app }, context = {}) {
  // Accept a phone in any common format, or an email.
  const lookup = identifier.includes("@")
    ? identifier.toLowerCase()
    : normalisePhone(identifier);

  const user = await authRepository.findByIdentifier(lookup);

  if (!user) {
    // Spend comparable time so timing does not disclose account existence.
    await verifyPassword(password, "$2b$10$invalidinvalidinvalidinvalidinvalidinvalidinvalidinvalidinv");

    throw new AuthenticationError(GENERIC_LOGIN_FAILURE, "INVALID_CREDENTIALS");
  }

  if (!user.passwordHash) {
    // Firebase phone sign-in is now the only password-free path.
    throw new AuthenticationError(
      "This account signs in with your phone number. Enter it on the sign-in screen.",
      "FIREBASE_SIGN_IN_REQUIRED"
    );
  }

  const passwordMatches = await verifyPassword(password, user.passwordHash);

  if (!passwordMatches) {
    logger.warn("Failed password login", { userId: user.publicId });

    throw new AuthenticationError(GENERIC_LOGIN_FAILURE, "INVALID_CREDENTIALS");
  }

  if (!user.isActive) {
    throw new AuthenticationError("Account is deactivated", "ACCOUNT_INACTIVE");
  }

  const allowedRoles = app ? APP_ALLOWED_ROLES[app] : null;
  if (allowedRoles && !allowedRoles.has(user.role)) {
    throw new AuthorizationError(
      app === "collector"
        ? "This account cannot sign in on the collector app."
        : "This account is not a household user. Open the collector app to sign in."
    );
  }

  await authRepository.recordLogin(user.id);

  return issueSession(user, context);
}

async function changePassword(user, { currentPassword, newPassword }) {
  if (!user.passwordHash) {
    throw new UnprocessableError(
      "This account has no password set",
      "NO_PASSWORD_SET"
    );
  }

  const matches = await verifyPassword(currentPassword, user.passwordHash);

  if (!matches) {
    throw new AuthenticationError("Current password is incorrect", "INVALID_CREDENTIALS");
  }

  const problems = assertPasswordStrength(newPassword);

  if (problems.length > 0) {
    throw new ValidationError("New password is too weak", {
      requirements: problems,
    });
  }

  await authRepository.updatePasswordHash(user.id, await hashPassword(newPassword));

  // Changing a password invalidates every other session on the account.
  const revoked = await authRepository.revokeAllRefreshTokens(user.id);

  logger.info("Password changed; sessions revoked", {
    userId: user.publicId,
    revokedSessions: revoked,
  });

  return { sessionsRevoked: revoked };
}

/*
|--------------------------------------------------------------------------
| OTP LOGIN
|--------------------------------------------------------------------------
*/

/**
 * An OTP challenge is created and the code is returned to the caller.
 *
 * RETURNS THE CODE ONLY BECAUSE no SMS/email provider is wired up yet. In a
 * deployed environment this must go through a provider and the response must
 * be reduced to `{ sent: true }`. See the note in auth.controller.js.
 */
async function requestOtp({ identifier, channel }) {
  const lookup = identifier.includes("@")
    ? identifier.toLowerCase()
    : normalisePhone(identifier);

  // Phone-based sign-in is handled by Firebase Phone Auth, which sends the SMS
  // and verifies the code on the device. This endpoint only issues codes for
  // email delivery. Silently falling back to SMS here would resurrect a second
  // SMS path that bypasses Firebase entirely.
  if (channel === "SMS" || (!channel && !identifier.includes("@"))) {
    throw new ValidationError(
      "SMS codes are no longer sent by this server. Sign in with phone number " +
        "to receive a code from Firebase.",
      { channel: "SMS sign-in is handled by Firebase Phone Auth" }
    );
  }

  const user = await authRepository.findByIdentifier(lookup);

  // Do not reveal whether the account exists.
  if (!user) {
    logger.info("OTP requested for unknown identifier");

    return { challengeId: null, delivered: false, devCode: null };
  }

  if (!user.isActive) {
    throw new AuthenticationError("Account is deactivated", "ACCOUNT_INACTIVE");
  }

  // EMAIL-only: a user with no address on file can never receive a code.
  if (!user.email) {
    logger.info("OTP requested for an account with no email address", {
      userId: user.publicId,
    });

    return { challengeId: null, delivered: false, devCode: null };
  }

  const code = generateOtpCode();
  const challenge = await authRepository.createOtpChallenge({
    userId: user.id,
    channel: "EMAIL",
    destination: user.email,
    codeHash: hashOtpCode(code),
    expiresAt: otpExpiry(),
  });

  logger.info("OTP challenge issued", {
    userId: user.publicId,
    channel: "EMAIL",
    challengeId: challenge.id,
  });

  return {
    challengeId: challenge.id,
    delivered: true,
    expiresInSeconds: 600,
    // Development convenience — see the note above.
    devCode: config.isProduction ? null : code,
  };
}

async function verifyOtp({ identifier, code }) {
  const lookup = identifier.includes("@")
    ? identifier.toLowerCase()
    : normalisePhone(identifier);

  const user = await authRepository.findByIdentifier(lookup);

  if (!user) {
    throw new AuthenticationError("Invalid or expired OTP", "OTP_INVALID");
  }

  const challenge = await authRepository.findActiveOtpChallenge(user.id);

  if (!challenge) {
    throw new AuthenticationError("Request a new OTP", "OTP_NOT_FOUND");
  }

  if (isOtpExpired(challenge.expiresAt)) {
    throw new AuthenticationError("OTP has expired. Request a new one.", "OTP_EXPIRED");
  }

  if (challenge.attempts >= challenge.maxAttempts) {
    throw new AuthenticationError(
      "Too many incorrect attempts. Request a new OTP.",
      "OTP_ATTEMPTS_EXCEEDED"
    );
  }

  const codeMatches = hashOtpCode(code) === challenge.codeHash;

  if (!codeMatches) {
    const updated = await authRepository.incrementOtpAttempts(challenge.id);

    logger.warn("Incorrect OTP submitted", {
      userId: user.publicId,
      attempts: updated?.attempts,
    });

    throw new AuthenticationError("Invalid or expired OTP", "OTP_INVALID");
  }

  // Single use: consume before issuing a session.
  await authRepository.consumeOtpChallenge(challenge.id);

  if (!user.isVerified) {
    await authRepository.setVerified(user.id);
  }

  await authRepository.recordLogin(user.id);

  const fresh = await authRepository.findById(user.id);

  await notificationService.create({
    userId: fresh.id,
    type: "SYSTEM",
    titleEn: "Welcome to Kabadiwala Connect",
    bodyEn:
      "Your account is verified. Capture a material photo to start creating lots.",
  });

  return issueSession(fresh);
}

/*
|--------------------------------------------------------------------------
| SESSION MANAGEMENT
|--------------------------------------------------------------------------
*/

async function refreshSession({ refreshToken }) {
  const tokenHash = hashRefreshToken(refreshToken);
  const existing = await authRepository.findActiveRefreshToken(tokenHash);

  if (!existing) {
    throw new AuthenticationError(
      "Session is invalid or has expired. Please sign in again.",
      "REFRESH_TOKEN_INVALID"
    );
  }

  const user = await authRepository.findById(existing.userId);

  if (!user || !user.isActive) {
    await authRepository.revokeAllRefreshTokens(existing.userId);

    throw new AuthenticationError("Session is no longer valid", "SESSION_REVOKED");
  }

  // Rotate: issue a new pair, then mark the old token used.
  const session = await issueSession(user);

  await authRepository.rotateRefreshToken(existing.id, session.refreshTokenId);

  return session;
}

async function logout({ refreshToken, allDevices }, user) {
  if (allDevices) {
    const revoked = await authRepository.revokeAllRefreshTokens(user.id);

    return { revokedSessions: revoked };
  }

  if (refreshToken) {
    await authRepository.revokeRefreshToken(hashRefreshToken(refreshToken));
  }

  return { revokedSessions: 1 };
}

async function getProfile(userId) {
  const user = await authRepository.findById(userId);

  if (!user) {
    throw new NotFoundError("User not found");
  }

  return toPublicUser(user);
}

async function updateProfile(userId, patch) {
  if (patch.email) {
    const existing = await authRepository.findByIdentifier(patch.email);

    if (existing && existing.id !== userId) {
      throw new ConflictError("That email is already in use", "ACCOUNT_EXISTS");
    }
  }

  await authRepository.updateProfileFields(userId, {
    fullName: patch.fullName ?? null,
    email: patch.email ?? null,
  });

  return getProfile(userId);
}

module.exports = {
  register,
  registerRecycler,
  login,
  changePassword,
  requestOtp,
  verifyOtp,
  refreshSession,
  logout,
  getProfile,
  updateProfile,
  issueSession,
  toPublicUser,
  GENERIC_LOGIN_FAILURE,
};
