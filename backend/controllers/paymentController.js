const mongoose = require("mongoose"); // Isay maine fix kar diya hai
const Ride = require("../models/Ride");
const User = require("../models/User");
const { AppError } = require("../middleware/errorHandler");
const logger = require("../utils/logger");

const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);

exports.createCheckoutSession = async (req, res, next) => {
  try {
    const { amount } = req.body;
    if (!amount || amount < 100) return next(new AppError("Minimum top-up is Rs. 100", 400));

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ["card"],
      line_items: [
        {
          price_data: {
            currency: "pkr",
            product_data: {
              name: "Wallet Top-up",
              description: "EV Ride App Wallet Credit",
            },
            unit_amount: amount * 100, // Stripe expects amount in cents/paisa
          },
          quantity: 1,
        },
      ],
      mode: "payment",
      success_url: `${process.env.CLIENT_URL}/payment-success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${process.env.CLIENT_URL}/payment-cancelled`,
      customer_email: req.user.email,
      metadata: {
        userId: req.user._id.toString(),
        type: "wallet_topup",
      },
    });

    res.status(200).json({ success: true, url: session.url, sessionId: session.id });
  } catch (err) {
    logger.error("Stripe Checkout Error:", err);
    next(err);
  }
};

exports.handleStripeWebhook = async (req, res) => {
  const sig = req.headers["stripe-signature"];
  let event;

  try {
    event = stripe.webhooks.constructEvent(
      req.body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    logger.error(`Webhook Error: ${err.message}`);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Handle the event
  if (event.type === "checkout.session.completed") {
    const session = event.data.object;

    if (session.metadata.type === "wallet_topup") {
      const userId = session.metadata.userId;
      const amount = session.amount_total / 100;

      try {
        const user = await User.findById(userId);
        if (user) {
          if (!user.wallet) user.wallet = { balance: 0, transactions: [] };
          user.wallet.balance += amount;
          user.wallet.transactions.push({
            type: "credit",
            amount,
            description: "Stripe Wallet Top-up",
            date: new Date(),
            reference: session.id
          });
          await user.save();
          logger.info(`Wallet topped up for user ${userId}: ${amount} PKR`);
        }
      } catch (err) {
        logger.error(`Error updating wallet for user ${userId}:`, err);
        return res.status(500).json({ message: "Internal server error" });
      }
    }
  }

  res.json({ received: true });
};

exports.getPaymentHistory = async (req, res, next) => {
  try {
    const page = Math.max(1, parseInt(req.query.page || "1"));
    const limit = Math.min(50, parseInt(req.query.limit || "20"));
    const filter = req.user.role === "driver" 
      ? { driver: req.user._id, paymentStatus: "completed" } 
      : { rider: req.user._id, paymentStatus: "completed" };

    const [rides, total] = await Promise.all([
      Ride.find(filter)
        .sort({ completedAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .select("fare paymentMethod paymentStatus completedAt distanceKm")
        .populate(req.user.role === "driver" ? "rider" : "driver", "fullName avatarUrl"),
      Ride.countDocuments(filter),
    ]);

    res.status(200).json({ success: true, total, page, data: rides });
  } catch (err) { next(err); }
};

exports.processManualPayment = async (req, res, next) => {
  const session = await mongoose.startSession();
  session.startTransaction();
  try {
    const { rideId } = req.params;
    const ride = await Ride.findById(rideId).session(session);
    if (!ride) return next(new AppError("Ride not found.", 404));
    if (ride.paymentStatus === "completed") return next(new AppError("Ride is already paid.", 400));

    ride.paymentStatus = "completed";
    await ride.save({ session });

    const amountToAdd = ride.fare.final || ride.fare;
    await User.findByIdAndUpdate(ride.driver, { $inc: { "earnings.pendingPayout": amountToAdd } }, { session });

    await session.commitTransaction();
    res.status(200).json({ success: true, message: "Payment confirmed.", data: ride });
  } catch (err) {
    await session.abortTransaction();
    next(err);
  } finally { session.endSession(); }
};

exports.getWalletDetails = async (req, res, next) => {
  try {
    const user = await User.findById(req.user._id).select("earnings wallet");
    res.status(200).json({
      success: true,
      data: {
        balance: user?.earnings?.pendingPayout || 0,
        walletBalance: user?.wallet?.balance || 0,
        totalPaidOut: user?.earnings?.totalPaidOut || 0,
        currency: "PKR"
      },
    });
  } catch (err) { next(err); }
};

exports.getWallet = exports.getWalletDetails;

exports.topUpWallet = async (req, res, next) => {
  try {
    const { amount } = req.body;
    if (!amount || amount <= 0) return next(new AppError("Invalid amount", 400));
    const user = await User.findById(req.user._id);
    if (!user.wallet) user.wallet = { balance: 0, transactions: [] };
    user.wallet.balance += Number(amount);
    user.wallet.transactions.push({ type: "credit", amount: Number(amount), description: "Wallet top-up", date: new Date() });
    await user.save();
    res.status(200).json({ success: true, balance: user.wallet.balance });
  } catch (err) { next(err); }
};

exports.getTransactions = async (req, res, next) => {
  try {
    const user = await User.findById(req.user._id).select("wallet");
    res.status(200).json({ success: true, data: (user?.wallet?.transactions || []).sort((a, b) => b.date - a.date) });
  } catch (err) { next(err); }
};

exports.getPresets = async (req, res, next) => {
  res.status(200).json({ success: true, data: [{ id: 1, amount: 500, label: "Rs. 500" }, { id: 2, amount: 1000, label: "Rs. 1,000" }] });
};

exports.completeRidePayment = async (req, res, next) => {
  const session = await mongoose.startSession();
  session.startTransaction();
  try {
    const { rideId } = req.params;
    const ride = await Ride.findById(rideId).populate("rider driver").session(session);

    if (!ride) return next(new AppError("Ride not found.", 404));
    if (ride.paymentStatus === "completed") return next(new AppError("Ride is already paid.", 400));
    if (ride.status !== "completed") return next(new AppError("Ride must be completed before payment.", 400));

    const amount = ride.fare.final || ride.fare.estimated || 0;

    if (ride.paymentMethod === "wallet") {
      const rider = await User.findById(ride.rider._id).session(session);
      if (rider.wallet.balance < amount) {
        return next(new AppError("Insufficient wallet balance. Please top up or use another method.", 400));
      }

      // Deduct from rider
      rider.wallet.balance -= amount;
      rider.wallet.transactions.push({
        type: "debit",
        amount,
        description: `Payment for Ride #${ride._id}`,
        reference: ride._id,
      });
      await rider.save({ session });
    }

    // Update ride status
    ride.paymentStatus = "completed";
    await ride.save({ session });

    // Add to driver earnings
    const driver = await User.findById(ride.driver._id).session(session);
    driver.earnings.totalEarned += amount;
    driver.earnings.pendingPayout += amount;
    await driver.save({ session });

    await session.commitTransaction();
    
    // Notify rider and driver (optional via socket if needed)
    const io = req.app.get("io");
    if (io) {
      io.to(`user_${ride.rider._id}`).emit("payment_confirmed", { rideId: ride._id, amount });
      io.to(`user_${ride.driver._id}`).emit("earning_updated", { rideId: ride._id, amount });
    }

    res.status(200).json({ success: true, message: "Payment processed successfully.", data: ride });
  } catch (err) {
    await session.abortTransaction();
    next(err);
  } finally {
    session.endSession();
  }
};