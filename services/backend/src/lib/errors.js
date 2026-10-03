/*
|--------------------------------------------------------------------------
| APPLICATION ERRORS
|--------------------------------------------------------------------------
| A single error type that carries an HTTP status, a stable machine-readable
| code, and optional details. Anything thrown that is not an AppError is
| treated as an unexpected internal error and never leaks its message to the
| client (AGENTS.md section 9).
|--------------------------------------------------------------------------
*/

class AppError extends Error {
  constructor(message, { status = 500, code = "INTERNAL_ERROR", details } = {}) {
    super(message);

    this.name = "AppError";
    this.status = status;
    this.code = code;
    this.details = details;
    this.isOperational = true;

    Error.captureStackTrace(this, this.constructor);
  }

  toJSON() {
    return {
      code: this.code,
      message: this.message,
      ...(this.details ? { details: this.details } : {}),
    };
  }
}

class ValidationError extends AppError {
  constructor(message = "Request validation failed", details) {
    super(message, { status: 400, code: "VALIDATION_ERROR", details });
  }
}

class AuthenticationError extends AppError {
  constructor(message = "Authentication required", code = "UNAUTHENTICATED") {
    super(message, { status: 401, code });
  }
}

class AuthorizationError extends AppError {
  constructor(message = "You do not have access to this resource") {
    super(message, { status: 403, code: "FORBIDDEN" });
  }
}

class NotFoundError extends AppError {
  constructor(message = "Resource not found", details) {
    super(message, { status: 404, code: "NOT_FOUND", details });
  }
}

class ConflictError extends AppError {
  constructor(message = "Resource conflict", code = "CONFLICT", details) {
    super(message, { status: 409, code, details });
  }
}

class UnprocessableError extends AppError {
  constructor(message, code = "UNPROCESSABLE_ENTITY", details) {
    super(message, { status: 422, code, details });
  }
}

class PayloadTooLargeError extends AppError {
  constructor(message = "Uploaded payload is too large") {
    super(message, { status: 413, code: "PAYLOAD_TOO_LARGE" });
  }
}

class RateLimitError extends AppError {
  constructor(message = "Too many requests", details) {
    super(message, { status: 429, code: "RATE_LIMITED", details });
  }
}

/*
|--------------------------------------------------------------------------
| UPSTREAM ERRORS
|--------------------------------------------------------------------------
| The Node.js backend is the gateway in front of the Python AI service
| (AGENTS.md section 2). A failing AI service must degrade gracefully instead
| of looking like a backend failure.
|--------------------------------------------------------------------------
*/

class UpstreamTimeoutError extends AppError {
  constructor(message = "AI service timeout", details) {
    super(message, { status: 504, code: "AI_SERVICE_TIMEOUT", details });
  }
}

class UpstreamUnavailableError extends AppError {
  constructor(message = "Failed to communicate with AI service", details) {
    super(message, { status: 503, code: "AI_SERVICE_UNAVAILABLE", details });
  }
}

module.exports = {
  AppError,
  ValidationError,
  AuthenticationError,
  AuthorizationError,
  NotFoundError,
  ConflictError,
  UnprocessableError,
  PayloadTooLargeError,
  RateLimitError,
  UpstreamTimeoutError,
  UpstreamUnavailableError,
};
