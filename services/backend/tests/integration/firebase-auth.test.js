/*
|--------------------------------------------------------------------------
| FIREBASE PHONE AUTH INTEGRATION
|--------------------------------------------------------------------------
| Covers the rules AGENTS.md sections 7 and 14 require for auth:
|
| - a token that Firebase did not verify is rejected before any DB write
| - account resolution prefers the Firebase uid over the phone claim
| - an existing password account is linked, not duplicated
| - a first sign-in creates a verified collector
| - a recycled phone number cannot inherit an existing account
| - session tokens are minted from the resolved account
|
| The JWKS fetch itself cannot be exercised offline, so lib/firebase is
| replaced at the module boundary. What IS tested here is the backend's own
| logic on top of a "Firebase says this" result, which is where the security
| decisions actually live.
|
| Verification of the signature/audience/issuer is covered separately by
| tests/unit/firebase-token.test.js, which builds real RSA-signed tokens
| against a local JWKS.
|--------------------------------------------------------------------------
*/

// Must be replaced before the service graph loads the real implementation.
jest.mock("../../src/lib/firebase", () => {
  const actual = jest.requireActual("../../src/lib/firebase");

  return { ...actual, verifyIdToken: jest.fn(), isEnabled: jest.fn(() => true) };
});

const firebase = require("../../src/lib/firebase");
const {
  describeIntegration,
  resetDb,
  createUser,
  teardown,
} = require("../helpers/db");

const firebaseAuthService = require("../../src/modules/auth/firebase-auth.service");
const authRepository = require("../../src/modules/auth/auth.repository");
const { queryOne, queryRows } = require("../../src/db/query");

