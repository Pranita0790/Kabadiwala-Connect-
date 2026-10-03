-- =====================================================================
-- 008 — Firebase Phone Auth linkage
--
-- Firebase verifies the SMS code on the device and hands the app a Firebase
-- ID token; this backend verifies that token and then needs to know which
-- Firebase account it belongs to.
--
-- firebase_uid stores the Firebase `sub` claim. It is unique so the same
-- Firebase identity cannot be linked to two platform accounts, and it makes
-- the link auditable when a collector disputes who signed in.
--
-- Deliberately NOT added:
--
--   - a service-account secret, private key, or admin SDK credential.
--     Verification uses Google's public certificates, so none is needed, and
--     committing one would be a credential leak (AGENTS.md section 9).
--
--   - a NOT NULL constraint. Password accounts are created before any
--     Firebase sign-in, so the column has to stay nullable. Accounts that
--     have only ever used Firebase are left without a password_hash, which
--     the auth service must therefore tolerate.
-- =====================================================================

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS firebase_uid TEXT;

-- Case-sensitive and unique. NULLs are excluded from uniqueness in
-- PostgreSQL by default, so many password-only accounts can coexist.
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_firebase_uid
  ON users (firebase_uid)
  WHERE firebase_uid IS NOT NULL;

COMMENT ON COLUMN users.firebase_uid IS
  'Firebase Identity Platform user id (the ID token `sub` claim) for phone sign-in';