/*
|--------------------------------------------------------------------------
| ERROR HANDLING
|--------------------------------------------------------------------------
| The last two middlewares in the chain.
|
| notFound       — turns an unmatched route into a 404 AppError.
| errorHandler   — the single place an error becomes an HTTP response.
|
| Invariants:
|   - Operational errors (AppError) are returned with their own message.
|   - Anything else is logged with a stack trace and reported to the client
|     as a generic 500, so internals never leak (AGENTS.md section 9).
|   - Syntax errors in the request body are reported as 400, not 500.
|--------------------------------------------------------------------------
*/

const {
  AppError,
  ValidationError,
  NotFoundError,
} = require("../lib/errors");
const logger = require("../lib/logger");
const { sendError, toErrorPayload } = require("../lib/response");
const config = require("../config/env");

function notFound(req, res, next) {
  next(
    new NotFoundError(`Route not found: ${req.method} ${req.originalUrl}`, {
      method: req.method,
      path: req.originalUrl,
    })
  );
}

// eslint-disable-next-line no-unused-vars -- Express identifies error middleware by arity
function errorHandler(error, req, res, next) {
  // Express 5 forwards body-parser failures here; a malformed JSON body is a
  // client error, not a server error.
  if (error instanceof SyntaxError && "body" in error) {
    return sendError(res, 400, {
      code: "INVALID_JSON",
      message: "Request body is not valid JSON",
    });
  }

  if (error?.type === "entity.too.large") {
    return sendError(res, 413, {
      code: "PAYLOAD_TOO_LARGE",
      message: `Request body exceeds the ${config.server.bodyLimit} limit`,
    });
  }

  if (error?.code === "LIMIT_UNSAFE_FILE" || error?.code === "LIMIT_FILE_SIZE") {
    return sendError(res, 413, {
      code: "PAYLOAD_TOO_LARGE",
      message: "Upload exceeds the allowed size",
    });
  }

  const payload = toErrorPayload(error);
  const isUnexpected = !(error instanceof AppError);

  const logContext = {
    requestId: req.id,
    method: req.method,
    path: req.originalUrl,
    status: payload.status,
    code: payload.code,
    userId: req.user?.id,
  };

  if (isUnexpected) {
    logContext.error = {
      name: error?.name,
      message: error?.message,
      stack: error?.stack,
    };

    logger.error("Unhandled error", logContext);
  } else {
    // Expected failures are noise at error level; a 4xx is a client problem.
    logger.warn("Request rejected", logContext);
  }

  // The response may already be partially written (e.g. a stream failure).
  if (res.headersSent) {
    return next(error);
  }

  return sendError(res, payload.status, {
    code: payload.code,
    message: payload.message,
    details: payload.details,
  });
}

/**
 * Wrap a synchronous function so a throw is caught. Used in tests and for
 * route registration time errors.
 */
function guard(fn) {
  return function guarded(req, res, next) {
    try {
      return fn(req, res, next);
    } catch (error) {
      return next(error);
    }
  };
}

module.exports = {
  notFound,
  errorHandler,
  guard,
  ValidationError,
};
