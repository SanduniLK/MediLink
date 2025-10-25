// models/DoctorSchedule.js
const mongoose = require('mongoose');

const timeSlotSchema = new mongoose.Schema({
  startTime: { 
    type: String, 
    required: true,
    validate: {
      validator: function(v) {
        return /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/.test(v);
      },
      message: 'Invalid time format (HH:MM)'
    }
  },
  endTime: { 
    type: String, 
    required: true,
    validate: {
      validator: function(v) {
        return /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/.test(v);
      },
      message: 'Invalid time format (HH:MM)'
    }
  },
  slotDuration: { 
    type: Number, 
    default: 30,
    enum: [15, 20, 30, 45, 60]
  }
});

const dailyScheduleSchema = new mongoose.Schema({
  day: { 
    type: String, 
    enum: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
    required: true 
  },
  available: { 
    type: Boolean, 
    default: false 
  },
  timeSlots: [timeSlotSchema]
});

const doctorScheduleSchema = new mongoose.Schema({
  doctor: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Doctor',
    required: true,
    unique: true
  },
  medicalCenter: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'MedicalCenter',
    required: true
  },
  weeklySchedule: [dailyScheduleSchema],
  appointmentSettings: {
    minAdvanceBooking: { type: Number, default: 24 }, // hours
    maxAdvanceBooking: { type: Number, default: 90 }, // days
    cancellationNotice: { type: Number, default: 2 }   // hours
  },
  adminApproved: { 
    type: Boolean, 
    default: false 
  },
  adminNotes: {
    type: String
  },
  isActive: { 
    type: Boolean, 
    default: true 
  },
  createdAt: { 
    type: Date, 
    default: Date.now 
  },
  updatedAt: { 
    type: Date, 
    default: Date.now 
  }
});

// Update timestamp on save
doctorScheduleSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model('DoctorSchedule', doctorScheduleSchema);