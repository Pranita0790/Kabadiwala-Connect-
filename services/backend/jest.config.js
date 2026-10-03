/*
|--------------------------------------------------------------------------
| JEST CONFIGURATION
|--------------------------------------------------------------------------
| Two kinds of test:
|
|   tests/unit        no database, no network — pure functions and status
|                     machine rules
|   tests/integration requires a real PostgreSQL, because the point of these
|                     tests is to verify the SQL and the field-name
|                     hand-offs between repository and DTO layer, which a
|                     mock cannot check.
|
| Integration tests are skipped unless TEST_DATABASE_URL is set, so a
| contributor without a database still gets a green unit suite rather than a
| wall of connection errors.
|
| Run against a THROWAWAY database only. The suite truncates application
| tables between tests.
|--------------------------------------------------------------------------
*/

module.exports = {
  testEnvironment: "node",
  clearMocks: true,

  // Integration tests share one database, so they must not run concurrently.
  maxWorkers: 1,

  collectCoverageFrom: [
    "src/**/*.js",
    "!src/server.js",
    "!src/db/migrations/**",
  ],

  coverageThreshold: {
    global: {
      branches: 60,
      functions: 70,
      lines: 70,
      statements: 70,
    },
  },

  setupFilesAfterEnv: ["<rootDir>/tests/setup.js"],

  testPathIgnorePatterns: ["/node_modules/", "/tests/helpers/"],
};