/*
|--------------------------------------------------------------------------
| AUTH REPOSITORY
|--------------------------------------------------------------------------
| All SQL for the identity tables. No business rules live here.
|
| Mapping note: `public_id` is the identifier exposed in tokens and API
| responses. The internal `id` is never sent to a client, so a leaked
| primary key cannot be used to address a record directly.
|--------------------------------------------------------------------------
*/

const { queryRows, queryOne, insertOne, transaction } = require("../../db/query");

const USER_COLUMNS = `
  u.id,
  u.public_id,
  u.phone,
  u.email,
  u.password_hash,
  u.full_name,
  u.role,
  u.is_active,
  u.is_verified,
  u.last_login_at,
  u.created_at,
  u.firebase_uid
`;

function toUser(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.id,
    publicId: row.public_id,
    phone: row.phone,
    email: row.email,
    // Retained for verification only; never serialised into a response.
    passwordHash: row.password_hash,
    fullName: row.full_name,
    role: row.role,
    isActive: row.is_active,
    isVerified: row.is_verified,
    lastLoginAt: row.last_login_at,
    createdAt: row.created_at,
    firebaseUid: row.firebase_uid ?? null,
    recyclerId: row.recycler_id ?? null,
    organisationName: row.organisation_name ?? null,
  };
}

async function findByPublicId(publicId) {
  const row = await queryOne(
    `SELECT ${USER_COLUMNS}, rp.id AS recycler_id, rp.organisation_name
     FROM users u
     LEFT JOIN recycler_profiles rp ON rp.user_id = u.id
     WHERE u.public_id = $1`,
    [publicId],
    { label: "users:findByPublicId" }
  );

  return toUser(row);
}

async function findById(id) {
  const row = await queryOne(
    `SELECT ${USER_COLUMNS}, rp.id AS recycler_id, rp.organisation_name
     FROM users u
     LEFT JOIN recycler_profiles rp ON rp.user_id = u.id
     WHERE u.id = $1`,
    [id],
    { label: "users:findById" }
  );

  return toUser(row);
}

/**
 * Look up a user by phone OR email in one round trip.
 */
async function findByIdentifier(identifier) {
  const row = await queryOne(
    `SELECT ${USER_COLUMNS}, rp.id AS recycler_id, rp.organisation_name
     FROM users u
     LEFT JOIN recycler_profiles rp ON rp.user_id = u.id
     WHERE u.phone = $1 OR u.email = $1
     LIMIT 1`,
    [identifier],
    { label: "users:findByIdentifier" }
  );

  return toUser(row);
}

async function createUser({
  phone = null,
  email = null,
  passwordHash = null,
  fullName,
  role,
  isVerified = false,
  firebaseUid = null,
}) {
  const row = await insertOne(
    "users",
    {
      phone,
      email,
      password_hash: passwordHash,
      full_name: fullName,
      role,
      is_verified: isVerified,
      firebase_uid: firebaseUid,
    },
    { label: "users:create" }
  );

  return toUser(row);
}

/**
 * Link a Firebase Identity Platform account to an existing platform user.
 *
 * Used when a collector who originally registered with a password signs in
 * with the same phone number via Firebase. The link is written only if the
 * slot is empty, so a later sign-in on another device cannot re-point an
 * already-linked account at a different Firebase identity.
 *
 * @returns {boolean} true if this call performed the link
 */
async function linkFirebaseUid(userId, firebaseUid) {
  const row = await queryOne(
    `UPDATE users
     SET firebase_uid = $2, updated_at = NOW()
     WHERE id = $1
       AND firebase_uid IS NULL
       -- Checked in the WHERE clause as well as by the unique index: the
       -- index would reject the row, which surfaces as a 23505 instead of a
       -- false return the caller can reason about.
       AND NOT EXISTS (
         SELECT 1 FROM users other WHERE other.firebase_uid = $2
       )
     RETURNING id`,
    [userId, firebaseUid],
    { label: "users:linkFirebaseUid" }
  );

  return row !== null;
}

