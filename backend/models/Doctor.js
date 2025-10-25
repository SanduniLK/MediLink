// models/Doctor.js
const mongoose = require('mongoose');

const doctorSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  medicalCenter: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'MedicalCenter',
    required: true
  },
  specialty: {
    type: String,
    required: true
  },
  licenseNumber: {
    type: String,
    required: true,
    unique: true
  },
  doctorCode: {
    type: String,
    unique: true
  },
  isActive: {
    type: Boolean,
    default: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

// Generate doctor code before save
doctorSchema.pre('save', async function(next) {
  if (this.isNew) {
    const medicalCenter = await mongoose.model('MedicalCenter').findById(this.medicalCenter);
    const count = await mongoose.model('Doctor').countDocuments({ 
      medicalCenter: this.medicalCenter 
    });
    
    this.doctorCode = `${medicalCenter.code}DOC${String(count + 1).padStart(3, '0')}`;
  }
  next();
});

module.exports = mongoose.model('Doctor', doctorSchema);