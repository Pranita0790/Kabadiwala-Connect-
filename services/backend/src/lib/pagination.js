/*
|--------------------------------------------------------------------------
| PAGINATION
|--------------------------------------------------------------------------
| Page/pageSize pagination, clamped so a client cannot request the whole
| table by accident.
|--------------------------------------------------------------------------
*/

const config = require("../config/env");
const { ValidationError } = require("./errors");

function toPositiveInt(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ""), 10);

  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }

  return parsed;
}

/**
 * Parse `?page=&pageSize=` into SQL-ready limit/offset plus a link-header
 * friendly meta block.
 */
function parsePagination(query = {}) {
  const page = toPositiveInt(query.page, 1);
  const requestedLimit = toPositiveInt(
    query.pageSize ?? query.limit,
    config.pagination.defaultLimit
  );

  const pageSize = Math.min(requestedLimit, config.pagination.maxLimit);

  return {
    page,
    pageSize,
    limit: pageSize,
    offset: (page - 1) * pageSize,
  };
}

/**
 * Standard `meta` block returned alongside list endpoints.
 */
function buildMeta({ page, pageSize, total }) {
  const totalPages = pageSize > 0 ? Math.ceil(total / pageSize) : 0;

  return {
    page,
    pageSize,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
}

/**
 * Reject a page size that was explicitly requested above the maximum instead
 * of silently clamping it, so a misconfigured client is visible in logs.
 */
function assertPageSizeAllowed(query = {}) {
  const raw = query.pageSize ?? query.limit;

  if (raw === undefined) {
    return;
  }

  const parsed = Number.parseInt(String(raw), 10);

  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new ValidationError("pageSize must be a positive integer");
  }

  if (parsed > config.pagination.maxLimit) {
    throw new ValidationError(
      `pageSize must not exceed ${config.pagination.maxLimit}`,
      { maxPageSize: config.pagination.maxLimit }
    );
  }
}

module.exports = {
  parsePagination,
  buildMeta,
  assertPageSizeAllowed,
};
