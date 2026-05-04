const mongoose = require('mongoose');
const kycSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  cnicNumber: { type: String, required: true },
  licenseNumber: { type: String, required: true },
  documents: { cnicFront: String, cnicBack: String, license: String, vehicleReg: String },
  status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending' },
  submittedAt: { type: Date, default: Date.now }
});
module.exports = mongoose.model('KYC', kycSchema);