const express = require("express");
const {
  register,
  verifyOtp,
  login,
  resendOtp,
  getMe,
  updateFcmToken,
  submitKyc,
  googleLogin,
} = require("../controllers/authController");
const { protect, restrictTo } = require("../middleware/auth");
const { validateRegister, validateLogin, validateOtp } = require("../middleware/validate");

const router = express.Router();

// ── Public ─────────────────────────────────────────────────────────
router.post("/register",    validateRegister, register);
router.post("/verify-otp",  validateOtp,      verifyOtp);
router.post("/login",       validateLogin,    login);
router.post("/resend-otp",  resendOtp);
router.post("/google",      googleLogin);

// ── Protected ──────────────────────────────────────────────────────
router.use(protect); // all routes below require valid JWT

router.get("/me",                          getMe);
router.patch("/fcm-token",                 updateFcmToken);
router.patch("/kyc", restrictTo("driver"), submitKyc);

module.exports = router;
