/*
|--------------------------------------------------------------------------
| PASSWORD HASHING
|--------------------------------------------------------------------------
| bcrypt with a configurable cost. Hash comparison is constant time by
| construction in bcryptjs.
|
| bcryptjs is used rather than the native bcrypt binding so the service
| installs without a compiler toolchain (AGENTS.md section 13).
|--------------------------------------------------------------------------
*/

const bcrypt = require("bcryptjs");

const config = require("../config/env");

function hashPassword(plainText) {
  return bcrypt.hash(plainText, config.auth.bcryptRounds);
}

/**
 * bcrypt.compare is safe to call with a null/undefined hash and returns
 * false rather than throwing, which is what we want when a user record has
 * no password set (recycler-registered accounts authenticate by OTP).
 */
function verifyPassword(plainText, passwordHash) {
  if (typeof plainText !== "string" || typeof passwordHash !== "string") {
    return Promise.resolve(false);
  }

  return bcrypt.compare(plainText, passwordHash);
}

/**
 * Minimum viable password policy for collector accounts.
 */
function assertPasswordStrength(plainText) {
  const problems = [];

  if (plainText.length < 8) {
    problems.push("at least 8 characters");
  }

  if (!/[a-z]/.test(plainText)) {
    problems.push("a lowercase letter");
  }

  if (!/[A-Z]/.test(plainText)) {
    problems.push("an uppercase letter");
  }

  if (!/[0-9]/.test(plainText)) {
    problems.push("a digit");
  }

  return problems;
}

module.exports = {
  hashPassword,
  verifyPassword,
  assertPasswordStrength,
};
