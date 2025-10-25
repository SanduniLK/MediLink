// routes/doctorSchedules.js
const express = require('express');
const {
  createOrUpdateSchedule,
  getMySchedule,
  getAllSchedules,
  updateScheduleApproval
} = require('../controllers/doctorScheduleController');

const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

// Doctor routes
router.post('/schedule', protect, authorize('doctor'), createOrUpdateSchedule);
router.get('/schedule', protect, authorize('doctor'), getMySchedule);

// Admin routes
router.get('/admin/schedules', protect, authorize('admin', 'superadmin'), getAllSchedules);
router.put('/admin/schedules/:scheduleId/approval', protect, authorize('admin', 'superadmin'), updateScheduleApproval);

module.exports = router;