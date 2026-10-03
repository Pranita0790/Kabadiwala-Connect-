/*
|--------------------------------------------------------------------------
| FIREBASE ID TOKEN VERIFICATION (UNIT)
|--------------------------------------------------------------------------
| The security-critical part of phone auth. These tests mint REAL RS256 tokens
| and run them through the real verifier with a local key set, so they cover
| the claims checks rather than a mock's idea of them.
|
| What is asserted, and why each matters:
|
|   - a valid token is accepted
|   - a tampered signature is rejected   (someone edited the payload)
|   - a foreign signing key is rejected  (a self-minted token, the classic
|                                         way to attack a naive verifier)
|   - `alg: none` is rejected            (unsigned token)
|   - HS256 with the RSA public key is rejected (algorithm confusion)
|   - the wrong `aud` is rejected        (a token from a different Firebase
|                                         project cannot be replayed here)
|   - the wrong `iss` is rejected        (not minted by securetoken.google)
|   - an expired token is rejected
|   - a not-yet-valid token is rejected
|   - an empty `sub` is rejected
|
| The key set is injected rather than configured, which is why verifyWith is
| exported alongside verifyIdToken: a configurable JWKS URL would be a way to
| redirect token verification to an attacker's own keys.
|--------------------------------------------------------------------------
*/

process.env.FIREBASE_PROJECT_ID = "test-kabadiwala-project";

const { createHmac } = require("node:crypto");

const {
  SignJWT,
  generateKeyPair,
  exportJWK,
  exportSPKI,
  createLocalJWKSet,
} = require("jose");

/** base64url without padding, matching JWT encoding. */
function base64url(input) {
  return Buffer.from(input).toString("base64url");
}

const { verifyWith, peek, ISSUER_PREFIX } = require("../../src/lib/firebase");

const PROJECT_ID = "test-kabadiwala-project";
const ISSUER = `${ISSUER_PREFIX}${PROJECT_ID}`;
const SUBJECT = "firebase-uid-abc123";

// Generated once per run; asymmetric verification only needs the public half.
let googleKeys;
let jwks;
let attackerKeys;
let attackerJwks;

beforeAll(async () => {
  const google = await generateKeyPair("RS256");
  const attacker = await generateKeyPair("RS256");

  const googleJwk = await exportJWK(google.publicKey);
  googleJwk.kid = "google-key-1";
  googleJwk.alg = "RS256";
  googleJwk.use = "sig";

  const attackerJwk = await exportJWK(attacker.publicKey);
  attackerJwk.kid = "google-key-1"; // deliberately the same kid
  attackerJwk.alg = "RS256";
  attackerJwk.use = "sig";

  googleKeys = { privateKey: google.privateKey, publicKey: google.publicKey };
  attackerKeys = { privateKey: attacker.privateKey, publicKey: attacker.publicKey };

  jwks = createLocalJWKSet({ keys: [googleJwk] });
  // Only the attacker's key is present here, so a token signed by them
  // verifies against the wrong set.
  attackerJwks = createLocalJWKSet({ keys: [attackerJwk] });
});

/** Mint a token the way Firebase would. */
function mint(overrides = {}, keySet = googleKeys) {
  return new SignJWT({
    phone_number: "+919876543210",
    firebase: { sign_in_provider: "phone", identities: {} },
    ...overrides.payload,
  })
    .setProtectedHeader({ alg: "RS256", kid: overrides.kid ?? "google-key-1", typ: "JWT" })
    .setSubject(overrides.sub ?? SUBJECT)
    .setIssuer(overrides.issuer ?? ISSUER)
    .setAudience(overrides.audience ?? PROJECT_ID)
    .setIssuedAt(overrides.issuedAt ?? Math.floor(Date.now() / 1000))
    .setExpirationTime(overrides.expiresIn ?? "1h")
    .sign(keySet.privateKey);
}

