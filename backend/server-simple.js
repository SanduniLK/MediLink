// server-simple.js - ULTRA SIMPLE VERSION
const express = require('express');

const app = express();
const PORT = 3000;

// Middleware
app.use(express.json());

// Enable CORS
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

// HEALTH CHECK - SIMPLE ROUTE
app.get('/', (req, res) => {
  res.json({ 
    message: 'Server is running!',
    status: 'OK'
  });
});

// DOCTOR DASHBOARD - SIMPLE ROUTE
app.get('/api/doctor/:id/dashboard', (req, res) => {
  console.log('Doctor dashboard called:', req.params.id);
  
  res.json({
    success: true,
    schedules: [
      {
        id: '1',
        medicalCenter: 'Test Medical Center',
        appointmentCount: 3,
        maxAppointments: 10
      }
    ],
    message: 'Dashboard working!'
  });
});

// START SERVER
app.listen(PORT, () => {
  console.log('='.repeat(40));
  console.log('✅ SERVER RUNNING ON http://localhost:' + PORT);
  console.log('='.repeat(40));
});