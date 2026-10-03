/*
|--------------------------------------------------------------------------
| TEST SETUP
|--------------------------------------------------------------------------
| Loaded by Jest for every suite.
|
| Provides a deterministic JWT secret so token tests do not depend on the
| developer's .env, and shortens the logger's default output unless a test
| asks for it.
|--------------------------------------------------------------------------
*/

process.env.NODE_ENV = process.env.NODE_ENV || "test";

// A fixed secret keeps tokens reproducible across runs. 32+ chars, because
// config/env.js rejects anything shorter and the failure would otherwise look
// like a config bug in every suite.
process.env.JWT_SECRET =
  process.env.JWT_SECRET || "test-secret-key-not-for-production-use-0123456789";

process.env.LOG_LEVEL = process.env.LOG_LEVEL || "silent";

/*
 | Integration tests target TEST_DATABASE_URL so that a developer cannot
 | accidentally point the suite at their working database: the suite
 | truncates tables.
 |
 | TEST_DATABASE_URL must win even when DATABASE_URL is already exported in
 | the developer's shell. Aliasing only when DATABASE_URL is absent would
 | silently truncate whatever database the shell happened to point at, which
 | is exactly the failure this guard exists to prevent. When both are set and
 | they disagree, refuse to run rather than pick one.
 */
if (process.env.TEST_DATABASE_URL) {
  const configured = process.env.DATABASE_URL;

  if (configured && configured !== process.env.TEST_DATABASE_URL) {
    throw new Error(
      "[tests] Refusing to run: DATABASE_URL and TEST_DATABASE_URL are both set " +
        "and differ. The suite truncates tables, so unset DATABASE_URL or make " +
        "the two match."
    );
  }

  process.env.DATABASE_URL = process.env.TEST_DATABASE_URL;
}

/*
 * Integration tests are opt-in. Without a database URL the suites under
 * tests/integration are skipped instead of failing on connection refused,
 * so `npm test` is useful on a machine with no PostgreSQL.
 */
const hasDatabase = Boolean(process.env.TEST_DATABASE_URL);

if (!hasDatabase) {
  beforeAll(() => {
    // eslint-disable-next-line no-console
    console.warn(
      "[tests] TEST_DATABASE_URL is not set — integration tests will be skipped. " +
        "Run migrations first: npm run migrate"
    );
  });
}