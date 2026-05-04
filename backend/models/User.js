const mongoose = require("mongoose");
const bcrypt   = require("bcryptjs");
const crypto   = require("crypto");

const CNIC_REGEX = /^\d{5}-\d{7}-\d{1}$/;

const KYCSchema = new mongoose.Schema(
  {
    cnic:            { type: String, trim: true, validate: { validator: (v) => CNIC_REGEX.test(v), message: "CNIC must follow Pakistani format: XXXXX-XXXXXXX-X" } },
    cnicFrontImage:  { type: String, default: null },
    cnicBackImage:   { type: String, default: null },
    licenseNumber:   { type: String, default: null },
    licenseImage:    { type: String, default: null },
    vehicleRegImage: { type: String, default: null },
    status:          { type: String, enum: ["pending", "under_review", "approved", "rejected"], default: "pending" },
    reviewedAt:      { type: Date,   default: null },
    rejectionReason: { type: String, default: null },
  },
  { _id: false }
);

const UserSchema = new mongoose.Schema(
  {
    fullName: {
      type: String, required: [true, "Full name is required"],
      trim: true, minlength: 2, maxlength: 80,
    },
    email: {
      type: String, required: [true, "Email is required"],
      unique: true, lowercase: true, trim: true,
      match: [/\S+@\S+\.\S+/, "Invalid email format"],
    },
    phoneNumber: {
      type: String, required: [true, "Phone number is required"],
      unique: true, trim: true,
      match: [/^(\+92|0)3[0-9]{9}$/, "Phone must be a valid Pakistani mobile number"],
    },
    password: {
      type: String, required: [true, "Password is required"],
      minlength: 8, select: false,
    },
    role:     { type: String, enum: ["rider", "driver", "admin"], required: true },
    isActive: { type: Boolean, default: true },

    // OTP Email Verification
    isEmailVerified: { type: Boolean, default: false },
    otpCode:         { type: String, default: null, select: false },
    otpExpires:      { type: Date,   default: null, select: false },

    avatarUrl: { type: String, default: null },
    fcmToken:  { type: String, default: null },

    // Driver-only
    kyc: { type: KYCSchema, default: () => ({}) },
    vehicleInfo: {
      make:         { type: String, default: null },
      model:        { type: String, default: null },
      year:         { type: Number, default: null },
      color:        { type: String, default: null },
      plateNumber:  { type: String, default: null },
      batteryRange: { type: Number, default: null },
    },
    isOnline: { type: Boolean, default: false },
    currentLocation: {
      type:        { type: String, enum: ["Point"], default: "Point" },
      coordinates: { type: [Number], default: [0, 0] },
    },
    rating: {
      average:      { type: Number, default: 0, min: 0, max: 5 },
      totalRatings: { type: Number, default: 0 },
    },

    wallet: {
      balance: { type: Number, default: 0 },
      transactions: [
        {
          type:        { type: String, enum: ["credit", "debit"] },
          amount:      { type: Number },
          description: { type: String },
          date:        { type: Date, default: Date.now },
          reference:   { type: String }, // e.g. Ride ID or Stripe ID
        },
      ],
    },

    earnings: {
      totalEarned:    { type: Number, default: 0 },
      pendingPayout:  { type: Number, default: 0 },
      totalPaidOut:   { type: Number, default: 0 },
      payoutHistory:  [
        {
          amount:      { type: Number },
          status:      { type: String, enum: ["requested", "processing", "paid", "rejected"], default: "requested" },
          requestedAt: { type: Date, default: Date.now },
          processedAt: { type: Date },
          transactionId: { type: String }
        }
      ]
    },

    passwordResetToken:   { type: String, default: null, select: false },
    passwordResetExpires: { type: Date,   default: null, select: false },
  },
  { timestamps: true }
);

UserSchema.index({ currentLocation: "2dsphere" });
UserSchema.index({ role: 1, isOnline: 1 });

UserSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();
  const salt = await bcrypt.genSalt(12);
  this.password = await bcrypt.hash(this.password, salt);
  next();
});

UserSchema.methods.comparePassword = async function (candidate) {
  return bcrypt.compare(candidate, this.password);
};

UserSchema.methods.generateOTP = function () {
  const otp = process.env.NODE_ENV === "development" 
    ? "123456" 
    : Math.floor(100000 + Math.random() * 900000).toString();
    
  this.otpCode    = crypto.createHash("sha256").update(otp).digest("hex");
  this.otpExpires = new Date(Date.now() + 10 * 60 * 1000); // 10 min
  return otp;
};

UserSchema.methods.verifyOTP = function (candidate) {
  const hashed = crypto.createHash("sha256").update(candidate).digest("hex");
  return this.otpCode === hashed && this.otpExpires > new Date();
};

UserSchema.methods.toPublicProfile = function () {
  return {
    id:              this._id,
    fullName:        this.fullName,
    email:           this.email,
    phoneNumber:     this.phoneNumber,
    role:            this.role,
    avatarUrl:       this.avatarUrl,
    isActive:        this.isActive,
    isEmailVerified: this.isEmailVerified,
    ...(this.role === "driver" && {
      kyc:         this.kyc,
      vehicleInfo: this.vehicleInfo,
      isOnline:    this.isOnline,
      rating:      this.rating,
    }),
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model("User", UserSchema);
