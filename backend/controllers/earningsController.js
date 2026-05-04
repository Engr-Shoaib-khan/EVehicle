const User = require("../models/User");
const Ride = require("../models/Ride");

// 1. Get Summary
exports.getEarningsSummary = async (req, res, next) => {
    try {
        const user = await User.findById(req.user._id).select("earnings");
        res.status(200).json({ success: true, data: user?.earnings || {} });
    } catch (err) { next(err); }
};

// 2. Get History
exports.getEarningsHistory = async (req, res, next) => {
    try {
        const rides = await Ride.find({ driver: req.user._id, status: "completed" });
        res.status(200).json({ success: true, data: rides });
    } catch (err) { next(err); }
};

// 3. Request Payout
exports.requestPayout = async (req, res, next) => {
    try {
        const { amount } = req.body;
        if (!amount || amount <= 0) {
            return next(new AppError("Invalid payout amount.", 400));
        }

        const user = await User.findById(req.user._id);
        if (!user.earnings) {
            // Initialize earnings if not present
            user.earnings = {
                totalEarned: 0,
                totalPaidOut: 0,
                pendingPayout: 0,
                payoutHistory: []
            };
        }

        // Ensure pendingPayout is initialized if not present
        user.earnings.pendingPayout = user.earnings.pendingPayout || 0;

        if (user.earnings.pendingPayout < amount) {
            return next(new AppError("Insufficient pending payout balance.", 400));
        }

        // Initialize payoutHistory if it doesn't exist
        if (!user.earnings.payoutHistory) {
            user.earnings.payoutHistory = [];
        }

        // Update earnings
        user.earnings.pendingPayout -= amount;
        user.earnings.totalPaidOut += amount; // Assuming totalPaidOut tracks total payouts made

        // Add to payout history
        user.earnings.payoutHistory.push({
            amount,
            status: "requested",
            requestedAt: new Date(),
            // Note: transactionId and processedAt will be set when an admin processes it
        });

        await user.save();

        res.status(200).json({ success: true, message: "Payout requested successfully. It will be processed shortly.", data: { amount, requestedAt: new Date() } });
    } catch (err) { next(err); }
};

// 4. Get Payouts
exports.getPayoutRequests = async (req, res, next) => {
    try {
        const user = await User.findById(req.user._id).select("earnings.payoutHistory");
        // Ensure payoutHistory is an array, even if user.earnings is not fully defined
        const payoutHistory = user?.earnings?.payoutHistory || [];
        res.status(200).json({ success: true, data: payoutHistory });
    } catch (err) { next(err); }
};

// 5. Process Payout (Admin)
exports.processPayout = async (req, res, next) => {
    try {
        const { userId, payoutId } = req.params; // Assuming payoutId is the index
        const { status, transactionId } = req.body;

        if (!['processing', 'paid', 'rejected'].includes(status)) {
            return next(new AppError("Invalid status. Must be 'processing', 'paid', or 'rejected'.", 400));
        }

        const user = await User.findById(userId);
        if (!user || !user.earnings || !user.earnings.payoutHistory) {
            return next(new AppError("User or earnings data not found.", 404));
        }

        // Find the payout request to process. Assuming payoutId is the index.
        const payoutIndex = parseInt(payoutId);
        if (isNaN(payoutIndex) || payoutIndex < 0 || payoutIndex >= user.earnings.payoutHistory.length) {
            return next(new AppError("Invalid payout ID.", 400));
        }

        const payoutRequest = user.earnings.payoutHistory[payoutIndex];

        if (payoutRequest.status !== "requested") {
            return next(new AppError(`Payout request status is not 'requested'. Current status: ${payoutRequest.status}.`, 400));
        }

        // Update payout status and details
        payoutRequest.status = status;
        payoutRequest.processedAt = new Date();
        if (transactionId) {
            payoutRequest.transactionId = transactionId;
        }

        // If rejected, return the amount back to pending payout
        if (status === 'rejected') {
            user.earnings.pendingPayout += payoutRequest.amount;
        }

        await user.save();

        logger.info(`[Payout] Admin processed payout for User ${userId} (Payout index ${payoutId}) with status: ${status}.`);

        res.status(200).json({ success: true, message: `Payout status updated to ${status}.`, data: payoutRequest });
    } catch (err) { next(err); }
};