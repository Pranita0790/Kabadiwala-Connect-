/*
|--------------------------------------------------------------------------
| RESPONSE ENVELOPE
|--------------------------------------------------------------------------
| Every response this service emits is shaped here, so clients see one
| consistent error format and one success format.
|
| BACKWARD COMPATIBILITY (AGENTS.md section 5)
| The Recycler Dashboard is already deployed against this API. Two response
| shapes predate this file and must be preserved exactly:
|
|   GET  /api/rates        ->  { success, rates[] }   (dashboard: data.rates)
|   PUT  /api/rates/:id    ->  bare rate object        (dashboard splices the
|                                                        response straight
|                                                        into its state array)
|
| Do not "clean up" those two shapes without a contract change and a
| coordinated dashboard release.
|--------------------------------------------------------------------------
*/

const { AppError } = require("./errors");

/**
 * Standard success envelope.
 *
 * @param {import("express").Response} res
 * @param {object} options
 * @param {number} [options.status]  HTTP status, default 200
 * @param {any}    [options.data]    Payload under the `data` key
 * @param {string} [options.message] Human readable summary
 * @param {object} [options.extra]   Additional top-level keys (legacy shape support)
 */
function sendSuccess(res, { status = 200, data, message, extra } = {}) {
  const body = { success: true };

  if (message !== undefined) {
    body.message = message;
  }

  if (data !== undefined) {
    body.data = data;
  }

  if (extra && typeof extra === "object") {
    Object.assign(body, extra);
  }

  return res.status(status).json(body);
}

/**
 * Standard error envelope.
 *
 * `error` is kept as an alias of `message` because the previous AI gateway
 * implementation returned `{ error }` and the deployed collector APK may
 * surface it.
 */
function sendError(
  res,
  status,
  { code = "INTERNAL_ERROR", message = "Internal server error", details } = {}
) {
  const body = {
    success: false,
    code,
    message,
    error: message,
  };

  if (details !== undefined) {
    body.details = details;
  }

  return res.status(status).json(body);
}

/**
 * Send a resource under a caller-chosen key, e.g. `{ success, lot }`.
 * Used where an existing consumer already depends on that exact key.
 */
function sendResource(res, key, resource, { status = 200, message, extra } = {}) {
  return sendSuccess(res, {
    status,
    message,
    data: resource,
    extra: { [key]: resource, ...(extra || {}) },
  });
}

/**
 * Send a resource under its own key with no `data` wrapper, for the
 * PUT /api/rates/:id case where the dashboard uses the whole body.
 */
function sendBare(res, resource, { status = 200 } = {}) {
  return res.status(status).json(resource);
}

function sendNoContent(res) {
  return res.status(204).send();
}

/**
 * Convert an unknown thrown value into an AppError-safe shape.
 */
function toErrorPayload(error) {
  if (error instanceof AppError) {
    return {
      status: error.status,
      code: error.code,
      message: error.message,
      details: error.details,
    };
  }

  return {
    status: 500,
    code: "INTERNAL_ERROR",
    message: "Internal server error",
  };
}

module.exports = {
  sendSuccess,
  sendError,
  sendResource,
  sendBare,
  sendNoContent,
  toErrorPayload,
};
