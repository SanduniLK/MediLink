const express = require('express');
const cors = require('cors');
const app = express();
const PORT = 5001;

// Simple middleware
app.use(cors());
app.use(express.json());

// INSTANT HEALTH CHECK
app.get('/health', (req, res) => {
  console.log('🏥 Health check - INSTANT RESPONSE');
  res.json({ 
    status: 'OK', 
    message: 'SIMPLE BACKEND IS WORKING!',
    timestamp: new Date().toISOString()
  });
});

// INSTANT DOCTORS DATA - NO FIREBASE, NO DATABASE
app.get('/api/doctors/dashboard', (req, res) => {
  console.log('📍 [INSTANT] Sending instant doctors data...');
  
  const instantData = [
    {
      id: 'EEtWgLQ9rke9O1W2rvAYbniIHNV2',
      fullname: 'Dr. Umapathy',
      specialization: 'Orthopedic',
      hospital: 'National Hospital',
      experience: 10,
      schedules: [
        {
          _id: 'schedule-1',
          medicalCenterName: 'City Medical Center',
          date: 'Every Monday',
          time: '09:00 - 17:00',
          appointments: [
            {
              patientName: 'John Doe',
              time: '10:00 AM',
              status: 'confirmed',
              tokenNumber: 1
            },
            {
              patientName: 'Jane Smith', 
              time: '11:00 AM',
              status: 'waiting',
              tokenNumber: 2
            }
          ]
        }
      ]
    }
  ];
  
  console.log('✅ INSTANT DATA SENT SUCCESSFULLY!');
  res.json(instantData);
});

// Start the SIMPLE server
app.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 SIMPLE SERVER running on PORT 5001');
  console.log('📍 Test these URLs:');
  console.log('   http://localhost:5001/health');
  console.log('   http://localhost:5001/api/doctors/dashboard');
  console.log('   http://10.159.139.145:5001/api/doctors/dashboard');
});