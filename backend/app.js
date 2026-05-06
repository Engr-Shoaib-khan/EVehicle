require("dotenv").config();
const express     = require("express");
const cors        = require("cors");
const helmet      = require("helmet");
const morgan      = require("morgan");
const path        = require("path");
const fs          = require("fs");

const { globalErrorHandler } = require("./middleware/errorHandler");

const app = express();

let logger;
try {
    logger = require("./utils/logger");
} catch (err) {
    console.error("❌ ERROR: Utils missing!");
}

app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({ origin: process.env.CLIENT_URL || "*", credentials: true }));

// Stripe Webhook needs the raw body for signature verification
app.post("/api/payments/webhook", express.raw({ type: "application/json" }));

app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

if (logger) {
    app.use(morgan("dev", { stream: logger.morganStream }));
}

app.get("/", (req, res) => res.json({ success: true, message: "EV Ride API Running (Serverless Mode)" }));

try {
    app.use("/api/auth",     require("./routes/authRoutes"));
    app.use("/api/rides",    require("./routes/rides"));
    app.use("/api/drivers",  require("./routes/drivers"));
    app.use("/api/earnings", require("./routes/earningsRoutes"));
    app.use("/api/payments", require("./routes/paymentRoutes"));
    app.use("/api/kyc",      require("./routes/kycRoutes"));
} catch (err) {
    console.error("❌ ROUTE ERROR:", err.message);
}

app.use("/uploads", express.static("uploads"));
app.use(globalErrorHandler);

module.exports = app;
