/*
|--------------------------------------------------------------------------
| ENVIRONMENT CONFIGURATION
|--------------------------------------------------------------------------
| Single place where environment variables are read, validated and typed.
|
| Rules:
| - No module may read process.env directly.
| - Secrets are never logged; see logger.js redaction.
| - The process must fail fast on invalid configuration.
|--------------------------------------------------------------------------
*/

const path = require("node:path");

// A developer's local .env must not influence the test run: tests/setup.js
// supplies every value deliberately, and quietly inheriting a real
// DATABASE_URL from a developer's machine is how a suite ends up truncating a
// database it was never meant to touch. Skipping the file also removes
// dotenv's "missing .env" tip from the test output.
if (process.env.NODE_ENV !== "test") {
  const dotenv = require("dotenv");
  // Monorepo root .env (local), then services/backend/.env (Render rootDir).
  dotenv.config({ path: path.resolve(__dirname, "../../../../.env") });
  dotenv.config({ path: path.resolve(__dirname, "../../.env") });
}

const isTest = process.env.NODE_ENV === "test";

/*
|--------------------------------------------------------------------------
| HELPERS
|--------------------------------------------------------------------------
*/

function required(name) {
  const value = process.env[name];

  if (!value || value.trim().length === 0) {
    throw new Error(
      `Missing required environment variable: ${name}. ` +
        `Copy .env.example to .env at the repository root.`
    );
  }

  return value.trim();
}

function optional(name, fallback = undefined) {
  const value = process.env[name];

  if (value === undefined || value.trim().length === 0) {
    return fallback;
  }

  return value.trim();
}

function toInt(name, fallback) {
  const raw = process.env[name];

  if (raw === undefined || raw.trim().length === 0) {
    return fallback;
  }

  const parsed = Number.parseInt(raw, 10);

  if (Number.isNaN(parsed)) {
    throw new Error(`Environment variable ${name} must be an integer.`);
  }

  return parsed;
}

function toBool(name, fallback) {
  const raw = optional(name);

  if (raw === undefined) {
    return fallback;
  }

  return ["1", "true", "yes", "on"].includes(raw.toLowerCase());
}

