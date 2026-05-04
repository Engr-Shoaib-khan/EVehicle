const express  = require("express");
const User     = require("../models/User");
const { protect, restrictTo } = require("../middleware/auth");
const { AppError }            = require("../middleware/errorHandler");

const router = express.Router();
router.use(protect);

// GET /api/drivers/nearby?lat=&lng=&radiusKm=
router.get("/nearby", restrictTo("rider"), async (req, res, next) => {
  try {
    const lat      = parseFloat(req.query.lat);
    const lng      = parseFloat(req.query.lng);
    const radiusKm = parseFloat(req.query.radiusKm || "5");

    if (isNaN(lat) || isNaN(lng)) return next(new AppError("lat and lng query params are required.", 400));
    if (radiusKm < 0.5 || radiusKm > 20) return next(new AppError("radiusKm must be between 0.5 and 20.", 400));

    const drivers = await User.find({
      role: "driver", isOnline: true, isActive: true, "kyc.status": "approved",
      currentLocation: { $near: { $geometry: { type: "Point", coordinates: [lng, lat] }, $maxDistance: radiusKm * 1000 } },
    }).select("fullName avatarUrl rating vehicleInfo currentLocation").limit(20);

    const payload = drivers.map((d) => ({
      id:      d._id,
      name:    d.fullName,
      avatar:  d.avatarUrl,
      rating:  d.rating.average,
      vehicle: d.vehicleInfo,
      location: { lat: d.currentLocation.coordinates[1], lng: d.currentLocation.coordinates[0] },
    }));

    return res.status(200).json({ success: true, count: payload.length, data: payload });
  } catch (err) { next(err); }
});

// PATCH /api/drivers/location  (driver updates GPS)
router.patch("/location", restrictTo("driver"), async (req, res, next) => {
  try {
    const { lat, lng } = req.body;
    if (lat == null || lng == null) return next(new AppError("lat and lng are required.", 400));
    const latN = parseFloat(lat), lngN = parseFloat(lng);
    if (isNaN(latN) || isNaN(lngN) || latN < -90 || latN > 90 || lngN < -180 || lngN > 180) {
      return next(new AppError("Invalid coordinate values.", 400));
    }
    await User.findByIdAndUpdate(req.user._id, { "currentLocation.coordinates": [lngN, latN] });
    return res.status(200).json({ success: true, message: "Location updated." });
  } catch (err) { next(err); }
});

// PATCH /api/drivers/toggle-online
router.patch("/toggle-online", restrictTo("driver"), async (req, res, next) => {
  try {
    const { isOnline, lat, lng } = req.body;
    if (typeof isOnline !== "boolean" && isOnline !== "true" && isOnline !== "false") {
      return next(new AppError("isOnline must be a boolean.", 400));
    }
    const online = isOnline === true || isOnline === "true";
    const update = { isOnline: online };
    if (online && lat != null && lng != null) {
      update["currentLocation.coordinates"] = [parseFloat(lng), parseFloat(lat)];
    }
    const user = await User.findByIdAndUpdate(req.user._id, update, { new: true });
    return res.status(200).json({ success: true, isOnline: user.isOnline, message: user.isOnline ? "You are online." : "You are offline." });
  } catch (err) { next(err); }
});

// GET /api/drivers/me/stats  (driver performance summary)
router.get("/me/stats", restrictTo("driver"), async (req, res, next) => {
  try {
    const Ride = require("../models/Ride");
    const [total, completed, cancelled] = await Promise.all([
      Ride.countDocuments({ driver: req.user._id }),
      Ride.countDocuments({ driver: req.user._id, status: "completed" }),
      Ride.countDocuments({ driver: req.user._id, status: "cancelled" }),
    ]);
    const earnings = await Ride.aggregate([
      { $match: { driver: req.user._id, status: "completed", paymentStatus: "completed" } },
      { $group: { _id: null, total: { $sum: "$fare.final" } } },
    ]);
    return res.status(200).json({
      success: true,
      data: {
        totalRides:     total,
        completedRides: completed,
        cancelledRides: cancelled,
        acceptanceRate: total > 0 ? parseFloat(((completed / total) * 100).toFixed(1)) : 0,
        totalEarnings:  earnings[0]?.total || 0,
        rating:         req.user.rating,
      },
    });
  } catch (err) { next(err); }
});

module.exports = router;
