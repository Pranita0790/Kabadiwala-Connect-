/*
|--------------------------------------------------------------------------
| REQUEST VALIDATION
|--------------------------------------------------------------------------
| Validates and coerces body / query / params with a zod schema, and
| REPLACES the raw value with the parsed one. Controllers therefore receive
| typed, trimmed, trusted data and never re-validate by hand.
|
| Unknown keys are stripped rather than passed through, so a client cannot
| smuggle unexpected fields into a service or repository call.
|--------------------------------------------------------------------------
*/

const { ValidationError } = require("../lib/errors");

/**
 * Turn a ZodError into a flat, client-readable list of field problems.
 */
function formatIssues(error) {
  return error.issues.map((issue) => ({
    field: issue.path.join(".") || "(root)",
    message: issue.message,
    code: issue.code,
  }));
}

function buildSchemas({ body, query, params }) {
  return { body, query, params };
}

/**
 * @param {object} schemas  { body?, query?, params? } zod schemas
 * @param {object} [options] { source: 'body' | 'query' | 'params' }
 */
function validate(schemas, options = {}) {
  const targets = options.source
    ? { [options.source]: schemas }
    : buildSchemas(schemas);

  return function validateRequest(req, res, next) {
    for (const [key, schema] of Object.entries(targets)) {
      if (!schema) {
        continue;
      }

      const result = schema.safeParse(req[key]);

      if (!result.success) {
        const details = formatIssues(result.error);

        // Echo which source failed so a client can debug without guessing.
        const labels = {
          body: "Request body",
          query: "Query string",
          params: "Path parameter",
        };

        return next(
          new ValidationError(
            `${labels[key] || key} validation failed`,
            details
          )
        );
      }

      // req.query is a getter on Express 5 and cannot be reassigned, so the
      // parsed value is stored alongside it.
      if (key === "query") {
        req.validatedQuery = result.data;
      } else {
        req[key] = result.data;
      }
    }

    next();
  };
}

/**
 * Read validated query parameters, falling back to the raw query when the
 * route did not declare a schema.
 */
function validatedQuery(req) {
  return req.validatedQuery || req.query;
}

module.exports = validate;
module.exports.validate = validate;
module.exports.validatedQuery = validatedQuery;
