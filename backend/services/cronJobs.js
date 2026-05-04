const cron   = require("node-cron");
const mongoose = require("mongoose");
const Ride   = require("../models/Ride");
const User   = require("../models/User");
const logger = require("../utils/logger");

// JOB 1: Expire stale "searching" rides
const expireStaleRides = async () => {
  try {
    const result = await Ride.updateMany(
      { status: "searching", broadcastExpiresAt: { $lt: new Date() } },
      {
        $set: {
          status: "no_drivers_found",
          cancelledAt: new Date(),
          cancelledBy: "system",
          cancellationReason: "Broadcast window expired (recovered by cron).",
        },
      }
    );
    if (result.modifiedCount > 0) logger.info(`[CRON] Expired ${result.modifiedCount} stale rides.`);
  } catch (err) {
    logger.error("[CRON] expireStaleRides error:", err);
  }
};

// JOB 2: Reset ghost drivers
const resetGhostDrivers = async (io) => {
  try {
    const connectedRooms = io ? [...io.sockets.adapter.rooms.keys()] : [];
    const connectedDriverIds = connectedRooms
      .filter((r) => r.startsWith("user_"))
      .map((r) => r.replace("user_", ""));

    const result = await User.updateMany(
      { role: "driver", isOnline: true, _id: { $nin: connectedDriverIds } },
      { $set: { isOnline: false } }
    );
    if (result.modifiedCount > 0) logger.info(`[CRON] Reset ${result.modifiedCount} ghost drivers.`);
  } catch (err) {
    logger.error("[CRON] resetGhostDrivers error:", err);
  }
};

// JOB 3: Daily earnings snapshot (Runs at 00:05)
const aggregateDailyEarnings = async () => {
  try {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const dayStart = new Date(yesterday.setHours(0, 0, 0, 0));
    const dayEnd   = new Date(yesterday.setHours(23, 59, 59, 999));

    const snapshots = await Ride.aggregate([
      { $match: { status: "completed", completedAt: { $gte: dayStart, $lte: dayEnd } } },
      {
        $group: {
          _id: "$driver",
          totalRides: { $sum: 1 },
          totalEarned: { $sum: "$fare.final" },
          totalKm: { $sum: "$distanceKm" },
        },
      },
    ]);

    for (const snap of snapshots) {
      if (!snap._id) continue;
      await User.findByIdAndUpdate(snap._id, {
        $push: {
          earningsLog: {
            $each: [{
              date: dayStart,
              totalRides: snap.totalRides,
              totalEarned: snap.totalEarned,
              totalKm: parseFloat(snap.totalKm.toFixed(2)),
            }],
            $slice: -90,
          },
        },
      });
    }
    logger.info(`[CRON] Daily earnings snapshot complete for ${dayStart.toDateString()}.`);
  } catch (err) {
    logger.error("[CRON] aggregateDailyEarnings error:", err);
  }
};

// JOB 4: Clean orphaned rides
const cleanOrphanedRides = async () => {
  try {
    const cutoff = new Date(Date.now() - 5 * 60 * 1000);
    const result = await Ride.updateMany(
      { status: "requested", createdAt: { $lt: cutoff } },
      { $set: { status: "cancelled", cancelledBy: "system", cancelledAt: new Date(), cancellationReason: "Orphaned ride cleaned." } }
    );
    if (result.modifiedCount > 0) logger.info(`[CRON] Cleaned ${result.modifiedCount} orphaned rides.`);
  } catch (err) {
    logger.error("[CRON] cleanOrphanedRides error:", err);
  }
};

// JOB 5: Platform Stats
const logPlatformStats = async () => {
  try {
    const [active, online, today] = await Promise.all([
      Ride.countDocuments({ status: { $in: ["searching","accepted","driver_arrived","in_progress"] } }),
      User.countDocuments({ role: "driver", isOnline: true }),
      Ride.countDocuments({ status: "completed", completedAt: { $gte: new Date(new Date().setHours(0,0,0,0)) } }),
    ]);
    logger.info("[CRON] Platform stats", { activeRides: active, onlineDrivers: online, todayCompleted: today });
  } catch (err) {
    logger.error("[CRON] logPlatformStats error:", err);
  }
};

// BOOT FUNCTION
const startAllJobs = (io = null) => {
  cron.schedule("*/2 * * * *", expireStaleRides);
  cron.schedule("*/10 * * * *", () => resetGhostDrivers(io));
  cron.schedule("*/5 * * * *", cleanOrphanedRides);
  cron.schedule("0 * * * *", logPlatformStats);
  cron.schedule("5 0 * * *", aggregateDailyEarnings);
  logger.info("[CRON] All 5 background jobs started.");
};

module.exports = { startAllJobs };