/**
 * Update the phone number recorded against a user.
 *
 * Used when Firebase is authoritative about the number and the stored value
 * has drifted. The write is skipped when the number is already taken by
 * another account, so two identities cannot end up sharing one number.
 */
async function updatePhone(userId, phone) {
  const row = await queryOne(
    `UPDATE users
     SET phone = $2, updated_at = NOW()
     WHERE id = $1
       AND (phone IS DISTINCT FROM $2)
       AND NOT EXISTS (
         SELECT 1 FROM users other
         WHERE other.phone = $2 AND other.id <> $1
       )
     RETURNING id`,
    [userId, phone],
    { label: "users:updatePhone" }
  );

  return row !== null;
}

/**
 * Look a user up by their Firebase uid.
 *
 * This is the authoritative lookup when a device presents an ID token: the
 * token's `sub` identifies a Firebase identity directly, whereas the phone
 * number in the token is only a claim about that identity. Matching on the
 * uid first means a recycled or reassigned phone number cannot inherit an
 * existing account.
 */
async function findByFirebaseUid(firebaseUid) {
  const row = await queryOne(
    `SELECT ${USER_COLUMNS} FROM users u WHERE u.firebase_uid = $1`,
    [firebaseUid],
    { label: "users:findByFirebaseUid" }
  );

  return toUser(row);
}

async function updatePasswordHash(userId, passwordHash) {
  await queryRows(
    `UPDATE users
     SET password_hash = $2, is_verified = TRUE, updated_at = NOW()
     WHERE id = $1
     RETURNING id`,
    [userId, passwordHash],
    { label: "users:updatePassword" }
  );
}

async function setVerified(userId) {
  await queryRows(
    "UPDATE users SET is_verified = TRUE, updated_at = NOW() WHERE id = $1 RETURNING id",
    [userId],
    { label: "users:setVerified" }
  );
}

async function recordLogin(userId) {
  await queryRows(
    "UPDATE users SET last_login_at = NOW() WHERE id = $1 RETURNING id",
    [userId],
    { label: "users:recordLogin" }
  );
}

/**
 * Update only the fields that were actually supplied; a null is treated as
 * "leave unchanged" so a partial profile update cannot wipe a field.
 */
async function updateProfileFields(userId, { fullName = null, email = null }) {
  await queryRows(
    `UPDATE users
     SET full_name = COALESCE($2, full_name),
         email      = COALESCE($3, email),
         updated_at = NOW()
     WHERE id = $1
     RETURNING id`,
    [userId, fullName, email],
    { label: "users:updateProfile" }
  );
}

/*
|--------------------------------------------------------------------------
| OTP CHALLENGES
|--------------------------------------------------------------------------
*/

async function createOtpChallenge({
  userId,
  channel,
  destination,
  codeHash,
  expiresAt,
  maxAttempts = 5,
}) {
  // Any previous unconsumed challenge for this user is invalidated, so the
  // newest code is always the only valid one.
  await queryRows(
    `UPDATE otp_challenges
     SET consumed_at = NOW()
     WHERE user_id = $1 AND consumed_at IS NULL`,
    [userId],
    { label: "otp:invalidatePrevious" }
  );

  return insertOne(
    "otp_challenges",
    {
      user_id: userId,
      channel,
      destination,
      code_hash: codeHash,
      expires_at: expiresAt,
      max_attempts: maxAttempts,
    },
    { label: "otp:create" }
  );
}

async function findActiveOtpChallenge(userId) {
  const row = await queryOne(
    `SELECT *
     FROM otp_challenges
     WHERE user_id = $1
       AND consumed_at IS NULL
     ORDER BY created_at DESC
     LIMIT 1`,
    [userId],
    { label: "otp:findActive" }
  );

  if (!row) {
    return null;
  }

  return {
    id: row.id,
    userId: row.user_id,
    channel: row.channel,
    destination: row.destination,
    codeHash: row.code_hash,
    attempts: row.attempts,
    maxAttempts: row.max_attempts,
    expiresAt: row.expires_at,
    createdAt: row.created_at,
  };
}