describeIntegration("firebase phone auth", () => {
  beforeEach(async () => {
    await resetDb();
    firebase.verifyIdToken.mockReset();
    firebase.isEnabled.mockReturnValue(true);
  });

  afterAll(teardown);

  /** Make Firebase "verify" this token and report this phone number. */
  function asFirebaseVerified({ uid = "firebase-uid-1", phone = "+919876543210" } = {}) {
    firebase.verifyIdToken.mockResolvedValue({
      uid,
      phoneNumber: phone,
      email: null,
      emailVerified: false,
      signInProvider: "phone",
      claims: { sub: uid },
    });
  }

  async function userByPhone(phone) {
    const row = await queryOne(
      "SELECT id, phone, firebase_uid, role, is_verified, full_name, password_hash FROM users WHERE phone = $1",
      [phone]
    );
    return row;
  }

  /*
  |--------------------------------------------------------------------------
  | ACCOUNT RESOLUTION
  |--------------------------------------------------------------------------
  */

  describe("account resolution", () => {
    it("creates a verified collector on first sign-in", async () => {
      asFirebaseVerified();

      const result = await firebaseAuthService.signInWithIdToken("token");

      expect(result.created).toBe(true);
      expect(result.accessToken).toEqual(expect.any(String));
      expect(result.refreshToken).toEqual(expect.any(String));

      const row = await userByPhone("+919876543210");
      expect(row.role).toBe("COLLECTOR");
      // Firebase already verified the number.
      expect(row.is_verified).toBe(true);
      expect(row.firebase_uid).toBe("firebase-uid-1");
      // Phone-first sign-in sets no password.
      expect(row.password_hash).toBeNull();
    });

    it("reuses the account on a second sign-in instead of creating another", async () => {
      asFirebaseVerified();
      await firebaseAuthService.signInWithIdToken("token");

      asFirebaseVerified();
      const second = await firebaseAuthService.signInWithIdToken("token");

      expect(second.created).toBe(false);
      expect(second.user.publicId).toBeTruthy();

      const rows = await queryRows(
        "SELECT id FROM users WHERE phone = $1",
        ["+919876543210"]
      );
      expect(rows).toHaveLength(1);
    });

    it("links an existing password account rather than duplicating it", async () => {
      // A collector who registered the old way, before Firebase.
      const existingId = await createUser({ phone: "+919876543210" });

      asFirebaseVerified();
      const result = await firebaseAuthService.signInWithIdToken("token");

      expect(result.created).toBe(false);
      expect(result.user.id).toBe(existingId);

      const row = await userByPhone("+919876543210");
      expect(row.firebase_uid).toBe("firebase-uid-1");
    });

    it("preserves an existing password hash when linking", async () => {
      // A password account created the old way.
      const existingId = await createUser({ phone: "+919876543210" });

      const { queryOne: q } = require("../../src/db/query");
      await q(
        "UPDATE users SET password_hash = $2 WHERE id = $1",
        [existingId, "$2b$10$abcdefghijklmnopqrstuv"]
      );

      asFirebaseVerified();
      await firebaseAuthService.signInWithIdToken("token");

      const row = await userByPhone("+919876543210");
      expect(row.password_hash).toBe("$2b$10$abcdefghijklmnopqrstuv");
    });

    it("does not overwrite an existing account name on a later sign-in", async () => {
      await createUser({ phone: "+919876543210", fullName: "Asha Patil" });

      asFirebaseVerified({ uid: "firebase-uid-1" });
      await firebaseAuthService.signInWithIdToken("token", { fullName: "Someone Else" });

      const row = await userByPhone("+919876543210");
      expect(row.full_name).toBe("Asha Patil");
    });

    it("refuses to let a recycled phone number inherit a linked account", async () => {
      // The number was linked to one Firebase identity...
      asFirebaseVerified({ uid: "firebase-uid-1" });
      await firebaseAuthService.signInWithIdToken("token");

      // ...and now a *different* Firebase identity claims the same number.
      asFirebaseVerified({ uid: "firebase-uid-2" });

      await expect(
        firebaseAuthService.signInWithIdToken("token")
      ).rejects.toMatchObject({ code: "PHONE_LINK_CONFLICT" });
    });

    it("does not write a second user when a link conflict occurs", async () => {
      asFirebaseVerified({ uid: "firebase-uid-1" });
      await firebaseAuthService.signInWithIdToken("token");

      asFirebaseVerified({ uid: "firebase-uid-2" });
      await firebaseAuthService
        .signInWithIdToken("token")
        .catch(() => {});

      const rows = await queryRows(
        "SELECT id FROM users WHERE phone = $1",
        ["+919876543210"]
      );
      expect(rows).toHaveLength(1);
    });
  });

  /*
  |--------------------------------------------------------------------------
  | TRUST BOUNDARY
  |--------------------------------------------------------------------------
  */

  describe("token trust boundary", () => {
    it("rejects a non-phone Firebase provider", async () => {
      firebase.verifyIdToken.mockResolvedValue({
        uid: "google-uid",
        phoneNumber: "+919876543210",
        email: "someone@example.com",
        emailVerified: true,
        signInProvider: "google.com",
        claims: {},
      });

      await expect(
        firebaseAuthService.signInWithIdToken("token")
      ).rejects.toMatchObject({ code: "FIREBASE_PROVIDER_NOT_ALLOWED" });

      // And crucially: nothing was persisted.
      const rows = await queryRows("SELECT id FROM users");
      expect(rows).toHaveLength(0);
    });

    it("rejects a token carrying no phone number", async () => {
      firebase.verifyIdToken.mockResolvedValue({
        uid: "uid",
        phoneNumber: null,
        email: null,
        emailVerified: false,
        signInProvider: "phone",
        claims: {},
      });

      await expect(
        firebaseAuthService.signInWithIdToken("token")
      ).rejects.toMatchObject({ code: "FIREBASE_PHONE_MISSING" });
    });

    it("rejects a non-Indian phone number", async () => {
      asFirebaseVerified({ phone: "+14155552671" });

      await expect(
        firebaseAuthService.signInWithIdToken("token")
      ).rejects.toMatchObject({ code: "PHONE_NOT_SUPPORTED" });

      const rows = await queryRows("SELECT id FROM users");
      expect(rows).toHaveLength(0);
    });

    it("does not create a user when verification fails", async () => {
      const { AuthenticationError } = require("../../src/lib/errors");

      firebase.verifyIdToken.mockRejectedValue(
        new AuthenticationError("nope", "FIREBASE_TOKEN_INVALID")
      );

      await expect(
        firebaseAuthService.signInWithIdToken("bad-token")
      ).rejects.toMatchObject({ code: "FIREBASE_TOKEN_INVALID" });

      const rows = await queryRows("SELECT id FROM users");
      expect(rows).toHaveLength(0);
    });

    it("reports a configuration fault as FIREBASE_NOT_CONFIGURED, not a bad token", async () => {
      // The real verifier throws this when FIREBASE_PROJECT_ID is unset, so
      // that a misconfigured server is not mistaken for a rejected credential.
      // It is a 503: the caller's token may be perfectly valid.
      const { ServiceUnavailableError } = require("../../src/lib/errors");

      firebase.verifyIdToken.mockRejectedValue(
        new ServiceUnavailableError(
          "Phone sign-in is not configured on this server.",
          "FIREBASE_NOT_CONFIGURED"
        )
      );

      await expect(
        firebaseAuthService.signInWithIdToken("token")
      ).rejects.toMatchObject({
        code: "FIREBASE_NOT_CONFIGURED",
        status: 503,
      });
    });
  });

  /*
  |--------------------------------------------------------------------------
  | ACCOUNT STATE
  |--------------------------------------------------------------------------
  */

  describe("account state", () => {
    it("blocks a deactivated account even with a valid token", async () => {
      asFirebaseVerified();
      await firebaseAuthService.signInWithIdToken("token");

      await require("../../src/db/query").query(
        "UPDATE users SET is_active = FALSE WHERE phone = $1",
        ["+919876543210"]
      );

      asFirebaseVerified();
      await expect(
        firebaseAuthService.signInWithIdToken("token")
      ).rejects.toMatchObject({ code: "ACCOUNT_INACTIVE" });
    });

    it("records the sign-in time", async () => {
      asFirebaseVerified();
      await firebaseAuthService.signInWithIdToken("token");

      const row = await queryOne(
        "SELECT last_login_at FROM users WHERE phone = $1",
        ["+919876543210"]
      );

      expect(row.last_login_at).not.toBeNull();
    });

    it("flags a brand new account as needing a profile", async () => {
      asFirebaseVerified();

      const result = await firebaseAuthService.signInWithIdToken("token");

      expect(firebaseAuthService.isOnboarded(result.user)).toBe(false);
    });

    it("does not flag an account as needing a profile once named", async () => {
      await createUser({ phone: "+919876543210", fullName: "Asha Patil" });
      asFirebaseVerified();

      const result = await firebaseAuthService.signInWithIdToken("token");

      expect(firebaseAuthService.isOnboarded(result.user)).toBe(true);
    });
  });

  /*
  |--------------------------------------------------------------------------
  | UID LOOKUP PRECEDENCE
  |--------------------------------------------------------------------------
  */

  describe("uid lookup precedence", () => {
    it("resolves by uid even when the local phone number has drifted", async () => {
      asFirebaseVerified({ uid: "uid-1", phone: "+919876543210" });
      await firebaseAuthService.signInWithIdToken("token");

      // Firebase now reports a different number for the same identity.
      asFirebaseVerified({ uid: "uid-1", phone: "+919999999999" });
      const result = await firebaseAuthService.signInWithIdToken("token");

      expect(result.created).toBe(false);
      expect(result.user.phone).toBe("+919999999999");
    });

    it("does not create a duplicate when the uid matches but the number changed", async () => {
      asFirebaseVerified({ uid: "uid-1", phone: "+919876543210" });
      await firebaseAuthService.signInWithIdToken("token");

      asFirebaseVerified({ uid: "uid-1", phone: "+919999999999" });
      await firebaseAuthService.signInWithIdToken("token");

      const rows = await queryRows("SELECT id FROM users");
      expect(rows).toHaveLength(1);
    });
  });

  /*
  |--------------------------------------------------------------------------
  | REPOSITORY
  |--------------------------------------------------------------------------
  */

  describe("repository", () => {
    it("finds a user by firebase uid", async () => {
      asFirebaseVerified();
      await firebaseAuthService.signInWithIdToken("token");

      const found = await authRepository.findByFirebaseUid("firebase-uid-1");

      expect(found).not.toBeNull();
      expect(found.phone).toBe("+919876543210");
    });

    it("returns null for an unknown firebase uid", async () => {
      expect(await authRepository.findByFirebaseUid("nope")).toBeNull();
    });

    it("refuses to link one firebase uid to two accounts", async () => {
      const first = await createUser({ phone: "+919876543210" });
      const second = await createUser({ phone: "+919876543211" });

      expect(await authRepository.linkFirebaseUid(first, "shared-uid")).toBe(true);
      // Second link must not overwrite the first.
      expect(await authRepository.linkFirebaseUid(second, "shared-uid")).toBe(false);

      expect(await authRepository.findByFirebaseUid("shared-uid")).not.toBeNull();
      expect(
        (await authRepository.findByPublicId(
          (await authRepository.findByFirebaseUid("shared-uid")).publicId
        )).id
      ).toBe(first);
    });

    it("does not steal a phone number that another account holds", async () => {
      const keeper = await createUser({ phone: "+919876543210" });
      const other = await createUser({ phone: "+919876543211" });

      const updated = await authRepository.updatePhone(other, "+919876543210");

      expect(updated).toBe(false);
      expect((await authRepository.findById(keeper)).phone).toBe("+919876543210");
    });
  });
});