const User  = require("../models/User");
const Ride  = require("../models/Ride");
const { notifyDriversOfNewRide } = require("./fcmService");

const FARE = {
  ev_bike:     { base: 50,  perKm: 20, platform: 15 },
  ev_rickshaw: { base: 80,  perKm: 28, platform: 20 },
  ev_car:      { base: 150, perKm: 40, platform: 30 },
  ev_van:      { base: 200, perKm: 50, platform: 40 },
};

const calculateFare = (distanceKm, vehicleTypeId = "ev_bike") => {
  const cfg            = FARE[vehicleTypeId] || FARE.ev_bike;
  const distanceCharge = parseFloat((distanceKm * cfg.perKm).toFixed(2));
  const estimated      = Math.round(cfg.base + distanceCharge + cfg.platform);
  return {
    estimated,
    currency:  "PKR",
    breakdown: {
      baseFare:       cfg.base,
      perKmCharge:    cfg.perKm,
      distanceKm:     parseFloat(distanceKm.toFixed(2)),
      distanceCharge,
      platformFee:    cfg.platform,
    },
  };
};

const haversineKm = ([lon1, lat1], [lon2, lat2]) => {
  const R    = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a    = Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return parseFloat((R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))).toFixed(3));
};

const estimateDurationMins = (distanceKm) => Math.max(3, Math.round((distanceKm / 25) * 60));

const findNearbyDrivers = async (pickupCoords, radiusKm = 5, excludeIds = []) =>
  User.find({
    role: "driver", isOnline: true, isActive: true, "kyc.status": "approved",
    _id: { $nin: excludeIds },
    currentLocation: {
      $near: {
        $geometry:   { type: "Point", coordinates: pickupCoords },
        $maxDistance: radiusKm * 1000,
      },
    },
  }).select("_id fullName phone rating currentLocation fcmToken vehicleInfo gender batterySoc");

const BROADCAST_TTL_SECONDS = 60;

const broadcastRideRequest = async (io, ride, drivers) => {
  const payload = {
    rideId:           ride._id.toString(),
    pickupLocation:   ride.pickupLocation,
    dropoffLocation:  ride.dropoffLocation,
    distanceKm:       ride.distanceKm,
    durationMins:     ride.durationMins,
    fare:             ride.fare,
    vehicleTypeId:    ride.vehicleTypeId,
    paymentMethod:    ride.paymentMethod,
    genderPreference: ride.genderPreference,
    expiresAt:        ride.broadcastExpiresAt,
  };

  // 1. Socket.IO — real-time (app in foreground)
  let socketSent = 0;
  if (io) {
    drivers.forEach((driver) => {
      const room = `user_${driver._id}`;
      if (io.sockets.adapter.rooms.has(room)) {
        io.to(room).emit("new_ride_request", payload);
        socketSent++;
      }
    });
    console.log(`[BROADCAST] Socket → ${socketSent}/${drivers.length} connected drivers`);
  }

  // 2. FCM push — background/killed app
  notifyDriversOfNewRide(drivers, ride).catch((e) =>
    console.error("[BROADCAST] FCM error:", e.message)
  );
};

const scheduleBroadcastExpiry = (io, rideId) => {
  setTimeout(async () => {
    try {
      const ride = await Ride.findOneAndUpdate(
        { _id: rideId, status: "searching" },
        {
          $set: {
            status:             "no_drivers_found",
            cancelledAt:        new Date(),
            cancelledBy:        "system",
            cancellationReason: "No drivers accepted within the broadcast window.",
          },
        },
        { new: true }
      ).populate("rider", "_id");

      if (ride && io) {
        io.to(`user_${ride.rider._id}`).emit("no_drivers_found", {
          rideId:  rideId.toString(),
          message: "No drivers available right now. Please try again.",
        });
        console.log(`[BROADCAST] Ride ${rideId} expired.`);
      }
    } catch (err) {
      console.error("[BROADCAST EXPIRY ERROR]", err.message);
    }
  }, BROADCAST_TTL_SECONDS * 1000);
};

module.exports = {
  calculateFare,
  haversineKm,
  estimateDurationMins,
  findNearbyDrivers,
  broadcastRideRequest,
  scheduleBroadcastExpiry,
  BROADCAST_TTL_SECONDS,
};
