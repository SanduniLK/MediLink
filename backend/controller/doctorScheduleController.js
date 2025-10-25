// controllers/doctorScheduleController.js
const DoctorSchedule = require('../models/DoctorSchedule');
const Doctor = require('../models/Doctor');
const asyncHandler = require('express-async-handler');

// @desc    Create or update doctor schedule
// @route   POST /api/doctors/schedule
// @access  Private/Doctor
const createOrUpdateSchedule = asyncHandler(async (req, res) => {
  const { weeklySchedule, appointmentSettings } = req.body;

  // Get doctor details to verify medical center
  const doctor = await Doctor.findOne({ user: req.user.id });
  
  if (!doctor) {
    return res.status(404).json({
      success: false,
      message: 'Doctor profile not found'
    });
  }

  // Validate schedule data
  if (!weeklySchedule || !Array.isArray(weeklySchedule)) {
    return res.status(400).json({
      success: false,
      message: 'Weekly schedule is required and must be an array'
    });
  }

  const scheduleData = {
    doctor: doctor._id,
    medicalCenter: doctor.medicalCenter,
    weeklySchedule,
    appointmentSettings: appointmentSettings || {},
    adminApproved: false // Reset approval when schedule changes
  };

  let schedule = await DoctorSchedule.findOne({ doctor: doctor._id });

  if (schedule) {
    // Update existing schedule
    schedule = await DoctorSchedule.findOneAndUpdate(
      { doctor: doctor._id },
      scheduleData,
      { new: true, runValidators: true }
    )
    .populate('doctor', 'user specialty')
    .populate('medicalCenter', 'name code');
  } else {
    // Create new schedule
    schedule = new DoctorSchedule(scheduleData);
    await schedule.save();
    await schedule.populate('doctor', 'user specialty');
    await schedule.populate('medicalCenter', 'name code');
  }

  res.status(200).json({
    success: true,
    message: 'Schedule saved successfully. Waiting for admin approval.',
    data: schedule
  });
});

// @desc    Get doctor's own schedule
// @route   GET /api/doctors/schedule
// @access  Private/Doctor
const getMySchedule = asyncHandler(async (req, res) => {
  const doctor = await Doctor.findOne({ user: req.user.id });
  
  if (!doctor) {
    return res.status(404).json({
      success: false,
      message: 'Doctor profile not found'
    });
  }

  const schedule = await DoctorSchedule.findOne({ doctor: doctor._id })
    .populate('doctor', 'user specialty')
    .populate('medicalCenter', 'name code address');

  if (!schedule) {
    return res.status(404).json({
      success: false,
      message: 'Schedule not found. Please create your schedule first.'
    });
  }

  res.status(200).json({
    success: true,
    data: schedule
  });
});

// @desc    Get all schedules for admin (by medical center)
// @route   GET /api/admin/schedules
// @access  Private/Admin
const getAllSchedules = asyncHandler(async (req, res) => {
  const { status, medicalCenter } = req.query;
  
  let query = {};
  
  if (status === 'pending') {
    query.adminApproved = false;
  } else if (status === 'approved') {
    query.adminApproved = true;
  }
  
  if (medicalCenter) {
    query.medicalCenter = medicalCenter;
  }

  const schedules = await DoctorSchedule.find(query)
    .populate({
      path: 'doctor',
      select: 'user specialty licenseNumber',
      populate: {
        path: 'user',
        select: 'name email phone'
      }
    })
    .populate('medicalCenter', 'name code')
    .sort({ createdAt: -1 });

  res.status(200).json({
    success: true,
    count: schedules.length,
    data: schedules
  });
});

// @desc    Approve/Reject doctor schedule
// @route   PUT /api/admin/schedules/:scheduleId/approval
// @access  Private/Admin
const updateScheduleApproval = asyncHandler(async (req, res) => {
  const { approved, notes } = req.body;

  const schedule = await DoctorSchedule.findById(req.params.scheduleId)
    .populate('doctor', 'user specialty')
    .populate('medicalCenter', 'name');

  if (!schedule) {
    return res.status(404).json({
      success: false,
      message: 'Schedule not found'
    });
  }

  schedule.adminApproved = approved;
  if (notes) schedule.adminNotes = notes;
  
  await schedule.save();

  const action = approved ? 'approved' : 'rejected';
  
  res.status(200).json({
    success: true,
    message: `Schedule ${action} successfully`,
    data: schedule
  });
});

module.exports = {
  createOrUpdateSchedule,
  getMySchedule,
  getAllSchedules,
  updateScheduleApproval
};