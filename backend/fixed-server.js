const express = require('express');
const app = express();
const PORT = 3000;

// ✅ CRITICAL: Add body parser middleware FIRST
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ✅ CRITICAL: CORS middleware - SIMPLIFIED
app.use((req, res, next) => {
    console.log(`📍 ${req.method} ${req.url}`);
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    next();
});

// ✅ SIMPLE TEST ENDPOINT - NO FIREBASE
app.get('/api/test', (req, res) => {
    console.log('✅ /api/test endpoint called');
    res.json({ 
        success: true, 
        message: 'Server is working perfectly!',
        timestamp: new Date().toISOString()
    });
});

// ✅ DOCTORS ENDPOINT - NO FIREBASE
app.get('/api/doctors/queue-dashboard', (req, res) => {
    console.log('✅ /api/doctors/queue-dashboard endpoint called');
    res.json({
        success: true,
        data: [
            {
                id: "EEtWgLQ9rke9O1W2rvAYbniIHNV2",
                fullname: "Dr. Umapathy",
                specialization: "Orthopedic",
                hospital: "National Hospital",
                experience: 10,
                schedules: [
                    {
                        id: "Lw4gAmxlY8OD8SFjbold",
                        medicalCenterName: "KKK Medical Center", 
                        status: "confirmed",
                        appointments: [
                            {
                                id: "app1",
                                patientName: "John Doe",
                                status: "confirmed",
                                date: "2025-10-12",
                                time: "09:00 - 17:00"
                            }
                        ]
                    }
                ]
            }
        ],
        message: "Real data loaded successfully"
    });
});

// ✅ ROOT ENDPOINT
app.get('/', (req, res) => {
    res.json({ 
        message: 'MediLink Backend IS WORKING!',
        endpoints: [
            'GET /api/test',
            'GET /api/doctors/queue-dashboard'
        ]
    });
});

// ✅ FIXED CATCH ALL - Use proper Express syntax
app.use((req, res) => {
    console.log('❌ Unknown route accessed:', req.originalUrl);
    res.status(404).json({ 
        error: 'Route not found',
        requested: req.originalUrl,
        available: ['/', '/api/test', '/api/doctors/queue-dashboard']
    });
});

app.listen(PORT, () => {
    console.log('🚀 ✅ FIXED SERVER running on http://localhost:' + PORT);
    console.log('📋 TEST THESE ENDPOINTS IN BROWSER:');
    console.log('   http://localhost:5000/');
    console.log('   http://localhost:5000/api/test');
    console.log('   http://localhost:5000/api/doctors/queue-dashboard');
});