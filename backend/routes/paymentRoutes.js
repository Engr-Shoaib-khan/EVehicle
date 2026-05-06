const express = require("express");
const ctrl    = require("../controllers/paymentController");
const { protect } = require("../middleware/auth");

const router = express.Router();

// Webhook must be BEFORE auth protection and should use raw parser (handled in app.js)
router.post("/webhook", ctrl.handleStripeWebhook);

router.use(protect);

router.get("/wallet",                          ctrl.getWallet);
router.post("/wallet/topup-session",           ctrl.createCheckoutSession);
router.post("/wallet/topup",                   ctrl.topUpWallet);
router.get("/wallet/transactions",             ctrl.getTransactions);
router.get("/presets",                         ctrl.getPresets);
router.post("/ride/:rideId/complete",          ctrl.completeRidePayment);

module.exports = router;
