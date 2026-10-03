/*
|--------------------------------------------------------------------------
| FIREBASE PHONE AUTH SERVICE
|--------------------------------------------------------------------------
| Turns a verified Firebase ID token into a platform session.
|
| OWNERSHIP (AGENTS.md section 4)
|
| SMS delivery and code verification belong to Firebase. This service owns
| only what the backend owns: which local account a phone number maps to,
| whether a session may be issued, and the audit trail for the link between
| the Firebase identity and the platform user.
|
| ACCOUNT RESOLUTION ORDER
|
|   1. By Firebase uid. Authoritative — the token's `sub` names the identity.
|   2. By phone number. Links a pre-existing password account to Firebase on
|      first phone sign-in.
|   3. Create a new collector account. Phone-first sign-up.
|
| The uid is consulted first on purpose. Falling back to the phone claim
| first would let a reassigned or recycled number silently inherit an
| existing account's lots and earnings.
|
| TRUST BOUNDARY
|
| Firebase proves the device completed SMS verification. It does not prove
| the SIM holder is the rightful owner, so this endpoint deliberately does not
| grant anything a phone number alone should not grant: recycler
| authorisation and settlement approval remain separate, human steps.
 *-------------------------------------------------------------------------
*/

const firebase = require("../../lib/firebase");
const authRepository = require("./auth.repository");
const notificationService = require("../notifications/notifications.service");
const logger = require("../../lib/logger");
const config = require("../../config/env");
const { userRole } = require("../../config/constants");
const { normalisePhone } = require("./auth.schema");
const {
  AuthenticationError,
  ConflictError,
} = require("../../lib/errors");

/*
|--------------------------------------------------------------------------
| HELPERS
|--------------------------------------------------------------------------
*/

/**
 * Firebase sends E.164 (e.g. +919876543210). Reuse the signup normaliser so
 * a number typed by hand and one asserted by Firebase cannot end up stored
 * as two different strings.
 */
function phoneFromToken(firebasePhone) {
  if (!firebasePhone) {
    throw new AuthenticationError(
      "This sign-in did not include a phone number. Use phone sign-in.",
      "FIREBASE_PHONE_MISSING"
    );
  }

  // normalisePhone returns null for anything that is not an Indian mobile
  // number, including other countries' numbers. Firebase asserts the number
  // is genuine; it does not assert the country.
  const normalised = normalisePhone(firebasePhone);

  if (!normalised) {
    throw new AuthenticationError(
      "That phone number is not supported. An Indian mobile number is required.",
      "PHONE_NOT_SUPPORTED"
    );
  }

  return normalised;
}

/**
 * Fallback display name when the app has not collected one yet.
 *
 * Firebase Phone Auth carries no name. Showing a raw phone number as a name
 * would look like a bug in the dashboard, so this reads as a neutral label
 * that the collector can change in their profile.
 */
function placeholderName(phone) {
  return `Collector ${phone.slice(-4)}`;
}

/*
|--------------------------------------------------------------------------
| ENTRY POINT
|--------------------------------------------------------------------------
*/

/**
 * Verify a Firebase ID token and issue a platform session.
 *
 * @param {string} idToken  Firebase ID token from the device
 * @param {object} context
 * @param {string} [context.fullName] Collected during first sign-up
 * @param {string} [context.userAgent]
 * @param {string} [context.ipAddress]
 * @returns {Promise<{accessToken, refreshToken, expiresInSeconds, user}>}
 */
