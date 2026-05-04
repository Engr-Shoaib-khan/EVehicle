const jwt         = require("jsonwebtoken");
const User        = require("../models/User");
const { AppError } = require("./errorHandler");

const protect = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return next(new AppError("Access denied. No authentication token provided.", 401));
    }
    const token = authHeader.split(" ")[1];
    if (!token || token === "null" || token === "undefined") {
      return next(new AppError("Access denied. Invalid token format.", 401));
    }
    const decoded = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ["HS256"] }); // Explicitly set algorithm
    const user = await User.findById(decoded.id).select(
      "-password -otpCode -otpExpires -passwordResetToken -passwordResetExpires"
    );
    if (!user) return next(new AppError("Account no longer exists.", 401));
    if (!user.isActive) return next(new AppError("Account deactivated. Contact support.", 403));
    req.user = user;
    next();
  } catch (err) {
    next(err);
  }
};

const restrictTo = (...roles) => (req, res, next) => {
  if (!req.user || !roles.includes(req.user.role)) {
    return next(new AppError(`Access denied. Required roles: [${roles.join(", ")}].`, 403));
  }
  next();
};

const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) return next();
    const token   = authHeader.split(" ")[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ["HS256"] }); // Explicitly set algorithm
    const user    = await User.findById(decoded.id).select("-password");
    if (user && user.isActive) req.user = user;
  } catch (_) {}
  next();
};

module.exports = { protect, restrictTo, optionalAuth };
