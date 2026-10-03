/*
|--------------------------------------------------------------------------
| AUTHENTICATION AND AUTHORIZATION
|--------------------------------------------------------------------------
| requireAuth    — valid access token required, user loaded and attached.
| requireRole    — the authenticated user must hold one of the given roles.
| optionalAuth   — attaches the user when a valid token is present, but does
|                  not reject anonymous requests.
|
| Ownership checks ("is this lot yours?") are NOT done here. They need the
| resource, so they belong in the service layer.
|--------------------------------------------------------------------------
*/

const {
  extractBearerToken,
  verifyAccessToken,
} = require("../lib/tokens");
const { AuthenticationError, AuthorizationError } = require("../lib/errors");
const users = require("../modules/auth/auth.repository");

/**
 * Resolve a verified token payload into the current user record.
 *
 * The user is re-read on every request rather than trusted from the token,
 * so a deactivated or deleted account loses access immediately instead of
 * when its token happens to expire.
 */
async function resolveUser(payload) {
  const user = await users.findByPublicId(payload.sub);

  if (!user) {
    throw new AuthenticationError("Account no longer exists", "ACCOUNT_GONE");
  }

  if (!user.is_active) {
    throw new AuthenticationError("Account is deactivated", "ACCOUNT_INACTIVE");
  }

  return user;
}

function requireAuth() {
  return async function authenticate(req, res, next) {
    try {
      const token = extractBearerToken(req);

      if (!token) {
        throw new AuthenticationError(
          "Authorization header with a bearer token is required"
        );
      }

      const payload = verifyAccessToken(token);

      req.auth = payload;
      req.user = await resolveUser(payload);

      next();
    } catch (error) {
      next(error);
    }
  };
}

function optionalAuth() {
  return async function optionalAuthentication(req, res, next) {
    const token = extractBearerToken(req);

    if (!token) {
      return next();
    }

    try {
      const payload = verifyAccessToken(token);

      req.auth = payload;
      req.user = await resolveUser(payload);
    } catch {
      // An invalid token on an optional route is treated as anonymous.
    }

    next();
  };
}

/**
 * @param {...string} roles  e.g. requireRole("COLLECTOR", "ADMIN")
 */
function requireRole(...roles) {
  const allowed = new Set(roles);

  return function authorize(req, res, next) {
    if (!req.user) {
      return next(
        new AuthenticationError("Authentication required")
      );
    }

    if (!allowed.has(req.user.role)) {
      return next(
        new AuthorizationError(
          `This action requires one of the following roles: ${[...allowed].join(", ")}`
        )
      );
    }

    next();
  };
}

/**
 * Administrator-only guard, for moderation and rate management.
 */
function requireAdmin() {
  return requireRole("ADMIN");
}

module.exports = {
  requireAuth,
  optionalAuth,
  requireRole,
  requireAdmin,
};