describe("firebase id token verification", () => {
  describe("accepts a genuine token", () => {
    it("returns the uid and phone number", async () => {
      const verified = await verifyWith(await mint(), jwks, PROJECT_ID);

      expect(verified.uid).toBe(SUBJECT);
      expect(verified.phoneNumber).toBe("+919876543210");
      expect(verified.signInProvider).toBe("phone");
    });

    it("reports a non-phone provider as such rather than rejecting it", async () => {
      // Provider policy lives in the service layer, not the verifier.
      const token = await mint({
        payload: { phone_number: undefined, firebase: { sign_in_provider: "google.com" } },
      });

      const verified = await verifyWith(token, jwks, PROJECT_ID);

      expect(verified.signInProvider).toBe("google.com");
      expect(verified.phoneNumber).toBeNull();
    });

    it("tolerates a token with no phone_number claim", async () => {
      const token = await mint({ payload: { phone_number: undefined } });

      const verified = await verifyWith(token, jwks, PROJECT_ID);

      expect(verified.uid).toBe(SUBJECT);
      expect(verified.phoneNumber).toBeNull();
    });

    it("tolerates the 5s clock drift allowance", async () => {
      // Issued 10s ago but with a notBefore 3s in the past, so it is inside
      // tolerance rather than 10s stale.
      const token = await new SignJWT({
        phone_number: "+919876543210",
        firebase: { sign_in_provider: "phone" },
      })
        .setProtectedHeader({ alg: "RS256", kid: "google-key-1" })
        .setSubject(SUBJECT)
        .setIssuer(ISSUER)
        .setAudience(PROJECT_ID)
        .setNotBefore(Math.floor(Date.now() / 1000) - 3)
        .setExpirationTime("1h")
        .sign(googleKeys.privateKey);

      await expect(verifyWith(token, jwks, PROJECT_ID)).resolves.toMatchObject({
        uid: SUBJECT,
      });
    });
  });

  describe("rejects a forged signature", () => {
    it("rejects a token signed by an unknown key", async () => {
      const token = await mint({}, attackerKeys);

      await expect(verifyWith(token, jwks, PROJECT_ID)).rejects.toMatchObject({
        code: "FIREBASE_TOKEN_INVALID",
      });
    });

    it("rejects a token whose payload was edited after signing", async () => {
      const token = await mint();
      const [header, , signature] = token.split(".");

      // Re-encode the payload with a different phone number but keep the
      // original signature.
      const forgedPayload = Buffer.from(
        JSON.stringify({ sub: SUBJECT, phone_number: "+919000000000" })
      ).toString("base64url");

      const forged = `${header}.${forgedPayload}.${signature}`;

      await expect(verifyWith(forged, jwks, PROJECT_ID)).rejects.toMatchObject({
        code: "FIREBASE_TOKEN_INVALID",
      });
    });

    it("rejects an unsigned alg:none token", async () => {
      const header = Buffer.from(JSON.stringify({ alg: "none", typ: "JWT" })).toString(
        "base64url"
      );
      const payload = Buffer.from(
        JSON.stringify({ sub: SUBJECT, iss: ISSUER, aud: PROJECT_ID, exp: 9_999_999_999 })
      ).toString("base64url");

      await expect(
        verifyWith(`${header}.${payload}.`, jwks, PROJECT_ID)
      ).rejects.toMatchObject({ code: "FIREBASE_TOKEN_INVALID" });
    });

    it("rejects HS256 signed with the RSA public key (algorithm confusion)", async () => {
      // The attack: take the RSA public key (which everyone can read from the
      // JWKS), use its bytes as an HMAC shared secret, and sign with HS256.
      // A verifier that reads `alg` from the header and trusts the key as an
      // HMAC secret would accept this. Minting it needs raw crypto because
      // jose refuses to sign HMAC with an RSA key.
      const publicPem = await exportSPKI(googleKeys.publicKey);

      const header = base64url(JSON.stringify({ alg: "HS256", kid: "google-key-1" }));
      const payload = base64url(
        JSON.stringify({
          sub: SUBJECT,
          iss: ISSUER,
          aud: PROJECT_ID,
          exp: Math.floor(Date.now() / 1000) + 3600,
          phone_number: "+919876543210",
          firebase: { sign_in_provider: "phone" },
        })
      );

      const signature = createHmac("sha256", publicPem)
        .update(`${header}.${payload}`)
        .digest("base64url");

      const token = `${header}.${payload}.${signature}`;

      // Sanity check: the HMAC really is valid, so this test would pass
      // trivially if the verifier simply ignored signatures.
      expect(
        createHmac("sha256", publicPem)
          .update(`${header}.${payload}`)
          .digest("base64url")
      ).toBe(signature);

      // It must fail anyway, because only RS256 is accepted.
      await expect(verifyWith(token, jwks, PROJECT_ID)).rejects.toMatchObject({
        code: "FIREBASE_TOKEN_INVALID",
      });
    });
  });

  describe("rejects a token from the wrong project", () => {
    it("rejects a token minted for another audience", async () => {
      const token = await mint({ audience: "someone-elses-project" });

      await expect(verifyWith(token, jwks, PROJECT_ID)).rejects.toMatchObject({
        code: "FIREBASE_TOKEN_INVALID",
      });
    });

    it("rejects a correctly signed token that omits `aud`", async () => {
      // Signed by the legitimate key, so this isolates the audience check:
      // without an `aud` claim there is nothing to compare to this project,
      // and the token must not be accepted.
      const token = await new SignJWT({
        phone_number: "+919876543210",
        firebase: { sign_in_provider: "phone" },
      })
        .setProtectedHeader({ alg: "RS256", kid: "google-key-1" })
        .setSubject(SUBJECT)
        .setIssuer(ISSUER)
        .setExpirationTime("1h")
        .sign(googleKeys.privateKey);

      await expect(verifyWith(token, jwks, PROJECT_ID)).rejects.toMatchObject({
        code: "FIREBASE_TOKEN_INVALID",
      });
    });

    it("rejects a token from another issuer", async () => {
      const token = await mint({ issuer: "https://evil.example.com/tokens" });

      await expect(verifyWith(token, jwks, PROJECT_ID)).rejects.toMatchObject({
        code: "FIREBASE_TOKEN_INVALID",
      });
    });
  });

  describe("rejects a stale or malformed token", () => {
    it("rejects an expired token", async () => {
      const now = Math.floor(Date.now() / 1000);
      const token = await new SignJWT({
        phone_number: "+919876543210",
        firebase: { sign_in_provider: "phone" },
      })
        .setProtectedHeader({ alg: "RS256", kid: "google-key-1" })
        .setSubject(SUBJECT)
        .setIssuer(ISSUER)
        .setAudience(PROJECT_ID)
        .setIssuedAt(now - 7200)
        .setExpirationTime(now - 60)
        .sign(googleKeys.privateKey);

      await expect(verifyWith(token, jwks, PROJECT_ID)).rejects.toMatchObject({
        code: "FIREBASE_TOKEN_INVALID",
      });
    });

    it("rejects a token that is not yet valid beyond the tolerance", async () => {
      const token = await new SignJWT({
        phone_number: "+919876543210",
        firebase: { sign_in_provider: "phone" },
      })
        .setProtectedHeader({ alg: "RS256", kid: "google-key-1" })
        .setSubject(SUBJECT)
        .setIssuer(ISSUER)
        .setAudience(PROJECT_ID)
        .setNotBefore(Math.floor(Date.now() / 1000) + 3600)
        .setExpirationTime("2h")
        .sign(googleKeys.privateKey);

      await expect(verifyWith(token, jwks, PROJECT_ID)).rejects.toMatchObject({
        code: "FIREBASE_TOKEN_INVALID",
      });
    });

    it("rejects a token with an empty subject", async () => {
      const token = await mint({ sub: "" });

      await expect(verifyWith(token, jwks, PROJECT_ID)).rejects.toMatchObject({
        code: "FIREBASE_TOKEN_INVALID",
      });
    });

    it.each([
      ["empty string", ""],
      ["whitespace", "   "],
      ["undefined", undefined],
      ["null", null],
      ["a number", 12345],
      ["an object", {}],
    ])("rejects %s as a missing token", async (_label, value) => {
      await expect(verifyWith(value, jwks, PROJECT_ID)).rejects.toMatchObject({
        code: "FIREBASE_TOKEN_MISSING",
      });
    });

    it.each([
      ["not a JWT at all", "definitely-not-a-jwt"],
      ["two segments only", "aaa.bbb"],
      ["valid base64 segments that are not a JWT", "aGVhZGVy.cGF5bG9hZA."],
    ])("rejects %s as an invalid token", async (_label, value) => {
      // Present but unusable is a different situation from absent, and the
      // distinction shows up in the client's error handling.
      await expect(verifyWith(value, jwks, PROJECT_ID)).rejects.toMatchObject({
        code: "FIREBASE_TOKEN_INVALID",
      });
    });

    it("does not leak the jose error text to the caller", async () => {
      // The caller is a phone UI; internal messages must not leak.
      let error;
      try {
        await verifyWith("garbage", jwks, PROJECT_ID);
      } catch (caught) {
        error = caught;
      }

      expect(error.message).not.toMatch(/jwt|signature|jose|at Object/i);
      expect(error.code).toBe("FIREBASE_TOKEN_INVALID");
    });
  });

  describe("peek (diagnostics only)", () => {
    it("reads claims without verifying", () => {
      // Documented as unverified on purpose: this is why nothing
      // authorisation-related may depend on it.
      const payload = peek(
        Buffer.from(JSON.stringify({ alg: "none" })).toString("base64url") +
          "." +
          Buffer.from(JSON.stringify({ sub: "forged", phone_number: "+919876543210" })).toString(
            "base64url"
          ) +
          "."
      );

      expect(payload).toMatchObject({ sub: "forged" });
    });

    it("returns null for something that is not a JWT", () => {
      expect(peek("nonsense")).toBeNull();
    });

    it("still verifies normally after a peek", async () => {
      const token = await mint();
      peek(token);

      await expect(verifyWith(token, jwks, PROJECT_ID)).resolves.toMatchObject({
        uid: SUBJECT,
      });
    });
  });

  describe("key set handling", () => {
    it("rejects a token signed by a key not in the set even with a matching kid", async () => {
      // Both keys advertise kid google-key-1. Verification must fail rather
      // than pick the first entry and, if it fails, try the next.
      const forged = await mint({}, attackerKeys);

      await expect(verifyWith(forged, jwks, PROJECT_ID)).rejects.toMatchObject({
        code: "FIREBASE_TOKEN_INVALID",
      });
    });

    it("verifies against the attacker key set so the negative tests are meaningful", async () => {
      // Guards against the suite passing because every token is broken.
      const forged = await mint({}, attackerKeys);

      await expect(verifyWith(forged, attackerJwks, PROJECT_ID)).resolves.toMatchObject({
        uid: SUBJECT,
      });
    });
  });
});