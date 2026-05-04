const express = require("express");
const ctrl    = require("../controllers/paymentController");
const { protect } = require("../middleware/auth");

const router = express.Router();
router.use(protect);

router.get("/wallet",                          ctrl.getWallet);
router.post("/wallet/topup",                   ctrl.topUpWallet);
router.get("/wallet/transactions",             ctrl.getTransactions);
router.get("/presets",                         ctrl.getPresets);
router.post("/ride/:rideId/complete",          ctrl.completeRidePayment);

module.exports = router;
