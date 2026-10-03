/*
|--------------------------------------------------------------------------
| AUTH CONTROLLER
|--------------------------------------------------------------------------
| HTTP concerns only: read the request, call the service, shape the
| response. No SQL, no business rules.
|--------------------------------------------------------------------------
*/

const authService = require("./auth.service");
const firebaseAuthService = require("./firebase-auth.service");
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess } = require("../../lib/response");
const { userRole } = require("../../config/constants");

/**
 * The collector app sends a user agent and source IP; both are recorded
 * against the refresh token so a suspicious session is attributable.
 */
function sessionContext(req) {
  return {
    userAgent: req.get("user-agent")?.slice(0, 400) ?? null,
    ipAddress: req.ip ?? null,
  };
}

const register = asyncHandler(async (req, res) => {
  const user = await authService.register(req.body);

  sendSuccess(res, {
    status: 201,
    message: "Account created. You can sign in now.",
    data: { user: authService.toPublicUser(user) },
  });
});

const registerRecycler = asyncHandler(async (req, res) => {
  const user = await authService.registerRecycler(req.body);

  sendSuccess(res, {
    status: 201,
    message:
      "Recycler account created. Your organisation stays unauthorised until an administrator verifies it.",
    data: { user: authService.toPublicUser(user) },
  });
});

const login = asyncHandler(async (req, res) => {
  const session = await authService.login(req.body, sessionContext(req));

  sendSuccess(res, { message: "Signed in", data: session });
});

const requestOtp = asyncHandler(async (req, res) => {
  const result = await authService.requestOtp(req.body);

  sendSuccess(res, {
    message: result.delivered
      ? "A one-time password has been sent."
      : "If that account exists, a one-time password has been sent.",
    data: result,
  });
});

const verifyOtp = asyncHandler(async (req, res) => {
  const session = await authService.verifyOtp(req.body, sessionContext(req));

  sendSuccess(res, { message: "Signed in", data: session });
});

const refresh = asyncHandler(async (req, res) => {
  const session = await authService.refreshSession(req.body);

  sendSuccess(res, { message: "Session refreshed", data: session });
});

const logout = asyncHandler(async (req, res) => {
  const result = await authService.logout(req.body, req.user);

  sendSuccess(res, { message: "Signed out", data: result });
});

const me = asyncHandler(async (req, res) => {
  const user = await authService.getProfile(req.user.id);

  sendSuccess(res, { data: { user } });
});

const updateMe = asyncHandler(async (req, res) => {
  const user = await authService.updateProfile(req.user.id, req.body);

  sendSuccess(res, { message: "Profile updated", data: { user } });
});

const changePassword = asyncHandler(async (req, res) => {
  const result = await authService.changePassword(req.user, req.body);

  sendSuccess(res, {
    message:
      "Password updated. Sign in again on your other devices.",
    data: result,
  });
});

/**
 * Development aid: which roles exist, so a client can render role-specific
 * UI without hard-coding the list. Returns nothing sensitive.
 */
const roles = asyncHandler(async (req, res) => {
  sendSuccess(res, {
    data: {
      roles: Object.values(userRole),
    },
  });
});

/**
 * Firebase phone sign-in.
 *
 * The device has already completed SMS verification with Firebase, so this
 * endpoint only verifies the resulting ID token and issues a session. The
 * token is passed straight to the service and never logged or echoed back:
 * `req.body.idToken` must not appear in any log line (AGENTS.md section 9).
 */
const firebaseSignIn = asyncHandler(async (req, res) => {
  const session = await firebaseAuthService.signInWithIdToken(req.body.idToken, {
    fullName: req.body.fullName,
    ...sessionContext(req),
  });

  sendSuccess(res, {
    status: session.created ? 201 : 200,
    message: session.created
      ? "Account created. Welcome to Kabadiwala Connect."
      : "Signed in",
    data: {
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresInSeconds: session.expiresInSeconds,
      user: authService.toPublicUser(session.user),
      // Lets the app route straight to the profile form after a brand new
      // account, without a second request.
      needsProfile: !firebaseAuthService.isOnboarded(session.user),
    },
  });
});

module.exports = {
  register,
  firebaseSignIn,
  registerRecycler,
  login,
  requestOtp,
  verifyOtp,
  refresh,
  logout,
  me,
  updateMe,
  changePassword,
  roles,
};
