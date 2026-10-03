/*
|--------------------------------------------------------------------------
| LOGGER
|--------------------------------------------------------------------------
| Leveled logger with secret redaction. Deliberately dependency-free: a
| logging library is not justified for this service (AGENTS.md section 13).
|
| Every log line is JSON so the deployment platform (Render) can index it.
|--------------------------------------------------------------------------
*/

const config = require("../config/env");

const LEVELS = Object.freeze({
  debug: 10,
  info: 20,
  warn: 30,
  error: 40,
  silent: 100,
});

const activeLevel =
  LEVELS[config.isTest ? "silent" : (process.env.LOG_LEVEL || "info")] ??
  LEVELS.info;

/*
|--------------------------------------------------------------------------
| REDACTION
|--------------------------------------------------------------------------
| AGENTS.md section 9: never log secrets. Redact by key name and mask any
| JWT-shaped value, so a stray token cannot reach the log pipeline.
|--------------------------------------------------------------------------
*/

const SECRET_KEY_PATTERN =
  /(pass|password|secret|token|authorization|cookie|api[_-]?key|credential|otp)/i;

const JWT_PATTERN = /\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\b/g;

const REDACTED = "[REDACTED]";

function redactString(value) {
  return value.replace(JWT_PATTERN, REDACTED);
}

function redact(value, depth = 0) {
  if (value === null || value === undefined) {
    return value;
  }

  if (depth > 6) {
    return "[TRUNCATED]";
  }

  if (typeof value === "string") {
    return redactString(value);
  }

  if (typeof value === "number" || typeof value === "boolean") {
    return value;
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (value instanceof Error) {
    return {
      name: value.name,
      message: redactString(value.message),
      stack: value.stack,
    };
  }

  if (Buffer.isBuffer(value)) {
    return `[Buffer ${value.length} bytes]`;
  }

  if (Array.isArray(value)) {
    return value.slice(0, 50).map((item) => redact(item, depth + 1));
  }

  if (typeof value === "object") {
    const output = {};

    for (const [key, item] of Object.entries(value)) {
      output[key] = SECRET_KEY_PATTERN.test(key)
        ? REDACTED
        : redact(item, depth + 1);
    }

    return output;
  }

  return String(value);
}

/*
|--------------------------------------------------------------------------
| WRITE
|--------------------------------------------------------------------------
*/

function write(level, message, context) {
  if (LEVELS[level] < activeLevel) {
    return;
  }

  const entry = {
    level,
    time: new Date().toISOString(),
    service: "kabadiwala-backend",
    message: redactString(String(message)),
  };

  if (context !== undefined) {
    entry.context = redact(context);
  }

  const stream = LEVELS[level] >= LEVELS.error ? console.error : console.log;

  stream(JSON.stringify(entry));
}

const logger = {
  debug: (message, context) => write("debug", message, context),
  info: (message, context) => write("info", message, context),
  warn: (message, context) => write("warn", message, context),
  error: (message, context) => write("error", message, context),
  redact,
};

module.exports = logger;
