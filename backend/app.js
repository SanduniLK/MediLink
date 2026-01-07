const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const app = express();
const router = express.Router();
const HealthAIIntegration = require('./healthai');
const PORT = 5000;
const healthAI = new HealthAIIntegration();
app.use(express.json());
app.use(cors());

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Import queue routes
const queueRoutes = require('./routes/queueRoutes');

// Use queue routes - THIS SHOULD BE BEFORE YOUR CUSTOM CORS MIDDLEWARE
app.use('/api/queues', queueRoutes); 

// CORS middleware
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
    
    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }
    
    next();
});
// FIXED Database structure
let data = {
    // Current schedule visible to patients (APPROVED) - STARTS EMPTY
    approvedSchedule: {},
    
    // Waiting for admin approval (PENDING)
    pendingSchedule: null,
    
    // List of all schedule submissions for admin
    scheduleHistory: []
};
// 🩺 DOCTOR QUEUE DASHBOARD ROUTE
app.get('/api/doctors/queue-dashboard', async (req, res) => {
  try {
    console.log('GET /api/doctors/queue-dashboard - Loading doctor dashboard data');
    
    // Get all active queues for the doctor
    const queuesSnapshot = await admin.firestore()
      .collection('doctorQueues')
      .where('isActive', '==', true)
      .get();

    const activeQueues = [];
    
    if (!queuesSnapshot.empty) {
      queuesSnapshot.forEach(doc => {
        const queue = doc.data();
        activeQueues.push({
          queueId: queue.queueId,
          scheduleId: queue.scheduleId,
          doctorName: queue.doctorName,
          medicalCenterName: queue.medicalCenterName,
          startTime: queue.startTime,
          currentToken: queue.currentToken,
          maxPatients: queue.maxPatients,
          patients: queue.patients,
          status: queue.status
        });
      });
    }

    // Get all schedules
    const schedulesSnapshot = await admin.firestore()
      .collection('doctorSchedules')
      .get();

    const schedules = [];
    
    if (!schedulesSnapshot.empty) {
      schedulesSnapshot.forEach(doc => {
        const schedule = doc.data();
        schedules.push({
          id: doc.id,
          ...schedule
        });
      });
    }

    // Get appointment statistics
    const appointmentsSnapshot = await admin.firestore()
      .collection('appointments')
      .get();

    let totalAppointments = 0;
    let confirmedAppointments = 0;
    let pendingAppointments = 0;
    
    if (!appointmentsSnapshot.empty) {
      appointmentsSnapshot.forEach(doc => {
        const appointment = doc.data();
        totalAppointments++;
        
        if (appointment.status === 'confirmed') {
          confirmedAppointments++;
        } else if (appointment.status === 'pending') {
          pendingAppointments++;
        }
      });
    }

    res.json({
      success: true,
      data: {
        activeQueues,
        schedules,
        statistics: {
          totalAppointments,
          confirmedAppointments,
          pendingAppointments,
          activeQueuesCount: activeQueues.length,
          totalSchedules: schedules.length
        }
      },
      message: 'Doctor dashboard data loaded successfully'
    });

  } catch (error) {
    console.error('❌ Error loading doctor dashboard:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to load dashboard data: ' + error.message
    });
  }
});
// 🩺 DOCTOR ROUTES
app.get('/api/doctors/schedule', (req, res) => {
    console.log('GET /api/doctors/schedule - Current approved schedule');
    res.json({
        success: true,
        data: data.approvedSchedule,
        message: Object.keys(data.approvedSchedule).length > 0 
            ? 'Current schedule loaded' 
            : 'No schedule set yet'
    });
});

app.post('/api/doctors/schedule', (req, res) => {
    console.log('POST /api/doctors/schedule - New schedule submitted:', req.body);
    
    if (!req.body || Object.keys(req.body).length === 0) {
        return res.status(400).json({
            success: false,
            error: 'No schedule data provided'
        });
    }
    
    // Save as pending (waiting for admin)
    data.pendingSchedule = {
        ...req.body,
        submittedAt: new Date().toISOString(),
        status: 'pending',
        id: Date.now()
    };
    
    // Add to history
    data.scheduleHistory.push(data.pendingSchedule);
    
    res.json({
        success: true,
        message: 'Schedule submitted for admin approval',
        status: 'pending',
        note: 'Patients cannot see this until admin approves'
    });
});

