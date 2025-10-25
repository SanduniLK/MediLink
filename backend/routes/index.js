// In src/routes/index.js

const express = require('express');
const router = express.Router();

// Import doctor routes (already exists)
const doctorRoutes = require('./doctorRoutes');
router.use('/api/v1/doctors', doctorRoutes); 

// 1. Import the appointment routes
const appointmentRoutes = require('./appointmentRoutes'); 

// 2. Attach the appointment routes to the base path
router.use('/api/v1/appointments', appointmentRoutes); 

module.exports = router;