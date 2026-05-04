const User = require("../models/User");
const { AppError } = require("../middleware/errorHandler");
const logger = require("../utils/logger");

// ── UPLOAD KYC DOCUMENTS ──────────────────────────────────────────
exports.uploadKyc = async (req, res, next) => {
  try {
    if (!req.files || Object.keys(req.files).length === 0) {
      return next(new AppError("Please upload all required documents (CNIC Front, Back, License, Vehicle Reg).", 400));
    }

    const kycUpdate = {
      "kyc.status": "under_review",
    };
    if (req.files['cnic_front'])  kycUpdate["kyc.cnicFrontImage"] = req.files['cnic_front'][0].path;
    if (req.files['cnic_back'])   kycUpdate["kyc.cnicBackImage"]  = req.files['cnic_back'][0].path;
    if (req.files['vehicle_reg'])  kycUpdate["kyc.vehicleRegImage"] = req.files['vehicle_reg'][0].path;

    await User.findByIdAndUpdate(req.user._id, { $set: kycUpdate });

    logger.info(`[KYC] User ${req.user.fullName} uploaded documents for verification.`);

    res.status(200).json({
      success: true,
      message: "KYC documents uploaded successfully. Admin review pending.",
    });
  } catch (err) {
    next(err);
  }
};

// ── GET KYC STATUS ───────────────────────────────────────────────
exports.getKycStatus = async (req, res, next) => {
  try {
    const user = await User.findById(req.user._id).select("kyc");
    if (!user) return next(new AppError("User not found.", 404));

    res.status(200).json({
      success: true,
      data: {
        status: user.kyc?.status,
        documents: {
          cnicFront: user.kyc?.cnicFrontImage,
          cnicBack:  user.kyc?.cnicBackImage,
          license:   user.kyc?.licenseImage,
          vehicleReg: user.kyc?.vehicleRegImage,
        }
      }
    });
  } catch (err) {
    next(err);
  }
};

// ── ADMIN: REVIEW KYC ────────────────────────────────────────────
exports.reviewKyc = async (req, res, next) => {
  try {
    const { status } = req.body; // 'approved' or 'rejected'
    
    if (!['approved', 'rejected'].includes(status)) {
      return next(new AppError("Invalid status. Must be 'approved' or 'rejected'.", 400));
    }

    const user = await User.findByIdAndUpdate(
      req.params.userId,
      { $set: { "kyc.status": status, "kyc.reviewedAt": new Date() } },
      { new: true }
    );

    logger.info(`[KYC] Admin reviewed KYC for ${user.fullName}: ${status}`);

    res.status(200).json({
      success: true,
      message: `KYC status updated to ${status}.`,
    });
  } catch (err) {
    next(err);
  }
};