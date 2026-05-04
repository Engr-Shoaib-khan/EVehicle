const express  = require("express");
const Ride     = require("../models/Ride");
const User     = require("../models/User");
const { protect, restrictTo }                                          = require("../middleware/auth");
const { validateRideRequest }                                          = require("../middleware/validate");
const { AppError }                                                     = require("../middleware/errorHandler");
const { calculateFare, haversineKm, estimateDurationMins, findNearbyDrivers, broadcastRideRequest, scheduleBroadcastExpiry, BROADCAST_TTL_SECONDS } = require("../services/broadcastService");

const router = express.Router();
router.use(protect);

// POST /api/rides/request
router.post("/request", restrictTo("rider"), validateRideRequest, async (req, res, next) => {
  try {
    const { pickupCoordinates, pickupAddress, dropoffCoordinates, dropoffAddress, paymentMethod = "cash", vehicleTypeId = "ev_bike" } = req.body;

    // Block if active ride exists
    const active = await Ride.findOne({
      rider:  req.user._id,
      status: { $in: ["requested","searching","accepted","driver_arrived","in_progress"] },
    });
    if (active) return next(new AppError("You have an active ride. Complete or cancel it first.", 409));

    const distanceKm   = haversineKm(pickupCoordinates, dropoffCoordinates);
    const durationMins = estimateDurationMins(distanceKm);
    const fare         = calculateFare(distanceKm, vehicleTypeId);
    const expiresAt    = new Date(Date.now() + BROADCAST_TTL_SECONDS * 1000);

    const ride = await Ride.create({
      rider:           req.user._id,
      status:          "searching",
      pickupLocation:  { type: "Point", coordinates: pickupCoordinates, address: pickupAddress || null },
      dropoffLocation: { type: "Point", coordinates: dropoffCoordinates, address: dropoffAddress || null },
      distanceKm,
      durationMins,
      fare,
      vehicleTypeId,
      paymentMethod,
      broadcastExpiresAt: expiresAt,
    });

    const nearbyDrivers = await findNearbyDrivers(pickupCoordinates, 5);
    if (nearbyDrivers.length === 0) {
      await Ride.findByIdAndUpdate(ride._id, { status: "no_drivers_found", cancelledAt: new Date(), cancelledBy: "system", cancellationReason: "No drivers available." });
      return res.status(200).json({ success: false, message: "No drivers available in your area. Please try again." });
    }

    const driverIds = nearbyDrivers.map((d) => d._id);
    await Ride.findByIdAndUpdate(ride._id, { broadcastedTo: driverIds, broadcastCount: driverIds.length });

    const io = req.app.get("io");
    broadcastRideRequest(io, ride, nearbyDrivers);
    scheduleBroadcastExpiry(io, ride._id);

    return res.status(201).json({
      success: true,
      message: `Ride broadcasted to ${nearbyDrivers.length} drivers.`,
      data:    { rideId: ride._id, status: "searching", distanceKm, durationMins, fare, driversNotified: nearbyDrivers.length, expiresAt },
    });
  } catch (err) { next(err); }
});

// POST /api/rides/:rideId/accept  (atomic — only one driver wins)
router.post("/:rideId/accept", restrictTo("driver"), async (req, res, next) => {
  try {
    const ride = await Ride.findOneAndUpdate(
      { _id: req.params.rideId, status: "searching", broadcastedTo: req.user._id, rejectedBy: { $nin: [req.user._id] }, broadcastExpiresAt: { $gt: new Date() } },
      { $set: { driver: req.user._id, status: "accepted", acceptedAt: new Date() } },
      { new: true }
    ).populate("rider", "fullName phone fcmToken _id");

    if (!ride) return next(new AppError("Ride no longer available. Another driver may have accepted it.", 409));

    // Mark driver busy
    await User.findByIdAndUpdate(req.user._id, { isOnline: false });

    const io = req.app.get("io");
    if (io) {
      const driverProfile = await User.findById(req.user._id).select("fullName phone avatarUrl rating vehicleInfo currentLocation");
      io.to(`user_${ride.rider._id}`).emit("ride_accepted", { rideId: ride._id.toString(), driver: driverProfile, message: "A driver has accepted your ride!" });
      ride.broadcastedTo.forEach((id) => {
        if (id.toString() !== req.user._id.toString()) {
          io.to(`user_${id}`).emit("ride_taken", { rideId: ride._id.toString() });
        }
      });
    }

    return res.status(200).json({
      success: true,
      message: "Ride accepted! Head to the pickup location.",
      data:    { rideId: ride._id, rider: ride.rider, pickupLocation: ride.pickupLocation, dropoffLocation: ride.dropoffLocation, distanceKm: ride.distanceKm, fare: ride.fare, paymentMethod: ride.paymentMethod },
    });
  } catch (err) { next(err); }
});

