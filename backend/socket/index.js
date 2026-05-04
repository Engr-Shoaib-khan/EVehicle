const jwt  = require("jsonwebtoken");
const User = require("../models/User");

const socketAuth = async (socket, next) => {
  try {
    const token = socket.handshake.auth?.token || socket.handshake.headers?.authorization?.replace("Bearer ", "");
    if (!token || token === "null" || token === "undefined") return next(new Error("AUTH_MISSING"));
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user    = await User.findById(decoded.id).select("_id fullName role isActive isOnline");
    if (!user)          return next(new Error("AUTH_INVALID: User not found."));
    if (!user.isActive) return next(new Error("AUTH_INACTIVE: Account deactivated."));
    socket.user = user;
    next();
  } catch (err) {
    const msg = err.name === "TokenExpiredError" ? "AUTH_EXPIRED" : err.name === "JsonWebTokenError" ? "AUTH_INVALID" : err.message;
    next(new Error(msg));
  }
};

const initSocket = (io) => {
  io.use(socketAuth);

  io.on("connection", async (socket) => {
    const { user } = socket;
    console.log(`[SOCKET] Connected: ${user.fullName} (${user.role}) [${socket.id}]`);
    socket.join(`user_${user._id}`);

    if (user.role === "driver") {
      socket.on("driver:go_online", async ({ coordinates } = {}) => {
        try {
          if (!Array.isArray(coordinates) || coordinates.length !== 2 || isNaN(coordinates[0]) || isNaN(coordinates[1])) {
            return socket.emit("error", { code: "INVALID_COORDS", message: "Send coordinates as [longitude, latitude]." });
          }
          await User.findByIdAndUpdate(user._id, { isOnline: true, currentLocation: { type: "Point", coordinates } });
          socket.emit("driver:status_updated", { isOnline: true, message: "You are online." });
          console.log(`[SOCKET] Driver ${user.fullName} online @ [${coordinates}]`);
        } catch (err) {
          console.error("[SOCKET] driver:go_online:", err.message);
          socket.emit("error", { code: "SERVER_ERROR", message: "Failed to update status." });
        }
      });

      socket.on("driver:update_location", async ({ coordinates, rideId } = {}) => {
        try {
          if (!Array.isArray(coordinates) || coordinates.length !== 2) return;
          await User.findByIdAndUpdate(user._id, { "currentLocation.coordinates": coordinates });
          if (rideId) {
            io.to(`ride_${rideId}`).emit("driver:location_update", { coordinates, rideId, timestamp: new Date().toISOString() });
          }
        } catch (err) { console.error("[SOCKET] driver:update_location:", err.message); }
      });

      socket.on("driver:go_offline", async () => {
        try {
          await User.findByIdAndUpdate(user._id, { isOnline: false });
          socket.emit("driver:status_updated", { isOnline: false, message: "You are offline." });
          console.log(`[SOCKET] Driver ${user.fullName} offline.`);
        } catch (err) { console.error("[SOCKET] driver:go_offline:", err.message); }
      });
    }

    socket.on("join_ride_room",  ({ rideId } = {}) => { if (rideId) { socket.join(`ride_${rideId}`);  console.log(`[SOCKET] ${user.fullName} joined ride_${rideId}`); } });
    socket.on("leave_ride_room", ({ rideId } = {}) => { if (rideId) socket.leave(`ride_${rideId}`); });

    socket.on("disconnect", async (reason) => {
      console.log(`[SOCKET] Disconnected: ${user.fullName} - ${reason}`);
      if (user.role === "driver") User.findByIdAndUpdate(user._id, { isOnline: false }).catch(() => {});
    });

    socket.on("error", (err) => socket.emit("error", { code: "SOCKET_ERROR", message: err.message }));
  });

  return io;
};

module.exports = { initSocket };
