const http = require("http");
const { Server } = require("socket.io");
const app = require("./app");
const connectDB = require("./config/db");
const { initSocket } = require("./socket/index");

let startAllJobs;
try {
    startAllJobs = require("./services/cronJobs").startAllJobs;
} catch (err) {
    console.error("❌ ERROR: Services missing!");
}

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: process.env.CLIENT_URL || "*", methods: ["GET","POST"] },
  transports: ["polling","websocket"],
});

app.set("io", io);
initSocket(io);

if (process.env.NODE_ENV !== "test") {
  connectDB();
}

const PORT = process.env.PORT || 5000;
if (process.env.NODE_ENV !== "test") {
  server.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 [SERVER] Running on http://localhost:${PORT}`);
    try { if (startAllJobs) startAllJobs(io); } catch (err) { console.error("❌ CRON ERROR:", err.message); }
  });
}

module.exports = { app, server };
