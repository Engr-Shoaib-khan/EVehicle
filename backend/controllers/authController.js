const jwt             = require("jsonwebtoken");
const User            = require("../models/User");
const { sendOtpEmail } = require("../services/otpService");
const { AppError }    = require("../middleware/errorHandler");

const { OAuth2Client } = require("google-auth-library");
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// GOOGLE LOGIN  POST /api/auth/google
exports.googleLogin = async (req, res, next) => {
  try {
    const { idToken, role = "rider" } = req.body;
    if (!idToken) return next(new AppError("Google ID Token is required.", 400));

    // Verify Google Token
    const ticket = await client.verifyIdToken({
      idToken,
      audience: [
        process.env.GOOGLE_CLIENT_ID_ANDROID,
        process.env.GOOGLE_CLIENT_ID_IOS,
        process.env.GOOGLE_CLIENT_ID_WEB,
      ].filter(Boolean),
    });

    const payload = ticket.getPayload();
    const { sub, email, name, picture } = payload;

    // Find or Create User
    let user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      user = await User.create({
        fullName: name,
        email: email.toLowerCase(),
        password: require("crypto").randomBytes(16).toString("hex"), // Dummy pass
        role,
        isEmailVerified: true, // Google emails are already verified
        avatarUrl: picture,
        googleId: sub,
      });
    } else {
      // If user exists, update their Google ID if not present
      if (!user.googleId) {
        user.googleId = sub;
        if (!user.avatarUrl) user.avatarUrl = picture;
        await user.save({ validateBeforeSave: false });
      }
    }

    if (!user.isActive) return next(new AppError("Account deactivated.", 403));

    return tokenResponse(user, 200, res, "Google login successful.");
  } catch (err) {
    console.error("[GOOGLE AUTH ERROR]", err.message);
    return next(new AppError("Invalid Google token or authentication failed.", 401));
  }
};

const signToken = (id) =>
  jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || "7d",
    algorithm: "HS256", // Explicitly set a strong algorithm
  });

const tokenResponse = (user, statusCode, res, message) =>
  res.status(statusCode).json({
    success: true,
    message,
    token:   signToken(user._id),
    user:    user.toPublicProfile(),
  });

// REGISTER  POST /api/auth/register
exports.register = async (req, res, next) => {
  try {
    const { fullName, email, password, phoneNumber, role } = req.body;
    const existing = await User.findOne({
      $or: [{ email: email.toLowerCase() }, { phoneNumber }],
    });
    if (existing) {
      const field = existing.email === email.toLowerCase() ? "email" : "phone number";
      return next(new AppError(`An account with this ${field} already exists.`, 409));
    }
    const userData = { fullName, email, password, phoneNumber, role };
    if (role === "driver") userData.kyc = { status: "pending" };
    const user     = new User(userData);
    const plainOtp = user.generateOTP();
    await user.save();
    sendOtpEmail(user.email, user.fullName, plainOtp, user.role).catch((err) =>
      console.error("[OTP EMAIL FAILED]", user.email, err.message)
    );
    return res.status(201).json({
      success: true,
      message: `Account created! A 6-digit code was sent to ${user.email}.`,
      email:   user.email,
    });
  } catch (err) { next(err); }
};

// VERIFY OTP  POST /api/auth/verify-otp
exports.verifyOtp = async (req, res, next) => {
  try {
    const { email, otp } = req.body;
    const user = await User.findOne({ email: email.toLowerCase() })
      .select("+otpCode +otpExpires");
    if (!user) return next(new AppError("No account found with this email.", 404));
    if (user.isEmailVerified) return next(new AppError("Email already verified. Please log in.", 400));
    if (!user.verifyOTP(String(otp).trim())) {
      return next(new AppError("Invalid or expired OTP. Please request a new code.", 400));
    }
    user.isEmailVerified = true;
    user.otpCode         = null;
    user.otpExpires      = null;
    await user.save({ validateBeforeSave: false });
    return tokenResponse(user, 200, res, "Email verified! Welcome to EV Ride.");
  } catch (err) { next(err); }
};

// LOGIN  POST /api/auth/login
exports.login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email: email.toLowerCase() }).select("+password");
    if (!user || !(await user.comparePassword(password))) {
      return next(new AppError("Invalid email or password.", 401));
    }
    if (!user.isEmailVerified) {
      const plainOtp = user.generateOTP();
      await user.save({ validateBeforeSave: false });
      sendOtpEmail(user.email, user.fullName, plainOtp, user.role).catch((err) =>
        console.error("[OTP RESEND FAILED]", user.email, err.message)
      );
      return res.status(403).json({
        success:     false,
        message:     "Email not verified. A new code has been sent to your inbox.",
        requiresOtp: true,
        email:       user.email,
      });
    }
    if (!user.isActive) return next(new AppError("Account deactivated. Contact support.", 403));
    return tokenResponse(user, 200, res, "Login successful.");
  } catch (err) { next(err); }
};

// RESEND OTP  POST /api/auth/resend-otp
exports.resendOtp = async (req, res, next) => {
  try {
    const { email } = req.body;
    if (!email) return next(new AppError("Email is required.", 400));
    const user = await User.findOne({ email: email.toLowerCase() }).select("+otpExpires");
    // Always same response to prevent enumeration
    if (!user || user.isEmailVerified) {
      return res.status(200).json({ success: true, message: "If unverified, a new code has been sent." });
    }
    const sentLessThanMinuteAgo = user.otpExpires && user.otpExpires.getTime() > Date.now() + 9 * 60 * 1000;
    if (sentLessThanMinuteAgo) {
      return next(new AppError("Please wait 60 seconds before requesting another code.", 429));
    }
    const plainOtp = user.generateOTP();
    await user.save({ validateBeforeSave: false });
    sendOtpEmail(user.email, user.fullName, plainOtp, user.role).catch((err) =>
      console.error("[OTP RESEND FAILED]", user.email, err.message)
    );
    return res.status(200).json({ success: true, message: "If unverified, a new code has been sent." });
  } catch (err) { next(err); }
};

// GET ME  GET /api/auth/me
exports.getMe = (req, res) => {
  res.status(200).json({ success: true, user: req.user.toPublicProfile() });
};

// UPDATE FCM TOKEN  PATCH /api/auth/fcm-token
exports.updateFcmToken = async (req, res, next) => {
  try {
    const { fcmToken } = req.body;
    if (!fcmToken) return next(new AppError("fcmToken is required.", 400));
    await User.findByIdAndUpdate(req.user._id, { fcmToken });
    res.status(200).json({ success: true, message: "FCM token updated." });
  } catch (err) { next(err); }
};

// SUBMIT KYC  PATCH /api/auth/kyc  (driver only)
exports.submitKyc = async (req, res, next) => {
  try {
    if (req.user.role !== "driver") return next(new AppError("Only drivers can submit KYC.", 403));
    const { cnic, licenseNumber } = req.body;
    if (!cnic) return next(new AppError("CNIC is required.", 400));
    const user = await User.findByIdAndUpdate(
      req.user._id,
      { $set: { "kyc.cnic": cnic, "kyc.licenseNumber": licenseNumber || null, "kyc.status": "under_review" } },
      { new: true, runValidators: true }
    );
    res.status(200).json({ success: true, message: "KYC submitted. Review within 24 hours.", kyc: user.kyc });
  } catch (err) { next(err); }
};
