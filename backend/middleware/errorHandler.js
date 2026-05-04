// ── Custom API Error Class ─────────────────────────────────────────
class AppError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.statusCode  = statusCode;
    this.status      = statusCode >= 400 && statusCode < 500 ? "fail"  : "error";
    this.isOperational = true; // distinguish programmer errors from known app errors
    Error.captureStackTrace(this, this.constructor);
  }
}

// ── Mongoose Duplicate Key (E11000) ───────────────────────────────
const _handleDuplicateKeyError = (err) => {
  const field   = Object.keys(err.keyValue)[0];
  const value   = err.keyValue[field];
  const message = `An account with ${field} '${value}' already exists.`;
  return new AppError(message, 409);
};

// ── Mongoose Validation Error ─────────────────────────────────────
const _handleValidationError = (err) => {
  const messages = Object.values(err.errors).map((e) => e.message);
  return new AppError(messages.join(" | "), 400);
};

// ── Mongoose Cast Error (bad ObjectId) ───────────────────────────
const _handleCastError = (err) => {
  return new AppError(`Invalid ${err.path}: '${err.value}'.`, 400);
};

// ── JWT Errors ────────────────────────────────────────────────────
const _handleJwtExpired   = () => new AppError("Your session has expired. Please log in again.", 401);
const _handleJwtInvalid   = () => new AppError("Invalid authentication token. Please log in again.", 401);

// ── Send Dev Error (full stack) ───────────────────────────────────
const _sendDevError = (err, res) => {
  res.status(err.statusCode || 500).json({
    success:    false,
    status:     err.status || "error",
    message:    err.message,
    stack:      err.stack,
    error:      err,
  });
};

// ── Send Prod Error (safe, no stack) ─────────────────────────────
const _sendProdError = (err, res) => {
  if (err.isOperational) {
    // Known, expected errors — safe to tell the client
    return res.status(err.statusCode).json({
      success: false,
      status:  err.status,
      message: err.message,
    });
  }
  // Unknown / programmer errors — don't leak internals
  console.error("💥 UNHANDLED ERROR:", err);
  return res.status(500).json({
    success: false,
    status:  "error",
    message: "Something went wrong on our end. Please try again.",
  });
};

// ── Global Error Handler (Express 4-arg middleware) ───────────────
const globalErrorHandler = (err, req, res, next) => {
  err.statusCode = err.statusCode || 500;
  err.status     = err.status     || "error";

  if (process.env.NODE_ENV === "development") {
    return _sendDevError(err, res);
  }

  // Map known Mongoose / JWT errors → AppError
  let error = Object.create(err); // shallow copy so we don't mutate original
  Object.assign(error, err);
  error.message = err.message;

  if (err.code === 11000)                    error = _handleDuplicateKeyError(err);
  if (err.name === "ValidationError")        error = _handleValidationError(err);
  if (err.name === "CastError")              error = _handleCastError(err);
  if (err.name === "TokenExpiredError")      error = _handleJwtExpired();
  if (err.name === "JsonWebTokenError")      error = _handleJwtInvalid();

  return _sendProdError(error, res);
};

module.exports = { AppError, globalErrorHandler };