// 👨‍💼 ADMIN ROUTES
app.get('/api/admin/schedules', (req, res) => {
    console.log('GET /api/admin/schedules - Admin viewing schedules');
    
    const pendingSchedules = data.pendingSchedule ? [data.pendingSchedule] : [];
    const approvedSchedules = data.scheduleHistory.filter(s => s.status === 'approved');
    const rejectedSchedules = data.scheduleHistory.filter(s => s.status === 'rejected');
    
    res.json({
        success: true,
        data: {
            pending: pendingSchedules,
            approved: approvedSchedules,
            rejected: rejectedSchedules
        }
    });
});

app.post('/api/admin/schedules/approve', (req, res) => {
    console.log('POST /api/admin/schedules/approve - Admin approving schedule');
    
    if (!data.pendingSchedule) {
        return res.status(400).json({
            success: false,
            error: 'No pending schedule to approve'
        });
    }
    
    // FIXED: Move from pending to approved - COPY THE SCHEDULE DATA
    data.approvedSchedule = { ...data.pendingSchedule };
    
    // Update status in history
    data.pendingSchedule.status = 'approved';
    data.pendingSchedule.approvedAt = new Date().toISOString();
    
    // Clear pending (but keep in history)
    data.pendingSchedule = null;
    
    console.log('✅ Schedule approved. New approved schedule:', data.approvedSchedule);
    
    res.json({
        success: true,
        message: 'Schedule approved! Now visible to patients.',
        data: data.approvedSchedule
    });
});

app.post('/api/admin/schedules/reject', (req, res) => {
    console.log('POST /api/admin/schedules/reject - Admin rejecting schedule');
    
    if (!data.pendingSchedule) {
        return res.status(400).json({
            success: false,
            error: 'No pending schedule to reject'
        });
    }
    
    data.pendingSchedule.status = 'rejected';
    data.pendingSchedule.rejectedAt = new Date().toISOString();
    data.pendingSchedule = null;
    
    res.json({
        success: true,
        message: 'Schedule rejected.'
    });
});

// 👤 PATIENT ROUTES - FIXED: Returns only approved schedule
app.get('/api/patient/schedule', (req, res) => {
    console.log('GET /api/patient/schedule - Patient viewing schedule');
    
    // Remove any internal fields before sending to patient
    const patientSchedule = { ...data.approvedSchedule };
    delete patientSchedule.submittedAt;
    delete patientSchedule.status;
    delete patientSchedule.id;
    delete patientSchedule.approvedAt;
    
    res.json({
        success: true,
        data: patientSchedule,
        message: Object.keys(patientSchedule).length > 0 
            ? 'Doctor schedule available' 
            : 'No schedule available yet'
    });
});

// Debug endpoint to check current state
app.get('/api/debug/state', (req, res) => {
    res.json({
        success: true,
        data: {
            pendingSchedule: data.pendingSchedule,
            approvedSchedule: data.approvedSchedule,
            scheduleHistory: data.scheduleHistory
        }
    });
});

// Health check
app.get('/', (req, res) => {
    res.json({ 
        message: 'MediLink Backend - Working!',
        status: '✅ Server is running',
        endpoints: {
            doctor: ['GET/POST /api/doctors/schedule'],
            admin: ['GET /api/admin/schedules', 'POST /api/admin/schedules/approve'],
            patient: ['GET /api/patient/schedule'],
            queues: ['POST /api/queues/start', 'POST /api/queues/checkin', 'GET /api/queues/schedule/:id', 'POST /api/queues/next', 'GET /api/queues/patient/:id']
        }
    });
});

app.listen(PORT, () => {
    console.log('🚀 Server running on http://localhost:' + PORT);
    console.log('✅ Fixed backend - Patients will see approved schedules');
    console.log('📋 Queue routes available at: http://localhost:' + PORT + '/api/queues');
});