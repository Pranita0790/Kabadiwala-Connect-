/*
|--------------------------------------------------------------------------
| AUTH ROUTES  →  /api/auth
|--------------------------------------------------------------------------
| Endpoints marked `public` are reachable without a token. Everything else
| requires a valid access token.
|--------------------------------------------------------------------------
*/

const express = require("express");

const controller = require("./auth.controller");
const schemas = require("./auth.schema");
const { requireAuth } = require("../../middleware/auth");
const { authLimiter } = require("../../middleware/rate-limit");
const { validate } = require("../../middleware/validate");

const router = express.Router();

/*
|--------------------------------------------------------------------------
| PUBLIC — REGISTRATION
|--------------------------------------------------------------------------
*/

// POST /api/auth/register
router.post(
  "/register",
  authLimiter,
  validate(schemas.register),
  controller.register
);

// POST /api/auth/recyclers/register
router.post(
  "/recyclers/register",
  authLimiter,
  validate(schemas.registerRecycler),
  controller.registerRecycler
);

// POST /api/auth/login
router.post(
  "/login",
  authLimiter,
  validate(schemas.login),
  controller.login
);

/*
|--------------------------------------------------------------------------
| PUBLIC — OTP LOGIN
|--------------------------------------------------------------------------
*/

// POST /api/auth/otp/request
router.post(
  "/otp/request",
  authLimiter,
  validate(schemas.requestOtp),
  controller.requestOtp
);

// POST /api/auth/otp/verify
router.post(
  "/otp/verify",
  authLimiter,
  validate(schemas.verifyOtp),
  controller.verifyOtp
);

/*
|--------------------------------------------------------------------------
| PUBLIC — SESSION
|--------------------------------------------------------------------------
*/

// POST /api/auth/refresh — rotates the refresh token
router.post(
  "/refresh",
  validate(schemas.refresh),
  controller.refresh
);

// POST /api/auth/logout — works with or without a token so a client whose
// access token already expired can still clear its refresh token.
router.post(
  "/logout",
  requireAuth(),
  validate(schemas.logout),
  controller.logout
);

/*
|--------------------------------------------------------------------------
| PUBLIC — REFERENCE DATA
|--------------------------------------------------------------------------
*/

// GET /api/auth/roles
router.get("/roles", controller.roles);

/*
|--------------------------------------------------------------------------
| AUTHENTICATED
|--------------------------------------------------------------------------
*/

// GET /api/auth/me
router.get("/me", requireAuth(), controller.me);

// PATCH /api/auth/me
router.patch("/me", requireAuth(), validate(schemas.updateProfile), controller.updateMe);

// POST /api/auth/change-password
router.post(
  "/change-password",
  authLimiter,
  requireAuth(),
  validate(schemas.changePassword),
  controller.changePassword
);

/*
|--------------------------------------------------------------------------
| PUBLIC - FIREBASE PHONE AUTH
|--------------------------------------------------------------------------
*/

// POST /api/auth/firebase/sign-in
//
// Device-side flow (see apps/collector/lib/core/auth/auth_controller.dart):
//   1. signInWithPhoneNumber -> Firebase sends the SMS
//   2. verifyWithCredential   -> Firebase checks the code
//   3. user.getIdToken()      -> device holds an ID token
//   4. POST this endpoint     -> backend verifies it and returns a session
//
// Rate limited like the other auth entry points so tokens cannot be probed
// at speed.
router.post(
  "/firebase/sign-in",
  authLimiter,
  validate(schemas.firebaseSignIn),
  controller.firebaseSignIn
);

module.exports = router;