async function incrementOtpAttempts(id) {
  const row = await queryOne(
    `UPDATE otp_challenges
     SET attempts = attempts + 1
     WHERE id = $1
     RETURNING attempts, max_attempts`,
    [id],
    { label: "otp:incrementAttempts" }
  );

  return row;
}

async function consumeOtpChallenge(id) {
  await queryRows(
    "UPDATE otp_challenges SET consumed_at = NOW() WHERE id = $1 RETURNING id",
    [id],
    { label: "otp:consume" }
  );
}

/*
|--------------------------------------------------------------------------
| REFRESH TOKENS
|--------------------------------------------------------------------------
*/

async function storeRefreshToken({
  userId,
  tokenHash,
  expiresAt,
  userAgent = null,
  ipAddress = null,
}) {
  return insertOne(
    "refresh_tokens",
    {
      user_id: userId,
      token_hash: tokenHash,
      expires_at: expiresAt,
      user_agent: userAgent,
      ip_address: ipAddress,
    },
    { label: "refreshTokens:create" }
  );
}

async function findActiveRefreshToken(tokenHash) {
  const row = await queryOne(
    `SELECT *
     FROM refresh_tokens
     WHERE token_hash = $1
       AND revoked_at IS NULL
       AND expires_at > NOW()
     LIMIT 1`,
    [tokenHash],
    { label: "refreshTokens:findActive" }
  );

  if (!row) {
    return null;
  }

  return {
    id: row.id,
    userId: row.user_id,
    expiresAt: row.expires_at,
    createdAt: row.created_at,
  };
}

async function rotateRefreshToken(oldId, newTokenId) {
  await queryRows(
    `UPDATE refresh_tokens
     SET revoked_at = NOW(), replaced_by_id = $2
     WHERE id = $1
     RETURNING id`,
    [oldId, newTokenId],
    { label: "refreshTokens:rotate" }
  );
}

async function revokeRefreshToken(tokenHash) {
  await queryRows(
    `UPDATE refresh_tokens
     SET revoked_at = NOW()
     WHERE token_hash = $1 AND revoked_at IS NULL
     RETURNING id`,
    [tokenHash],
    { label: "refreshTokens:revoke" }
  );
}

async function revokeAllRefreshTokens(userId) {
  const rows = await queryRows(
    `UPDATE refresh_tokens
     SET revoked_at = NOW()
     WHERE user_id = $1 AND revoked_at IS NULL
     RETURNING id`,
    [userId],
    { label: "refreshTokens:revokeAll" }
  );

  return rows.length;
}

/**
 * Register a recycler user together with their organisation profile in one
 * transaction, so a user is never left without a profile.
 */
async function createRecyclerUserWithProfile({
  phone,
  email,
  passwordHash,
  fullName,
  organisationName,
  address = null,
  city = null,
  region = null,
  isAuthorized = false,
}) {
  return transaction(async (client) => {
    const user = await insertOne(
      "users",
      {
        phone,
        email,
        password_hash: passwordHash,
        full_name: fullName,
        role: "RECYCLER",
        is_verified: Boolean(passwordHash),
      },
      { client, label: "users:createRecycler" }
    );

    const profile = await insertOne(
      "recycler_profiles",
      {
        user_id: user.id,
        organisation_name: organisationName,
        address,
        city,
        region,
        is_authorized: isAuthorized,
      },
      { client, label: "recyclerProfiles:create" }
    );

    return {
      user: toUser({ ...user, recycler_id: profile.id }),
    };
  });
}

module.exports = {
  findByPublicId,
  findById,
  findByIdentifier,
  createUser,
  linkFirebaseUid,
  updatePhone,
  findByFirebaseUid,
  createRecyclerUserWithProfile,
  updatePasswordHash,
  setVerified,
  recordLogin,
  updateProfileFields,
  createOtpChallenge,
  findActiveOtpChallenge,
  incrementOtpAttempts,
  consumeOtpChallenge,
  storeRefreshToken,
  findActiveRefreshToken,
  rotateRefreshToken,
  revokeRefreshToken,
  revokeAllRefreshTokens,
  toUser,
};