async function signInWithIdToken(
  idToken,
  { fullName, userAgent, ipAddress } = {}
) {
  const verified = await firebase.verifyIdToken(idToken);

  // A token from a provider other than phone auth does not prove control of
  // a phone number, and this service is only authorised to map phone numbers
  // to accounts.
  if (verified.signInProvider && verified.signInProvider !== "phone") {
    logger.warn("Rejected non-phone Firebase sign-in", {
      provider: verified.signInProvider,
      uid: verified.uid,
    });

    throw new AuthenticationError(
      "Sign in with your phone number to continue.",
      "FIREBASE_PROVIDER_NOT_ALLOWED"
    );
  }

  const phone = phoneFromToken(verified.phoneNumber);

  const { user, created } = await resolveUser({
    firebaseUid: verified.uid,
    phone,
    fullName,
  });

  if (!user.isActive) {
    throw new AuthenticationError(
      "Account is deactivated",
      "ACCOUNT_INACTIVE"
    );
  }

  // Firebase has already verified the phone number, so the account counts as
  // verified even if it was created by an earlier password sign-up that never
  // completed email confirmation.
  if (!user.isVerified) {
    await authRepository.setVerified(user.id);
  }

  await authRepository.recordLogin(user.id);

  const fresh = await authRepository.findById(user.id);

  if (created) {
    await notificationService.create({
      userId: fresh.id,
      type: "SYSTEM",
      titleEn: "Welcome to Kabadiwala Connect",
      bodyEn:
        "Your account is ready. Capture a material photo to start creating lots.",
    });

    logger.info("Collector account created via Firebase phone auth", {
      userId: fresh.publicId,
      uid: verified.uid,
    });
  }

  logger.info("Firebase phone sign-in", {
    userId: fresh.publicId,
    uid: verified.uid,
    created,
  });

  const { issueSession } = require("./auth.service");
  const session = await issueSession(fresh, { userAgent, ipAddress });

  return { ...session, created, user: fresh };
}

/*
|--------------------------------------------------------------------------
| ACCOUNT RESOLUTION
|--------------------------------------------------------------------------
*/

async function resolveUser({ firebaseUid, phone, fullName }) {
  // 1. Already linked.
  const byUid = await authRepository.findByFirebaseUid(firebaseUid);

  if (byUid) {
    // Guard against a stale local phone number: Firebase is authoritative
    // for the number, so keep the two in step.
    if (byUid.phone !== phone) {
      logger.info("Updating phone number from Firebase", {
        userId: byUid.publicId,
      });

      await authRepository.updatePhone(byUid.id, phone);
    }

    const refreshed = await authRepository.findById(byUid.id);

    return { user: refreshed, created: false };
  }

  // 2. Existing account with this number — link it.
  const byPhone = await authRepository.findByIdentifier(phone);

  if (byPhone) {
    if (byPhone.firebaseUid && byPhone.firebaseUid !== firebaseUid) {
      // The number is already tied to a different Firebase identity. This is
      // the recycled-number case, and it must not be allowed to continue.
      logger.warn("Phone already linked to a different Firebase uid", {
        userId: byPhone.publicId,
      });

      throw new ConflictError(
        "This phone number is already linked to another sign-in. " +
          "Contact support to recover the account.",
        "PHONE_LINK_CONFLICT"
      );
    }

    await authRepository.linkFirebaseUid(byPhone.id, firebaseUid);

    const linked = await authRepository.findById(byPhone.id);

    return { user: linked, created: false };
  }

  // 3. First sign-in: create a collector account.
  const created = await authRepository.createUser({
    phone,
    fullName: (fullName && fullName.trim()) || placeholderName(phone),
    role: userRole.COLLECTOR,
    // Firebase has already verified the number.
    isVerified: true,
    // No password: this account signs in through Firebase. login() must
    // tolerate a null password_hash as a result.
    passwordHash: null,
    firebaseUid,
  });

  return { user: created, created: true };
}

/**
 * Whether the collector finished onboarding.
 *
 * The client uses this to decide between the profile form and the home
 * screen after a successful sign-in.
 */
function isOnboarded(user) {
  return Boolean(user.fullName && !user.fullName.startsWith("Collector "));
}

module.exports = {
  signInWithIdToken,
  isOnboarded,
  phoneFromToken,
  placeholderName,
  isFirebaseEnabled: firebase.isEnabled,
  placeholderMessage: config.isProduction
    ? null
    : "FIREBASE_PROJECT_ID is not set; phone sign-in is disabled.",
};