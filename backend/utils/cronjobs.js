const cron = require("node-cron");
const Ride = require("../models/Ride");
const User = require("../models/User");
const logger = require("./logger");

const aggregateDailyEarnings = async () => {
  try {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const dayStart = new Date(yesterday.setHours(0, 0, 0, 0));
    const dayEnd = new Date(yesterday.setHours(23, 59, 59, 999));

    const snapshots = await Ride.aggregate([
      { $match: { status: "completed", completedAt: { $gte: dayStart, $lte: dayEnd } } },
      { $group: { _id: "$driver", totalRides: { $sum: 1 }, totalEarned: { $sum: "$fare.final" }, totalKm: { $sum: "$distanceKm" } } }
    ]);

    for (const snap of snapshots) {
      if (!snap._id) continue;
      await User.findByIdAndUpdate(snap._id, {
        $inc: { "earnings.pendingPayout": snap.totalEarned },
        $push: {
          "earnings.earningsLog": {
            $each: [{ date: dayStart, amount: snap.totalEarned, ridesCount: snap.totalRides, distance: parseFloat(snap.totalKm.toFixed(2)) }],
            $slice: -90
          }
        }
      });
    }
    logger.info(`[CRON] Daily earnings processed.`);
  } catch (err) { logger.error("[CRON] Error:", err.message); }
};

const startAllJobs = (io = null) => {
  cron.schedule("5 0 * * *", aggregateDailyEarnings);
  logger.info("[CRON] Background jobs started.");
};

module.exports = { startAllJobs };