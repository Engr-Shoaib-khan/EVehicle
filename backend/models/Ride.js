const mongoose = require("mongoose");

// ─────────────────────────────────────────────────────────────────
// Ride Status Flow:
//
//  requested ──► searching ──► accepted ──► driver_arrived
//                    │                           │
//                    ▼                           ▼
//            no_drivers_found              in_progress
//                                               │
//                    ┌──────────────────────────┤
//                    ▼                          ▼
//                cancelled               completed
// ─────────────────────────────────────────────────────────────────

const GeoPointSchema = new mongoose.Schema(
  {
    type:        { type: String, enum: ["Point"], default: "Point" },
    coordinates: { type: [Number], required: true }, // [longitude, latitude]
    address:     { type: String, default: null },    // human-readable address
  },
  { _id: false }
);

const FareSchema = new mongoose.Schema(
  {
    estimated:   { type: Number, default: 0 }, // PKR, calculated at request time
    final:       { type: Number, default: 0 }, // PKR, set on completion
    currency:    { type: String, default: "PKR" },
    breakdown: {
      baseFare:       { type: Number, default: 0 },
      perKmCharge:    { type: Number, default: 0 },
      distanceCharge: { type: Number, default: 0 },
      platformFee:    { type: Number, default: 0 },
    },
  },
  { _id: false }
);

const RideSchema = new mongoose.Schema(
  {
    // ── Parties ────────────────────────────────────────────────────
    rider: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    driver: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null, // null until a driver accepts
    },

    // ── Status ─────────────────────────────────────────────────────
    status: {
      type: String,
      enum: [
        "requested",        // rider just submitted
        "searching",        // server is broadcasting to nearby drivers
        "accepted",         // a driver accepted
        "driver_arrived",   // driver is at pickup point
        "in_progress",      // rider is in the vehicle
        "completed",        // ride finished
        "cancelled",        // cancelled by rider or system
        "no_drivers_found", // broadcast timed out, no one accepted
      ],
      default: "requested",
      index: true,
    },

    // ── Locations ──────────────────────────────────────────────────
    pickupLocation:  { type: GeoPointSchema, required: true },
    dropoffLocation: { type: GeoPointSchema, required: true },

    // ── Fare & Distance ────────────────────────────────────────────
    fare:          { type: FareSchema, default: () => ({}) },
    distanceKm:    { type: Number, default: 0 },
    durationMins:  { type: Number, default: 0 },

    // ── Broadcast Tracking ─────────────────────────────────────────
    // Keeps track of which drivers received the ping
    broadcastedTo: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
    // Drivers who explicitly rejected this ride
    rejectedBy: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
    broadcastRadius: { type: Number, default: 5 }, // km
    broadcastCount:  { type: Number, default: 0 }, // how many drivers were pinged

    // ── Payment ────────────────────────────────────────────────────
    paymentMethod: {
      type: String,
      enum: ["cash", "stripe", "wallet"],
      default: "cash",
    },
    paymentStatus: {
      type: String,
      enum: ["pending", "completed", "refunded"],
      default: "pending",
    },
    stripePaymentIntentId: { type: String, default: null },

    // ── Ratings ────────────────────────────────────────────────────
    riderRating:  { type: Number, min: 1, max: 5, default: null },
    driverRating: { type: Number, min: 1, max: 5, default: null },
    riderComment:  { type: String, default: null },
    driverComment: { type: String, default: null },

    // ── Cancellation ───────────────────────────────────────────────
    cancelledBy:       { type: String, enum: ["rider", "driver", "system"], default: null },
    cancellationReason:{ type: String, default: null },

    // ── Timestamps ─────────────────────────────────────────────────
    acceptedAt:       { type: Date, default: null },
    driverArrivedAt:  { type: Date, default: null },
    tripStartedAt:    { type: Date, default: null },
    completedAt:      { type: Date, default: null },
    cancelledAt:      { type: Date, default: null },
    broadcastExpiresAt: { type: Date, default: null }, // TTL for broadcast window
  },
  {
    timestamps: true, // createdAt, updatedAt
  }
);

// ── Indexes ────────────────────────────────────────────────────────
RideSchema.index({ pickupLocation: "2dsphere" });
RideSchema.index({ dropoffLocation: "2dsphere" });
RideSchema.index({ rider: 1, status: 1 });
RideSchema.index({ driver: 1, status: 1 });
RideSchema.index({ status: 1, broadcastExpiresAt: 1 }); // for expiry cleanup job

module.exports = mongoose.model("Ride", RideSchema);