function toList(name, fallback = []) {
  const raw = optional(name);

  if (raw === undefined) {
    return fallback;
  }

  return raw
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

/*
|--------------------------------------------------------------------------
| SCHEMA
|--------------------------------------------------------------------------
*/

const nodeEnv = optional("NODE_ENV", "development");

const isProduction = nodeEnv === "production";

/*
| JWT secret is mandatory in production. In development and test a clearly
| marked development-only value is allowed so the service can boot without a
| secrets file, but the server logs a loud warning.
*/

const DEV_JWT_SECRET = "dev-only-insecure-jwt-secret-change-me";

const jwtSecret = optional("JWT_SECRET", isProduction ? undefined : DEV_JWT_SECRET);

if (!jwtSecret) {
  throw new Error(
    "JWT_SECRET is required in production. Generate one with: openssl rand -hex 32"
  );
}

/*
| Whether a database was actually configured. This is deliberately separate
| from the connection details, which all carry defaults: those defaults would
| otherwise make an unconfigured deploy look configured and turn every
| DB-backed route into a connection-refused 500 instead of an honest 503.
|
| A value counts as configured if the deploy supplied a connection string or
| any of the discrete DB_* settings.
*/
const databaseConnectionString = optional("DATABASE_URL");
const databaseConfigured = Boolean(
  databaseConnectionString ||
    optional("DB_HOST") ||
    optional("DB_NAME")
);

const config = {
  env: nodeEnv,
  isProduction,
  isTest,
  isDevelopment: nodeEnv === "development",

  server: {
    port: toInt("PORT", 5000),
    host: optional("HOST", "0.0.0.0"),
    shutdownTimeoutMs: toInt("SHUTDOWN_TIMEOUT_MS", 10_000),
    bodyLimit: optional("BODY_LIMIT", "1mb"),
  },

  cors: {
    origins: toList("CORS_ORIGINS", [
      "http://localhost:5173",
      "http://localhost:5174",
      "https://kabadiwala-connect-xi.vercel.app",
    ]),
  },

  database: {
    // False when no DB_* variable was supplied; see require-database.js.
    configured: databaseConfigured,
    connectionString: databaseConnectionString,
    host: optional("DB_HOST", "localhost"),
    port: toInt("DB_PORT", 5432),
    name: optional("DB_NAME", "kabadiwala"),
    user: String(optional("DB_USER", "postgres") ?? "postgres"),
    // pg SCRAM requires a string password (numeric .env values must not stay as numbers).
    password: String(optional("DB_PASSWORD", "") ?? ""),
    ssl: toBool("DB_SSL", false),
    max: toInt("DB_POOL_MAX", 10),
    idleTimeoutMillis: toInt("DB_IDLE_TIMEOUT_MS", 30_000),
    connectionTimeoutMillis: toInt("DB_CONNECTION_TIMEOUT_MS", 5_000),
    // When true the /health endpoint reports degraded instead of failing hard.
    required: toBool("DB_REQUIRED", true),
  },

  auth: {
    jwtSecret,
    isUsingDevelopmentSecret: jwtSecret === DEV_JWT_SECRET,
    accessTokenTtl: optional("JWT_ACCESS_TTL", "15m"),
    refreshTokenTtl: optional("JWT_REFRESH_TTL", "30d"),
    refreshTokenTtlDays: toInt("JWT_REFRESH_TTL_DAYS", 30),
    issuer: optional("JWT_ISSUER", "kabadiwala-connect"),
    audience: optional("JWT_AUDIENCE", "kabadiwala-clients"),
    bcryptRounds: toInt("BCRYPT_ROUNDS", 10),

    /*
     | Firebase Phone Auth.
     |
     | The PROJECT ID is public information — it appears in the client's
     | firebase_options.dart and in every token's `aud` claim — so it is safe
     | to commit. It is the only value needed to verify an ID token, because
     | that uses Google's public certificates rather than a private key.
     |
     | No service-account JSON is ever read by this backend. If one appears
     | in the repository it must be treated as exposed (AGENTS.md section 9).
     */
    firebaseProjectId: optional("FIREBASE_PROJECT_ID", null),
  },

  ai: {
    baseUrl: optional("AI_SERVICE_URL", "http://localhost:8000"),
    analyzePath: optional("AI_SERVICE_ANALYZE_PATH", "/api/v1/analyze"),
    criticalMineralPath: optional(
      "AI_SERVICE_CRITICAL_MINERAL_PATH",
      "/api/v1/critical-mineral/check"
    ),
    healthPath: optional("AI_SERVICE_HEALTH_PATH", "/health"),
    timeoutMs: toInt("AI_SERVICE_TIMEOUT_MS", 15_000),
    maxImageBytes: toInt("AI_MAX_IMAGE_BYTES", 10 * 1024 * 1024),
    // Circuit breaker: stop calling a failing AI service for a cool-down window.
    breakerThreshold: toInt("AI_BREAKER_THRESHOLD", 5),
    breakerCooldownMs: toInt("AI_BREAKER_COOLDOWN_MS", 30_000),
    // Backend-only. Never put this in Flutter dart-define.
    geminiApiKey: optional("GEMINI_API_KEY", null),
    geminiModel: optional("GEMINI_MODEL", "gemini-2.0-flash"),
  },

  uploads: {
    maxImageBytes: toInt("UPLOAD_MAX_IMAGE_BYTES", 10 * 1024 * 1024),
    allowedMimeTypes: toList("UPLOAD_ALLOWED_MIME_TYPES", [
      "image/jpeg",
      "image/jpg",
      "image/png",
      "image/webp",
      "image/heic",
      "image/heif",
    ]),
  },

  rateLimit: {
    // Simple in-process limiter. See middleware/rate-limit.js for the limits.
    enabled: toBool("RATE_LIMIT_ENABLED", true),
    aiAnalyzePerMinute: toInt("RATE_LIMIT_AI_PER_MINUTE", 30),
    authPerMinute: toInt("RATE_LIMIT_AUTH_PER_MINUTE", 10),
    defaultPerMinute: toInt("RATE_LIMIT_DEFAULT_PER_MINUTE", 300),
  },

  pagination: {
    defaultLimit: toInt("PAGINATION_DEFAULT_LIMIT", 25),
    maxLimit: toInt("PAGINATION_MAX_LIMIT", 100),
  },

  /*
   | Razorpay Checkout Key Id is client-safe (Test Mode). Never expose
   | RAZORPAY_KEY_SECRET to Flutter — keep it backend-only for order APIs.
   */
  razorpay: {
    keyId: optional("RAZORPAY_KEY_ID", null),
    // Secret stays server-side only; not returned by any public user route.
    keySecret: optional("RAZORPAY_KEY_SECRET", null),
  },

  paths: {
    repoRoot: path.resolve(__dirname, "../../../.."),
    sharedContracts: path.resolve(
      __dirname,
      "../../../../packages/shared/contracts/enums.json"
    ),
  },
};

if (config.isUsingDevelopmentSecret && !isTest) {
  // Loud, actionable warning — never silently boot with a known-weak secret.
  process.emitWarning(
    "JWT_SECRET is not set. Using an insecure development-only secret. " +
      "Set JWT_SECRET before deploying.",
    "InsecureJwtSecretWarning"
  );
}

module.exports = config;
