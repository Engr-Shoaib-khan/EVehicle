const { AppError } = require("./errorHandler");

// ── Generic field presence check ──────────────────────────────────
const requireFields = (...fields) => (req, res, next) => {
  const missing = fields.filter((f) => {
    const val = req.body[f];
    return val === undefined || val === null || String(val).trim() === "";
  });
  if (missing.length > 0) {
    return next(new AppError(`Missing required fields: ${missing.join(", ")}.`, 400));
  }
  next();
};

// ── Sanitize string fields (trim, lowercase where needed) ─────────
const sanitizeBody = (req, res, next) => {
  if (req.body.email)    req.body.email    = req.body.email.trim().toLowerCase();
  if (req.body.fullName) req.body.fullName = req.body.fullName.trim();
  if (req.body.phone)    req.body.phone    = req.body.phone.trim();
  next();
};

// ── Validate register payload ─────────────────────────────────────
const validateRegister = [
  sanitizeBody,
  (req, res, next) => {
    const { fullName, email, password, phoneNumber, role } = req.body;
    const errors = [];

    if (!fullName || fullName.length < 2 || fullName.length > 80)
      errors.push("Full name must be between 2 and 80 characters.");

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!email || !emailRegex.test(email))
      errors.push("A valid email address is required.");

    if (!password || password.length < 8)
      errors.push("Password must be at least 8 characters.");

    const phoneRegex = /^(\+92|0)3[0-9]{9}$/;
    if (!phoneNumber || !phoneRegex.test(phoneNumber))
      errors.push("Phone must be a valid Pakistani mobile number (e.g. 03001234567).");

    if (!["rider", "driver"].includes(role))
      errors.push("Role must be 'rider' or 'driver'.");

    if (errors.length > 0) {
      return next(new AppError(errors.join(" | "), 400));
    }
    next();
  },
];

// ── Validate login payload ────────────────────────────────────────
const validateLogin = [
  sanitizeBody,
  (req, res, next) => {
    const { email, password } = req.body;
    if (!email || !password) {
      return next(new AppError("Email and password are required.", 400));
    }
    next();
  },
];

// ── Validate OTP payload ──────────────────────────────────────────
const validateOtp = (req, res, next) => {
  const { email, otp } = req.body;
  if (!email || !otp) {
    return next(new AppError("Email and OTP code are required.", 400));
  }
  if (String(otp).trim().length !== 6 || isNaN(Number(otp))) {
    return next(new AppError("OTP must be exactly 6 digits.", 400));
  }
  next();
};

// ── Validate ride request payload ─────────────────────────────────
const validateRideRequest = (req, res, next) => {
  const { pickupCoordinates, dropoffCoordinates } = req.body;

  if (!Array.isArray(pickupCoordinates)  || pickupCoordinates.length  !== 2 ||
      !Array.isArray(dropoffCoordinates) || dropoffCoordinates.length !== 2) {
    return next(new AppError(
      "pickupCoordinates and dropoffCoordinates must be arrays of [longitude, latitude].", 400
    ));
  }

  const [pLng, pLat] = pickupCoordinates;
  const [dLng, dLat] = dropoffCoordinates;

  if (isNaN(pLat) || isNaN(pLng) || isNaN(dLat) || isNaN(dLng)) {
    return next(new AppError("Coordinates must be valid numbers.", 400));
  }
  if (pLat === dLat && pLng === dLng) {
    return next(new AppError("Pickup and drop-off locations cannot be the same.", 400));
  }
  next();
};

module.exports = {
  requireFields,
  sanitizeBody,
  validateRegister,
  validateLogin,
  validateOtp,
  validateRideRequest,
};