// POST /api/rides/:rideId/reject
router.post("/:rideId/reject", restrictTo("driver"), async (req, res, next) => {
  try {
    await Ride.findOneAndUpdate({ _id: req.params.rideId, status: "searching" }, { $addToSet: { rejectedBy: req.user._id } });
    res.status(200).json({ success: true, message: "Ride rejected." });
  } catch (err) { next(err); }
});

// PATCH /api/rides/:rideId/status  (driver advances status through lifecycle)
const TRANSITIONS = { accepted: "driver_arrived", driver_arrived: "in_progress", in_progress: "completed" };

router.patch("/:rideId/status", restrictTo("driver"), async (req, res, next) => {
  try {
    const { newStatus } = req.body;
    if (!newStatus) return next(new AppError("newStatus is required.", 400));

    const ride = await Ride.findOne({ _id: req.params.rideId, driver: req.user._id });
    if (!ride) return next(new AppError("Ride not found or you are not the assigned driver.", 404));

    const allowed = TRANSITIONS[ride.status];
    if (!allowed || allowed !== newStatus) {
      return next(new AppError(`Cannot transition from '${ride.status}' to '${newStatus}'. Expected: '${allowed}'.`, 400));
    }

    const update = { status: newStatus };
    if (newStatus === "driver_arrived") update.driverArrivedAt = new Date();
    if (newStatus === "in_progress")    update.tripStartedAt   = new Date();
    if (newStatus === "completed") {
      update.completedAt   = new Date();
      update.paymentStatus = ride.paymentMethod === "cash" ? "completed" : "pending";
      update["fare.final"] = ride.fare.estimated;
    }

    const updated = await Ride.findByIdAndUpdate(ride._id, { $set: update }, { new: true }).populate("rider", "_id");
    if (newStatus === "completed") await User.findByIdAndUpdate(req.user._id, { isOnline: true });

    const io = req.app.get("io");
    if (io) {
      const msgs = { driver_arrived: "Your driver has arrived!", in_progress: "Your trip has started!", completed: "You have arrived. Thanks for riding!" };
      const payload = { rideId: updated._id.toString(), newStatus, message: msgs[newStatus] || newStatus };
      
      io.to(`user_${updated.rider._id}`).emit("ride_status_update", payload);
      io.to(`ride_${updated._id}`).emit("ride_status_update", payload);
    }

    return res.status(200).json({ success: true, message: `Status updated to: ${newStatus}`, data: { rideId: ride._id, status: newStatus } });
  } catch (err) { next(err); }
});

// DELETE /api/rides/:rideId/cancel  (rider cancels)
router.delete("/:rideId/cancel", restrictTo("rider"), async (req, res, next) => {
  try {
    const { reason } = req.body;
    const ride = await Ride.findOneAndUpdate(
      { _id: req.params.rideId, rider: req.user._id, status: { $in: ["requested","searching","accepted"] } },
      { $set: { status: "cancelled", cancelledBy: "rider", cancellationReason: reason || "Rider cancelled.", cancelledAt: new Date() } },
      { new: true }
    );
    if (!ride) return next(new AppError("Ride cannot be cancelled at this stage.", 400));

    const io = req.app.get("io");
    if (ride.driver && io) {
      io.to(`user_${ride.driver}`).emit("ride_cancelled_by_rider", { rideId: ride._id.toString(), message: "The rider has cancelled the ride." });
      await User.findByIdAndUpdate(ride.driver, { isOnline: true });
    }

    return res.status(200).json({ success: true, message: "Ride cancelled." });
  } catch (err) { next(err); }
});

// GET /api/rides/history/me
router.get("/history/me", async (req, res, next) => {
  try {
    const isDriver = req.user.role === "driver";
    const filter = {
      [isDriver ? "driver" : "rider"]: req.user._id,
      status: { $in: ["completed","cancelled","no_drivers_found"] },
    };
    const page  = Math.max(1, parseInt(req.query.page  || "1"));
    const limit = Math.min(50, parseInt(req.query.limit || "20"));
    const skip  = (page - 1) * limit;

    const [rides, total] = await Promise.all([
      Ride.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit)
        .populate("rider",  "fullName avatarUrl")
        .populate("driver", "fullName avatarUrl rating"),
      Ride.countDocuments(filter),
    ]);

    return res.status(200).json({ success: true, total, page, limit, count: rides.length, data: rides });
  } catch (err) { next(err); }
});

// GET /api/rides/:rideId
router.get("/:rideId", async (req, res, next) => {
  try {
    const ride = await Ride.findOne({
      _id: req.params.rideId,
      $or: [{ rider: req.user._id }, { driver: req.user._id }],
    })
      .populate("rider",  "fullName phone avatarUrl")
      .populate("driver", "fullName phone avatarUrl rating vehicleInfo");
    if (!ride) return next(new AppError("Ride not found.", 404));
    return res.status(200).json({ success: true, data: ride });
  } catch (err) { next(err); }
});

module.exports = router;
