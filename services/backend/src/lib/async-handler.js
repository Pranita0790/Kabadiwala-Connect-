/*
|--------------------------------------------------------------------------
| ASYNC HANDLER
|--------------------------------------------------------------------------
| Wraps an async route handler so a rejected promise reaches the Express error
| middleware instead of becoming an unhandled rejection.
|--------------------------------------------------------------------------
*/

function asyncHandler(handler) {
  return function wrappedAsyncHandler(req, res, next) {
    Promise.resolve(handler(req, res, next)).catch(next);
  };
}

module.exports = asyncHandler;
