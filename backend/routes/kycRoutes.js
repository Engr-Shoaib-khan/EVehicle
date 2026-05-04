const express  = require("express");
const multer   = require("multer");
const path     = require("path");
const ctrl     = require("../controllers/kycController");
const { protect, restrictTo } = require("../middleware/auth");

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, "uploads/kyc/"),
  filename:    (req, file, cb) => {
    const ext  = path.extname(file.originalname);
    const name = `${req.user._id}_${file.fieldname}_${Date.now()}${ext}`;
    cb(null, name);
  },
});

const upload = multer({ storage });

const kycFields = upload.fields([
  { name: "cnic_front",  maxCount: 1 },
  { name: "cnic_back",   maxCount: 1 },
  { name: "license",     maxCount: 1 },
  { name: "vehicle_reg", maxCount: 1 },
]);

const router = express.Router();
router.use(protect);

router.post("/upload",  kycFields, ctrl.uploadKyc);
router.get("/status",              ctrl.getKycStatus);
router.patch("/review/:userId", restrictTo("admin"), ctrl.reviewKyc);

module.exports = router;