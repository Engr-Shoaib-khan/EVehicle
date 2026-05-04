const express = require("express");
const router = express.Router();
const ctrl = require("../controllers/earningsController");
const { protect, restrictTo } = require("../middleware/auth");

router.use(protect);

router.get("/summary", restrictTo("driver"), ctrl.getEarningsSummary);
router.get("/rides",   restrictTo("driver"), ctrl.getEarningsHistory);
router.post("/payout",  restrictTo("driver"), ctrl.requestPayout);
router.get("/payouts", restrictTo("driver"), ctrl.getPayoutRequests);
router.patch("/payout/:payoutId/process", restrictTo("admin"), ctrl.processPayout);

module.exports = router;