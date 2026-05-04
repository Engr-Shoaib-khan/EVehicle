const winston = require("winston");
const path    = require("path");

// ── Log directory: backend/logs/ ──────────────────────────────────
const LOG_DIR = path.join(process.cwd(), "logs");

// ── Custom log format ─────────────────────────────────────────────
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss" }),
  winston.format.errors({ stack: true }),   // include stack traces
  winston.format.splat(),
  winston.format.json()
);

// ── Console format (dev only — human-readable) ────────────────────
const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({ format: "HH:mm:ss" }),
  winston.format.printf(({ timestamp, level, message, stack }) =>
    stack
      ? `[${timestamp}] ${level}: ${message}\n${stack}`
      : `[${timestamp}] ${level}: ${message}`
  )
);

// ── Transports ────────────────────────────────────────────────────
const transports = [
  // Error log — persistent, errors only
  new winston.transports.File({
    filename:   path.join(LOG_DIR, "error.log"),
    level:      "error",
    maxsize:    5 * 1024 * 1024,   // 5 MB
    maxFiles:   5,
    tailable:   true,
    format:     logFormat,
  }),
  // Combined log — all levels
  new winston.transports.File({
    filename:   path.join(LOG_DIR, "combined.log"),
    maxsize:    10 * 1024 * 1024,  // 10 MB
    maxFiles:   10,
    tailable:   true,
    format:     logFormat,
  }),
];

// Console transport in dev only
if (process.env.NODE_ENV !== "production") {
  transports.push(
    new winston.transports.Console({ format: consoleFormat })
  );
} else {
  // In production, also log errors to console for container stdout capture
  transports.push(
    new winston.transports.Console({
      level:  "error",
      format: logFormat,
    })
  );
}

// ── Create logger ─────────────────────────────────────────────────
const logger = winston.createLogger({
  level:             process.env.LOG_LEVEL || "info",
  defaultMeta:       { service: "ev-ride-api" },
  transports,
  exceptionHandlers: [
    new winston.transports.File({ filename: path.join(LOG_DIR, "exceptions.log") }),
  ],
  rejectionHandlers: [
    new winston.transports.File({ filename: path.join(LOG_DIR, "rejections.log") }),
  ],
});

// ── Morgan stream → Winston ───────────────────────────────────────
logger.morganStream = {
  write: (message) => logger.http(message.trim()),
};

module.exports = logger;
