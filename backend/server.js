const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const app = express();
const PORT = 5001;

const http = require('http');
const socketIo = require('socket.io');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://your-project-id.firebaseio.com"
});

const db = admin.firestore();

// Middleware
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Store active rooms and users for WebRTC
const rooms = new Map();
const users = new Map();

// WebRTC Socket.io connection handling
io.on('connection', (socket) => {
  console.log('🔗 User connected for WebRTC:', socket.id);
// server.js - ADD THESE EVENTS

// Doctor starts a call
socket.on('doctor-start-call', (data) => {
  console.log(`📞 DOCTOR starting ${data.callType} call to room ${data.roomId}`);
  
  // Notify patient about incoming call
  socket.to(data.roomId).emit('incoming-call-from-doctor', {
    doctorName: data.callerName,
    doctorId: data.targetUserId,
    roomId: data.roomId,
    callType: data.callType,
    timestamp: new Date().toISOString()
  });

  // Send offer to patient
  socket.to(data.roomId).emit('webrtc-offer', {
    from: socket.id,
    offer: data.offer,
    callType: data.callType
  });
});

// Patient answers call
socket.on('patient-answer-call', (data) => {
  console.log(`✅ PATIENT answered call in room ${data.roomId}`);
  
  // Notify doctor that patient answered
  socket.to(data.roomId).emit('call-answered-by-patient', {
    from: socket.id,
    answer: data.answer
  });
});

// Patient rejects call
socket.on('patient-reject-call', (data) => {
  console.log(`❌ PATIENT rejected call in room ${data.roomId}`);
  
  // Notify doctor that patient rejected
  socket.to(data.roomId).emit('call-rejected-by-patient', {
    from: socket.id,
    reason: data.reason
  });
});

// Notify patient about call
socket.on('notify-call-started', (data) => {
  console.log(`🔔 Notifying patient ${data.patientId} about call`);
  
  const patientRoom = `patient_${data.patientId}`;
  socket.to(patientRoom).emit('incoming-call-from-doctor', {
    doctorName: data.doctorName,
    doctorId: data.doctorId,
    roomId: data.roomId,
    callType: data.callType,
    timestamp: data.timestamp
  });
});

  socket.on('patient-join', (data) => {
  const patientId = typeof data === 'string' ? data : data.patientId;
   const userName = data.userName || 'Unknown Patient';
  const roomName = `patient_${patientId}`;
  
  console.log(`🎯 PATIENT JOIN DEBUG:`);
  console.log(`   Patient ID: ${patientId}`);
  console.log(`   Patient Name: ${userName}`);
  console.log(`   Room Name: ${roomName}`);
  console.log(`   Socket ID: ${socket.id}`);
  console.log(`   Data received: ${JSON.stringify(data)}`);
  
  // Leave any previous patient rooms
  const currentRooms = Array.from(socket.rooms);
  currentRooms.forEach(room => {
    if (room.startsWith('patient_') && room !== roomName) {
      socket.leave(room);
      console.log(`   Left previous room: ${room}`);
    }
  });
  
  // Join new patient room
  socket.join(roomName);
  
  // Store patient info
 users.set(socket.id, { 
    type: 'patient', 
    patientId: patientId,
    userName: userName,
    room: roomName,
    socketId: socket.id,
    joinedAt: new Date().toISOString()
  });
  
    console.log(`✅ Patient ${patientId} (${data.userName}) joined room: ${roomName}`);

    socket.emit('patient-room-joined', {
    room: roomName,
    patientId: patientId,
    status: 'success'
  });

      // Debug: Check all patient rooms
  const patientRooms = Array.from(io.sockets.adapter.rooms.keys())
    .filter(room => room.startsWith('patient_'));
 console.log(`   Active patient rooms: ${patientRooms.join(', ') || 'NONE'}`);
});
});

// Add this to your server.js for real-time debugging
console.log('\n🔍 REAL-TIME PATIENT ROOM DEBUG:');
const patientRooms = Array.from(io.sockets.adapter.rooms.keys())
  .filter(room => room.startsWith('patient_'));
console.log(`   Active patient rooms: ${patientRooms.join(', ') || 'NONE'}`);

// Check if our target patient is connected
const targetPatientRoom = `patient_cnHEP9bh8QdKvS061HjBpiRzyNZ2`;
const targetRoom = io.sockets.adapter.rooms.get(targetPatientRoom);
console.log(`   Target patient room exists: ${!!targetRoom}`);
if (targetRoom) {
  console.log(`   Sockets in target room: ${Array.from(targetRoom).join(', ')}`);
}
// Add this to your server.js for real-time monitoring
setInterval(() => {
  console.log('\n🏠 REAL-TIME CONNECTION MONITOR:');
  console.log(`   Total connections: ${io.engine.clientsCount}`);
  
  const rooms = io.sockets.adapter.rooms;
  const patientRooms = Array.from(rooms.keys()).filter(room => room.startsWith('patient_'));
  
  console.log(`   Patient rooms: ${patientRooms.length}`);
  patientRooms.forEach(roomName => {
    const room = rooms.get(roomName);
    const patientId = roomName.replace('patient_', '');
    console.log(`   👤 ${roomName}: ${room.size} socket(s)`);
    
    // Show socket details for each patient room
    Array.from(room).forEach(socketId => {
      const userInfo = users.get(socketId);
      if (userInfo) {
        console.log(`      → ${userInfo.userName} (${socketId})`);
      }
    });
  });
  
  // Show call rooms
  const callRooms = Array.from(rooms.keys()).filter(room => room.startsWith('T17'));
  console.log(`   Active call rooms: ${callRooms.length}`);
  callRooms.forEach(roomName => {
    const room = rooms.get(roomName);
    console.log(`   📞 ${roomName}: ${room.size} participant(s)`);
  });
  
}, 15000); // Every 15 seconds 10000); // Every 10 seconds

socket.on('notify-call-started', (data) => {
  const { patientId, roomId, doctorName, doctorId, consultationType } = data;
  
  console.log(`🔔 CALL NOTIFICATION: Patient ${patientId}, Room ${roomId}`);
  
  const patientRoomName = `patient_${patientId}`;
  const patientRoom = io.sockets.adapter.rooms.get(patientRoomName);
  
  if (patientRoom && patientRoom.size > 0) {
    console.log(`✅ Sending call to patient room: ${patientRoomName}`);
    
    io.to(patientRoomName).emit('call-started', {
      roomId: roomId,
      doctorName: doctorName,
      doctorId: doctorId,
      consultationType: consultationType || 'video',
      patientId: patientId,
      timestamp: new Date().toISOString()
    });
    
    // Also send as incoming-call for compatibility
    io.to(patientRoomName).emit('incoming-call', {
      roomId: roomId,
      doctorName: doctorName,
      doctorId: doctorId,
      consultationType: consultationType || 'video',
      patientId: patientId
    });
  } else {
    console.log(`❌ Patient ${patientId} not in their room`);
  }
});
  // Join a video call room
  socket.on('join-call-room', (roomId) => {
    socket.join(roomId);
    
    if (!rooms.has(roomId)) {
      rooms.set(roomId, new Set());
    }
    rooms.get(roomId).add(socket.id);
    
    console.log(`🎥 User ${socket.id} joined call room: ${roomId}`);
    
    // Notify others in the room
    socket.to(roomId).emit('user-joined', { userId: socket.id });
    
    // Send current room participants count
    const roomSize = rooms.get(roomId).size;
    io.to(roomId).emit('room-size-update', { size: roomSize });
  });
socket.on('test-patient-notification', (data) => {
  console.log('🧪 TEST PATIENT NOTIFICATION:', data);
  socket.emit('test-response', {
    message: 'Test notification received by server',
    patientId: data.patientId,
    timestamp: new Date().toISOString()
  });
});
  // Handle WebRTC signaling messages
  socket.on('webrtc-signal', (data) => {
    console.log(`📡 WebRTC signal from ${socket.id} to room ${data.roomId}: ${data.type}`);
    
    // Broadcast to other users in the room
    socket.to(data.roomId).emit('webrtc-signal', {
      type: data.type,
      sdp: data.sdp,
      candidate: data.candidate,
      from: socket.id
    });
  });

  // Enhanced WebRTC signaling for direct peer communication
  socket.on('webrtc-offer', (data) => {
    console.log(`📨 WebRTC offer from ${socket.id} to ${data.to}`);
    console.log(`   Target User ID: ${data.targetUserId}`);

    if (!data.offer || !data.to) {
    console.log('❌ Invalid offer data');
    return;
  }
    socket.to(data.to).emit('webrtc-offer', {
      from: socket.id,
      fromUserId: data.targetUserId,
      offer: data.offer,
      roomId: data.to,
      timestamp: new Date().toISOString()
    });
  });

  socket.on('webrtc-answer', (data) => {
    console.log(`📨 WebRTC answer from ${socket.id} to ${data.to}`);
    socket.to(data.to).emit('webrtc-answer', {
      from: socket.id,
      answer: data.answer,
      timestamp: new Date().toISOString()
    });
  });
socket.on('media-state-changed', (data) => {
  console.log(`🎛️ Media state changed: ${data.mediaType} = ${data.enabled}`);
  socket.to(data.roomId).emit('media-state-changed', data);
});
  socket.on('ice-candidate', (data) => {
     console.log(`🧊 ICE candidate from ${socket.id} to ${data.to}`);
    socket.to(data.to).emit('ice-candidate', {
      from: socket.id,
      candidate: data.candidate
    });
  });

  // Handle user leaving call
  socket.on('leave-call-room', (roomId) => {
    socket.leave(roomId);
    
    if (rooms.has(roomId)) {
      rooms.get(roomId).delete(socket.id);
      if (rooms.get(roomId).size === 0) {
        rooms.delete(roomId);
      }
    }
    
    console.log(`🚪 User ${socket.id} left call room: ${roomId}`);
    socket.to(roomId).emit('user-left', { userId: socket.id });
  });

  // Handle call initiation
  socket.on('initiate-call', (data) => {
    const { targetUserId, roomId, offer, callerName, callType } = data;
    console.log(`📞 Call initiated by ${callerName} in room ${roomId}`);
    
    socket.to(roomId).emit('incoming-call', {
      from: socket.id,
      fromUserId: data.callerId,
      fromUserName: callerName,
      roomId: roomId,
      offer: offer,
      callType: callType || 'video'
    });
  });

  // Handle call acceptance
  socket.on('accept-call', (data) => {
    const { to, answer } = data;
    console.log(`✅ Call accepted by ${socket.id}, sending answer to: ${to}`);
    
    socket.to(to).emit('call-accepted', {
      from: socket.id,
      answer: answer
    });
  });

  // Handle media controls
  socket.on('toggle-media', (data) => {
    const { roomId, mediaType, isEnabled } = data;
    console.log(`🎛️ ${socket.id} toggled ${mediaType}: ${isEnabled}`);
    
    socket.to(roomId).emit('user-media-updated', {
      userId: socket.id,
      mediaType: mediaType,
      isEnabled: isEnabled
    });
  });

  // Handle call end
  socket.on('end-call', (data) => {
    const { roomId } = data;
    console.log(`📞 Call ended by ${socket.id} in room ${roomId}`);
    
    socket.to(roomId).emit('call-ended', {
      endedBy: socket.id,
      timestamp: new Date().toISOString()
    });
  });

  socket.on('disconnect', () => {
    console.log('🔌 User disconnected from WebRTC:', socket.id);
    
    // Remove user from all rooms
    rooms.forEach((users, roomId) => {
      if (users.has(socket.id)) {
        users.delete(socket.id);
        socket.to(roomId).emit('user-left', { userId: socket.id });
        
        if (users.size === 0) {
          rooms.delete(roomId);
        }
      }
    });
  });


// Your existing routes below - KEEP ALL YOUR CURRENT ROUTES AS THEY ARE
const queueRoutes = require('./routes/queueRoutes');
app.use('/api/queue', queueRoutes);

// INSTANT HEALTH CHECK
app.get('/health', (req, res) => {
  console.log('🏥 Health check - INSTANT RESPONSE');
  res.json({ 
    status: 'OK', 
    message: 'BACKEND WITH FIREBASE IS WORKING!',
    timestamp: new Date().toISOString()
  });
});

// Get active queues for a medical center
app.get('/api/medical-center/:medicalCenterId/active-queues', async (req, res) => {
  try {
    const { medicalCenterId } = req.params;
    
    console.log('🔍 Getting active queues for medical center:', medicalCenterId);
    
    const queuesSnapshot = await db.collection('doctorQueues')
      .where('medicalCenterId', '==', medicalCenterId)
      .where('isActive', '==', true)
      .get();
    
    const activeQueues = [];
    queuesSnapshot.forEach(doc => {
      const queue = doc.data();
      activeQueues.push({
        queueId: queue.queueId,
        scheduleId: queue.scheduleId,
        doctorId: queue.doctorId,
        doctorName: queue.doctorName,
        medicalCenterName: queue.medicalCenterName,
        currentToken: queue.currentToken,
        totalPatients: queue.patients?.length || 0,
        startTime: queue.startTime,
        isActive: queue.isActive
      });
    });
    
    console.log(`✅ Found ${activeQueues.length} active queues`);
    
    res.json({
      success: true,
      data: activeQueues
    });
  } catch (error) {
    console.error('❌ Error getting active queues:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get patient appointments with queue status
app.get('/api/patients/:patientId/appointments', async (req, res) => {
  try {
    const { patientId } = req.params;
    
    console.log('📋 Getting appointments for patient:', patientId);
    
    const appointmentsSnapshot = await db.collection('appointments')
      .where('patientId', '==', patientId)
      .where('status', 'in', ['confirmed', 'scheduled', 'pending', 'waiting'])
      .get();
    
    const appointments = [];
    
    for (const doc of appointmentsSnapshot.docs) {
      const data = doc.data();
      const scheduleId = data.scheduleId;
      
      // Check if there's an active queue for this schedule
      let queueStatus = 'not-started';
      let currentToken = 0;
      let patientToken = data.tokenNumber;
      let queueId = null;
      
      if (scheduleId) {
        const queuesSnapshot = await db.collection('doctorQueues')
          .where('scheduleId', '==', scheduleId)
          .where('isActive', '==', true)
          .limit(1)
          .get();
        
        if (!queuesSnapshot.empty) {
          const queue = queuesSnapshot.docs[0].data();
          queueStatus = 'active';
          currentToken = queue.currentToken || 1;
          queueId = queue.queueId;
          
          // Check if this patient is in the queue
          const patientInQueue = queue.patients?.find(p => p.patientId === patientId);
          if (patientInQueue) {
            patientToken = patientInQueue.tokenNumber;
          }
        }
      }
      
      appointments.push({
        id: doc.id,
        patientName: data.patientName,
        patientId: data.patientId,
        doctorId: data.doctorId,
        doctorName: data.doctorName,
        medicalCenterName: data.medicalCenterName,
        scheduleId: data.scheduleId,
        date: data.date,
        time: data.time,
        status: data.status,
        tokenNumber: patientToken,
        appointmentType: data.appointmentType,
        fees: data.fees,
        paymentStatus: data.paymentStatus,
        patientAge: data.patientAge,
        patientGender: data.patientGender,
        patientPhone: data.patientPhone,
        queueStatus: queueStatus,
        queueId: queueId,
        currentToken: currentToken,
        positionInQueue: queueStatus === 'active' ? (patientToken - currentToken + 1) : null,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || data.createdAt,
        updatedAt: data.updatedAt?.toDate?.()?.toISOString() || data.updatedAt
      });
    }
    
    console.log(`✅ Found ${appointments.length} appointments for patient ${patientId}`);
    
    // Log appointment details with queue status
    appointments.forEach(apt => {
      console.log(`   - ${apt.patientName} | ${apt.date} ${apt.time} | Queue: ${apt.queueStatus} | Token: ${apt.tokenNumber}`);
    });
    
    res.json({
      success: true,
      data: appointments
    });
  } catch (error) {
    console.error('❌ Error getting patient appointments:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// DEBUG: Check schedule and appointment matching
app.get('/api/debug-schedule-matching', async (req, res) => {
  try {
    console.log('🔍 Debugging schedule and appointment matching...');
    
    // Get all schedules
    const schedulesSnapshot = await db.collection('doctorSchedules').get();
    console.log(`📅 Total schedules: ${schedulesSnapshot.size}`);
    
    const schedules = [];
    schedulesSnapshot.forEach(doc => {
      const data = doc.data();
      schedules.push({
        id: doc.id,
        medicalCenter: data.medicalCenterName,
        doctorId: data.doctorId,
        doctorName: data.doctorName
      });
    });
    
    // Get all appointments
    const appointmentsSnapshot = await db.collection('appointments').get();
    console.log(`📋 Total appointments: ${appointmentsSnapshot.size}`);
    
    const appointments = [];
    appointmentsSnapshot.forEach(doc => {
      const data = doc.data();
      appointments.push({
        id: doc.id,
        patientName: data.patientName,
        scheduleId: data.scheduleId,
        doctorId: data.doctorId,
        medicalCenter: data.medicalCenterName
      });
    });
    
    // Find matches
    const matches = [];
    const noMatch = [];
    
    appointments.forEach(apt => {
      const matchingSchedule = schedules.find(s => s.id === apt.scheduleId);
      
      if (matchingSchedule) {
        matches.push({
          appointment: apt.patientName,
          schedule: matchingSchedule.medicalCenter,
          scheduleId: apt.scheduleId,
          status: '✅ MATCHED'
        });
      } else {
        noMatch.push({
          appointment: apt.patientName,
          appointmentScheduleId: apt.scheduleId,
          medicalCenter: apt.medicalCenter,
          status: '❌ NO MATCHING SCHEDULE'
        });
      }
    });
    
    console.log('📊 Matching Results:');
    console.log(`   ✅ Matched: ${matches.length}`);
    console.log(`   ❌ No Match: ${noMatch.length}`);
    
    res.json({
      schedules: schedules,
      appointments: appointments,
      matches: matches,
      noMatch: noMatch,
      summary: {
        totalSchedules: schedules.length,
        totalAppointments: appointments.length,
        matched: matches.length,
        notMatched: noMatch.length
      }
    });
    
  } catch (error) {
    console.error('❌ Debug error:', error);
    res.status(500).json({ error: error.message });
  }
});

// FIXED: GET ALL DOCTORS WITH THEIR SCHEDULES AND APPOINTMENTS
app.get('/api/doctors/dashboard', async (req, res) => {
  try {
    console.log('📍 Fetching doctors with TODAY & FUTURE schedules/appointments only...');
    
    // Get current date for filtering
    const today = new Date();
    today.setHours(0, 0, 0, 0); // Start of today
    
    console.log(`📅 Filtering for dates from: ${today.toDateString()}`);
    
    // Get all schedules
    const schedulesSnapshot = await db.collection('doctorSchedules').get();
    
    if (schedulesSnapshot.empty) {
      console.log('No schedules found');
      return res.json([]);
    }

    // Get all appointments
    const appointmentsSnapshot = await db.collection('appointments').get();
    const allAppointments = [];
    appointmentsSnapshot.forEach(doc => {
      const data = doc.data();
      allAppointments.push({
        id: doc.id,
        ...data
      });
    });

    console.log(`📊 Total schedules: ${schedulesSnapshot.size}, Total appointments: ${allAppointments.length}`);

    const doctorsMap = new Map();

    // Process each schedule
    for (const doc of schedulesSnapshot.docs) {
      const scheduleData = doc.data();
      const scheduleId = doc.id;
      const doctorId = scheduleData.doctorId;
      
      if (!doctorId) {
        console.log('⚠️ Skipping schedule without doctorId:', scheduleId);
        continue;
      }

      // Create doctor if doesn't exist
      if (!doctorsMap.has(doctorId)) {
        doctorsMap.set(doctorId, {
          id: doctorId,
          fullname: scheduleData.doctorName || 'Unknown Doctor',
          specialization: scheduleData.doctorSpecialty || 'General',
          hospital: scheduleData.medicalCenterName || 'Unknown Hospital',
          experience: scheduleData.experience || 5,
          imageUrl: scheduleData.doctorImage || '',
          schedules: []
        });
      }

      const doctor = doctorsMap.get(doctorId);
      
      // FIND TODAY & FUTURE APPOINTMENTS FOR THIS SCHEDULE
      let relevantAppointments = [];
      
      // Get available days from this schedule
      const weeklySchedule = scheduleData.weeklySchedule || [];
      const availableDays = weeklySchedule
        .filter(day => day.available === true)
        .map(day => day.day.toLowerCase());
      
      console.log(`   Schedule: ${scheduleData.medicalCenterName}`);
      console.log(`   Available days: ${availableDays.join(', ')}`);
      
      // Method 1: Direct scheduleId match + date filter
      const directMatches = allAppointments.filter(apt => {
        if (apt.scheduleId !== scheduleId) return false;
        
        // DATE FILTER: Only include today & future appointments
        const appointmentDate = _parseAppointmentDate(apt.date);
        return appointmentDate >= today;
      });
      
      // Method 2: Schedule-based match + date filter
      const scheduleBasedMatches = allAppointments.filter(apt => {
        // Must match doctor and medical center
        if (apt.doctorId !== doctorId || apt.medicalCenterName !== scheduleData.medicalCenterName) {
          return false;
        }
        
        // DATE FILTER: Only include today & future appointments
        const appointmentDate = _parseAppointmentDate(apt.date);
        if (appointmentDate < today) return false;
        
        // Check if appointment date matches schedule's available days
        const appointmentDay = _extractDayFromDate(apt.date).toLowerCase();
        
        // Check if this day is available in the schedule
        const isDayAvailable = availableDays.includes(appointmentDay);
        
        return isDayAvailable;
      });
      
      // Combine and remove duplicates
      const allMatches = [...directMatches, ...scheduleBasedMatches];
      const uniqueMatches = allMatches.filter((apt, index, self) => 
        index === self.findIndex(a => a.id === apt.id)
      );
      
      relevantAppointments = uniqueMatches;
      
      console.log(`      Today+Future appointments: ${relevantAppointments.length}`);
      relevantAppointments.forEach(apt => {
        console.log(`         - ${apt.patientName} (${apt.date})`);
      });

      // Format appointments
      const formattedAppointments = relevantAppointments.map(apt => ({
        id: apt.id,
        patientName: apt.patientName || 'Unknown Patient',
        patientId: apt.patientId,
        tokenNumber: apt.tokenNumber || 0,
        time: apt.time || 'Not specified',
        date: apt.date || 'Today',
        status: apt.status || apt.queueStatus || 'waiting',
        appointmentType: apt.appointmentType || 'physical',
        fees: apt.fees || 0,
        paymentStatus: apt.paymentStatus || 'pending',
        patientAge: apt.patientAge || null,
        patientGender: apt.patientGender || 'Not specified',
        patientPhone: apt.patientPhone || '',
        patientNotes: apt.patientNotes || '',
        createdAt: apt.createdAt?.toDate?.()?.toISOString() || apt.createdAt,
        updatedAt: apt.updatedAt?.toDate?.()?.toISOString() || apt.updatedAt
      }));

      // Sort by date, then by token number
      formattedAppointments.sort((a, b) => {
        const dateA = _parseAppointmentDate(a.date);
        const dateB = _parseAppointmentDate(b.date);
        
        if (dateA.getTime() !== dateB.getTime()) {
          return dateA - dateB; // Sort by date
        }
        return (a.tokenNumber || 0) - (b.tokenNumber || 0); // Then by token
      });

      // Only include schedules that have TODAY or FUTURE appointments
      if (formattedAppointments.length > 0) {
        const formattedSchedule = {
          id: scheduleId,
          medicalCenterName: scheduleData.medicalCenterName,
          medicalCenterId: scheduleData.medicalCenterId,
          status: scheduleData.status,
          adminApproved: scheduleData.adminApproved || false,
          doctorConfirmed: scheduleData.doctorConfirmed || false,
          bookedAppointments: formattedAppointments.length,
          weeklySchedule: weeklySchedule,
          appointments: formattedAppointments,
          createdAt: scheduleData.createdAt?.toDate?.()?.toISOString() || scheduleData.createdAt,
          updatedAt: scheduleData.updatedAt?.toDate?.()?.toISOString() || scheduleData.updatedAt
        };

        doctor.schedules.push(formattedSchedule);
      } else {
        console.log(`      ❌ Skipping schedule - no today/future appointments`);
      }
    }

    // Convert to array and filter doctors with active schedules
    const doctorsData = Array.from(doctorsMap.values())
      .filter(doctor => doctor.schedules.length > 0);
    
    // Final debug log
    let totalAppointments = 0;
    doctorsData.forEach(doctor => {
      console.log(`👨‍⚕️ Doctor: ${doctor.fullname}`);
      doctor.schedules.forEach(schedule => {
        console.log(`   📅 ${schedule.medicalCenterName}: ${schedule.appointments.length} TODAY+FUTURE appointments`);
        totalAppointments += schedule.appointments.length;
        
        // Log appointment details
        schedule.appointments.forEach((apt, index) => {
          console.log(`      ${index + 1}. ${apt.patientName} - ${apt.date} ${apt.time} - Token #${apt.tokenNumber}`);
        });
      });
    });
    
    console.log(`🎯 FINAL: ${doctorsData.length} doctors with active schedules, ${totalAppointments} TODAY+FUTURE appointments`);
    
    res.json(doctorsData);
    
  } catch (error) {
    console.error('❌ Error fetching doctors data:', error);
    res.status(500).json({ 
      error: 'Failed to fetch doctors data',
      details: error.message 
    });
  }
});

// Helper function to parse appointment date string to Date object
function _parseAppointmentDate(dateString) {
  if (!dateString) return new Date(); // Default to today
  
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  // Handle "Today"
  if (dateString.toLowerCase().includes('today')) {
    return new Date(today);
  }
  
  // Handle "Tomorrow"
  if (dateString.toLowerCase().includes('tomorrow')) {
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    return tomorrow;
  }
  
  // Handle "Monday (14/10/2025)" format
  const dateMatch = dateString.match(/(\d{1,2})\/(\d{1,2})\/(\d{4})/);
  if (dateMatch) {
    const [_, day, month, year] = dateMatch;
    return new Date(year, month - 1, day); // month is 0-indexed
  }
  
  // Try to parse as ISO date
  try {
    const parsedDate = new Date(dateString);
    if (!isNaN(parsedDate)) {
      parsedDate.setHours(0, 0, 0, 0);
      return parsedDate;
    }
  } catch (e) {
    // Ignore parsing errors
  }
  
  // Default to today if can't parse
  return new Date(today);
}

// Helper function to extract day from date string
function _extractDayFromDate(dateString) {
  if (!dateString) return '';
  
  // Handle "Today", "Tomorrow" format
  if (dateString.toLowerCase().includes('today')) {
    return new Date().toLocaleDateString('en-US', { weekday: 'long' }).toLowerCase();
  }
  if (dateString.toLowerCase().includes('tomorrow')) {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    return tomorrow.toLocaleDateString('en-US', { weekday: 'long' }).toLowerCase();
  }
  
  // Handle "Monday (14/10/2025)" format
  const dayMatch = dateString.match(/(monday|tuesday|wednesday|thursday|friday|saturday|sunday)/i);
  if (dayMatch) return dayMatch[0].toLowerCase();
  
  // Try to parse date string
  try {
    const date = _parseAppointmentDate(dateString);
    return date.toLocaleDateString('en-US', { weekday: 'long' }).toLowerCase();
  } catch (e) {
    // Ignore parsing errors
  }
  
  return '';
}

// DEBUG: Check schedule-relevant appointment matching
app.get('/api/debug-schedule-relevance', async (req, res) => {
  try {
    console.log('🔍 Debugging SCHEDULE-RELEVANT appointment matching...');
    
    // Get all schedules
    const schedulesSnapshot = await db.collection('doctorSchedules').get();
    
    // Get all appointments
    const appointmentsSnapshot = await db.collection('appointments').get();
    const allAppointments = [];
    appointmentsSnapshot.forEach(doc => {
      allAppointments.push({
        id: doc.id,
        ...doc.data()
      });
    });

    const results = [];
    
    // Check each schedule
    for (const doc of schedulesSnapshot.docs) {
      const scheduleData = doc.data();
      const scheduleId = doc.id;
      const weeklySchedule = scheduleData.weeklySchedule || [];
      
      const availableDays = weeklySchedule
        .filter(day => day.available === true)
        .map(day => day.day.toLowerCase());
      
      // Find relevant appointments
      const relevantAppointments = allAppointments.filter(apt => {
        // Must match doctor and medical center
        if (apt.doctorId !== scheduleData.doctorId || apt.medicalCenterName !== scheduleData.medicalCenterName) {
          return false;
        }
        
        // Check day matching
        const appointmentDate = apt.date || '';
        const appointmentDay = _extractDayFromDate(appointmentDate).toLowerCase();
        const isDayAvailable = availableDays.includes(appointmentDay);
        
        return isDayAvailable || apt.scheduleId === scheduleId;
      });
      
      results.push({
        schedule: `${scheduleData.medicalCenterName} (${scheduleId})`,
        doctor: scheduleData.doctorName,
        availableDays: availableDays,
        totalRelevantAppointments: relevantAppointments.length,
        appointments: relevantAppointments.map(apt => ({
          patient: apt.patientName,
          date: apt.date,
          time: apt.time,
          scheduleId: apt.scheduleId,
          matches: apt.scheduleId === scheduleId ? 'DIRECT' : 'BY_DAY'
        }))
      });
    }
    
    console.log('📊 Schedule-Relevance Results:');
    results.forEach(result => {
      console.log(`   ${result.schedule}`);
      console.log(`      Available days: ${result.availableDays.join(', ')}`);
      console.log(`      Relevant appointments: ${result.totalRelevantAppointments}`);
      result.appointments.forEach(apt => {
        console.log(`         - ${apt.patient} (${apt.date} ${apt.time}) - ${apt.matches}`);
      });
    });
    
    res.json({
      results: results,
      summary: {
        totalSchedules: results.length,
        totalRelevantAppointments: results.reduce((sum, r) => sum + r.totalRelevantAppointments, 0)
      }
    });
    
  } catch (error) {
    console.error('❌ Debug error:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET SCHEDULES WITH APPOINTMENTS FOR A SPECIFIC DOCTOR
app.get('/api/doctors/:doctorId/schedules', async (req, res) => {
  try {
    const { doctorId } = req.params;
    console.log(`📍 Fetching schedules with appointments for doctor: ${doctorId}`);
    
    const schedulesSnapshot = await db.collection('doctorSchedules')
      .where('doctorId', '==', doctorId)
      .get();
    
    if (schedulesSnapshot.empty) {
      return res.json([]);
    }

    // Get all appointments for this doctor
    const appointmentsSnapshot = await db.collection('appointments')
      .where('doctorId', '==', doctorId)
      .get();

    const allAppointments = [];
    appointmentsSnapshot.forEach(doc => {
      allAppointments.push({
        id: doc.id,
        ...doc.data()
      });
    });

    const schedules = [];
    
    // Process each schedule
    for (const doc of schedulesSnapshot.docs) {
      const scheduleData = doc.data();
      const scheduleId = doc.id;

      // Find appointments for this schedule
      const appointments = allAppointments.filter(apt => 
        apt.scheduleId === scheduleId || 
        (apt.doctorId === doctorId && apt.medicalCenterName === scheduleData.medicalCenterName)
      );

      // Format appointments
      const formattedAppointments = appointments.map(apt => ({
        id: apt.id,
        patientName: apt.patientName || 'Unknown Patient',
        patientId: apt.patientId,
        tokenNumber: apt.tokenNumber || 0,
        time: apt.time || 'Not specified',
        date: apt.date || 'Today',
        status: apt.status || apt.queueStatus || 'waiting',
        appointmentType: apt.appointmentType || 'physical',
        fees: apt.fees || 0,
        paymentStatus: apt.paymentStatus || 'pending',
        patientAge: apt.patientAge || null,
        patientGender: apt.patientGender || 'Not specified',
        patientPhone: apt.patientPhone || '',
        patientNotes: apt.patientNotes || '',
        createdAt: apt.createdAt?.toDate?.()?.toISOString() || apt.createdAt,
        updatedAt: apt.updatedAt?.toDate?.()?.toISOString() || apt.updatedAt
      }));

      // Sort by token number
      formattedAppointments.sort((a, b) => (a.tokenNumber || 0) - (b.tokenNumber || 0));

      schedules.push({
        id: scheduleId,
        ...scheduleData,
        bookedAppointments: formattedAppointments.length,
        appointments: formattedAppointments,
        createdAt: scheduleData.createdAt?.toDate?.()?.toISOString() || scheduleData.createdAt,
        updatedAt: scheduleData.updatedAt?.toDate?.()?.toISOString() || scheduleData.updatedAt
      });
    }

    console.log(`✅ Found ${schedules.length} schedules with appointments for doctor ${doctorId}`);
    res.json(schedules);
    
  } catch (error) {
    console.error('❌ Error fetching doctor schedules with appointments:', error);
    res.status(500).json({ 
      error: 'Failed to fetch doctor schedules with appointments',
      details: error.message 
    });
  }
});

// GET ALL APPOINTMENTS (FOR DEBUGGING)
app.get('/api/debug-appointments', async (req, res) => {
  try {
    console.log('🔍 DEBUG: Checking ALL appointments in Firestore...');
    
    const appointmentsSnapshot = await db.collection('appointments').get();
    
    const allAppointments = [];
    appointmentsSnapshot.forEach(doc => {
      const data = doc.data();
      allAppointments.push({
        id: doc.id,
        patientName: data.patientName,
        scheduleId: data.scheduleId,
        doctorId: data.doctorId,
        status: data.status,
        date: data.date,
        time: data.time,
        // Log ALL fields to see what's available
        allFields: data
      });
    });
    
    console.log(`📋 Total appointments in Firestore: ${allAppointments.length}`);
    
    // Group by scheduleId to see distribution
    const bySchedule = {};
    allAppointments.forEach(apt => {
      const scheduleId = apt.scheduleId || 'NO_SCHEDULE_ID';
      if (!bySchedule[scheduleId]) {
        bySchedule[scheduleId] = [];
      }
      bySchedule[scheduleId].push(apt);
    });
    
    console.log('📊 Appointments by scheduleId:');
    Object.keys(bySchedule).forEach(scheduleId => {
      console.log(`   Schedule: ${scheduleId} - ${bySchedule[scheduleId].length} appointments`);
      bySchedule[scheduleId].forEach(apt => {
        console.log(`      - ${apt.patientName} (${apt.status})`);
      });
    });
    
    res.json({
      totalAppointments: allAppointments.length,
      bySchedule: bySchedule,
      allAppointments: allAppointments
    });
    
  } catch (error) {
    console.error('❌ Debug appointments error:', error);
    res.status(500).json({ error: error.message });
  }
});

// WebRTC Health Check
app.get('/api/webrtc/health', (req, res) => {
  console.log('📡 WebRTC Signaling Server Health Check');
  res.json({ 
    status: 'OK', 
    message: 'WEBRTC SIGNALING SERVER IS RUNNING!',
    activeRooms: Array.from(rooms.keys()),
    totalConnections: io.engine.clientsCount,
    timestamp: new Date().toISOString()
  });
});

// Start video call session
app.post('/api/webrtc/call/start', async (req, res) => {
  try {
    const { appointmentId, patientId, doctorId, patientName, doctorName } = req.body;
    
    console.log(`🎬 Starting video call for appointment: ${appointmentId}`);
    
    // Create call session in Firestore
    const callSession = {
      appointmentId: appointmentId,
      patientId: patientId,
      doctorId: doctorId,
      patientName: patientName,
      doctorName: doctorName,
      roomId: appointmentId, // Use appointmentId as roomId
      status: 'initiated',
      startedAt: new Date().toISOString(),
      participants: [patientId, doctorId],
      isActive: true
    };
    
    await db.collection('videoCalls').doc(appointmentId).set(callSession);
    
    // Update appointment status
    await db.collection('appointments').doc(appointmentId).update({
      callStatus: 'in-progress',
      callStartedAt: new Date().toISOString()
    });
    
    console.log(`✅ Video call session created: ${appointmentId}`);
    
    res.json({
      success: true,
      roomId: appointmentId,
      session: callSession
    });
    
  } catch (error) {
    console.error('❌ Error starting video call:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// End video call session
app.post('/api/webrtc/call/end', async (req, res) => {
  try {
    const { appointmentId, endedBy, duration } = req.body;
    
    console.log(`🛑 Ending video call for appointment: ${appointmentId}`);
    
    // Update call session in Firestore
    await db.collection('videoCalls').doc(appointmentId).update({
      status: 'ended',
      endedAt: new Date().toISOString(),
      endedBy: endedBy,
      duration: duration,
      isActive: false
    });
    
    // Update appointment status
    await db.collection('appointments').doc(appointmentId).update({
      callStatus: 'completed',
      callEndedAt: new Date().toISOString(),
      callDuration: duration
    });
    
    // Notify all users in the room to end call
    io.to(appointmentId).emit('call-ended', { endedBy: endedBy });
    
    console.log(`✅ Video call session ended: ${appointmentId}`);
    
    res.json({ success: true });
    
  } catch (error) {
    console.error('❌ Error ending video call:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get call session
app.get('/api/webrtc/call/:appointmentId', async (req, res) => {
  try {
    const { appointmentId } = req.params;
    
    const callDoc = await db.collection('videoCalls').doc(appointmentId).get();
    
    if (!callDoc.exists) {
      return res.status(404).json({ success: false, error: 'Call session not found' });
    }
    
    res.json({
      success: true,
      session: callDoc.data()
    });
    
  } catch (error) {
    console.error('❌ Error getting call session:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// FEEDBACK ROUTES

// Submit feedback
app.post('/api/feedback/submit', async (req, res) => {
  try {
    const {
      patientId,
      patientName,
      patientEmail,
      medicalCenterId,
      medicalCenterName,
      doctorId,
      doctorName,
      appointmentId,
      rating,
      comment,
      wouldRecommend,
      categories = [],
      anonymous = false
    } = req.body;

    console.log('📝 New feedback submission:', { patientName, doctorName, rating });

    // Validate required fields
    if (!patientId || !medicalCenterId || !doctorId || !rating) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: patientId, medicalCenterId, doctorId, rating'
      });
    }

    // Create feedback document
    const feedbackRef = db.collection('feedback').doc();
    const feedbackData = {
      feedbackId: feedbackRef.id,
      patientId,
      patientName: anonymous ? 'Anonymous' : patientName,
      patientEmail: anonymous ? '' : patientEmail,
      medicalCenterId,
      medicalCenterName,
      doctorId,
      doctorName,
      appointmentId: appointmentId || null,
      rating: parseInt(rating),
      comment: comment || '',
      wouldRecommend: wouldRecommend || false,
      categories: categories || [],
      anonymous: anonymous || false,
      status: 'approved', // Auto-approve for now, can change to 'pending' for moderation
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await feedbackRef.set(feedbackData);

    // Update doctor and medical center ratings
    await updateDoctorRatings(doctorId);
    await updateMedicalCenterRatings(medicalCenterId);

    console.log('✅ Feedback submitted successfully:', feedbackRef.id);

    res.json({
      success: true,
      message: 'Thank you for your feedback!',
      feedbackId: feedbackRef.id
    });

  } catch (error) {
    console.error('❌ Error submitting feedback:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to submit feedback: ' + error.message
    });
  }
});

// Get feedback for a doctor
app.get('/api/feedback/doctor/:doctorId', async (req, res) => {
  try {
    const { doctorId } = req.params;
    const { limit = 10, page = 1 } = req.query;

    console.log(`📊 Getting feedback for doctor: ${doctorId}`);

    const limitNum = parseInt(limit);
    const pageNum = parseInt(page);
    const offset = (pageNum - 1) * limitNum;

    // Get feedback with pagination
    let query = db.collection('feedback')
      .where('doctorId', '==', doctorId)
      .where('status', '==', 'approved')
      .orderBy('createdAt', 'desc');

    // Get total count
    const countSnapshot = await query.get();
    const total = countSnapshot.size;

    // Apply pagination
    const snapshot = await query.limit(limitNum).offset(offset).get();

    const feedback = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      feedback.push({
        id: doc.id,
        ...data,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || data.createdAt
      });
    });

    // Get doctor rating summary
    const doctorRatingDoc = await db.collection('doctorRatings').doc(doctorId).get();
    const ratingSummary = doctorRatingDoc.exists ? doctorRatingDoc.data() : null;

    res.json({
      success: true,
      data: {
        feedback,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          pages: Math.ceil(total / limitNum)
        },
        ratingSummary
      }
    });

  } catch (error) {
    console.error('❌ Error getting doctor feedback:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get feedback: ' + error.message
    });
  }
});

// Get feedback for a medical center
app.get('/api/feedback/medical-center/:medicalCenterId', async (req, res) => {
  try {
    const { medicalCenterId } = req.params;
    const { limit = 10, page = 1 } = req.query;

    console.log(`📊 Getting feedback for medical center: ${medicalCenterId}`);

    const limitNum = parseInt(limit);
    const pageNum = parseInt(page);
    const offset = (pageNum - 1) * limitNum;

    let query = db.collection('feedback')
      .where('medicalCenterId', '==', medicalCenterId)
      .where('status', '==', 'approved')
      .orderBy('createdAt', 'desc');

    const countSnapshot = await query.get();
    const total = countSnapshot.size;

    const snapshot = await query.limit(limitNum).offset(offset).get();

    const feedback = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      feedback.push({
        id: doc.id,
        ...data,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || data.createdAt
      });
    });

    // Get medical center rating summary
    const centerRatingDoc = await db.collection('medicalCenterRatings').doc(medicalCenterId).get();
    const ratingSummary = centerRatingDoc.exists ? centerRatingDoc.data() : null;

    res.json({
      success: true,
      data: {
        feedback,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          pages: Math.ceil(total / limitNum)
        },
        ratingSummary
      }
    });

  } catch (error) {
    console.error('❌ Error getting medical center feedback:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get feedback: ' + error.message
    });
  }
});

// Get patient's previous feedback
app.get('/api/feedback/patient/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;

    console.log(`📝 Getting feedback history for patient: ${patientId}`);

    const snapshot = await db.collection('feedback')
      .where('patientId', '==', patientId)
      .orderBy('createdAt', 'desc')
      .get();

    const feedback = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      feedback.push({
        id: doc.id,
        ...data,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || data.createdAt
      });
    });

    res.json({
      success: true,
      data: feedback
    });

  } catch (error) {
    console.error('❌ Error getting patient feedback:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get feedback history: ' + error.message
    });
  }
});

// Get overall ratings for doctor
app.get('/api/ratings/doctor/:doctorId', async (req, res) => {
  try {
    const { doctorId } = req.params;

    const ratingDoc = await db.collection('doctorRatings').doc(doctorId).get();

    if (!ratingDoc.exists) {
      return res.json({
        success: true,
        data: {
          averageRating: 0,
          totalReviews: 0,
          ratingDistribution: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }
        }
      });
    }

    res.json({
      success: true,
      data: ratingDoc.data()
    });

  } catch (error) {
    console.error('❌ Error getting doctor ratings:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get ratings: ' + error.message
    });
  }
});

// ADMIN: Get all feedback for moderation
app.get('/api/admin/feedback', async (req, res) => {
  try {
    const { status = 'pending', limit = 20, page = 1 } = req.query;

    console.log(`🛠️ Admin getting feedback with status: ${status}`);

    const limitNum = parseInt(limit);
    const pageNum = parseInt(page);
    const offset = (pageNum - 1) * limitNum;

    let query = db.collection('feedback')
      .where('status', '==', status)
      .orderBy('createdAt', 'desc');

    const countSnapshot = await query.get();
    const total = countSnapshot.size;

    const snapshot = await query.limit(limitNum).offset(offset).get();

    const feedback = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      feedback.push({
        id: doc.id,
        ...data,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || data.createdAt
      });
    });

    res.json({
      success: true,
      data: {
        feedback,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          pages: Math.ceil(total / limitNum)
        }
      }
    });

  } catch (error) {
    console.error('❌ Error getting admin feedback:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get feedback: ' + error.message
    });
  }
});

// ADMIN: Update feedback status
app.put('/api/admin/feedback/:feedbackId/status', async (req, res) => {
  try {
    const { feedbackId } = req.params;
    const { status } = req.body;

    if (!['approved', 'rejected'].includes(status)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid status. Must be "approved" or "rejected"'
      });
    }

    console.log(`🛠️ Admin updating feedback ${feedbackId} to status: ${status}`);

    const feedbackRef = db.collection('feedback').doc(feedbackId);
    const feedbackDoc = await feedbackRef.get();

    if (!feedbackDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'Feedback not found'
      });
    }

    const feedbackData = feedbackDoc.data();

    await feedbackRef.update({
      status: status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Update ratings if approved
    if (status === 'approved') {
      await updateDoctorRatings(feedbackData.doctorId);
      await updateMedicalCenterRatings(feedbackData.medicalCenterId);
    }

    res.json({
      success: true,
      message: `Feedback ${status} successfully`
    });

  } catch (error) {
    console.error('❌ Error updating feedback status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update feedback status: ' + error.message
    });
  }
});

// HELPER FUNCTIONS
async function updateDoctorRatings(doctorId) {
  try {
    const snapshot = await db.collection('feedback')
      .where('doctorId', '==', doctorId)
      .where('status', '==', 'approved')
      .get();

    let totalRating = 0;
    let totalReviews = 0;
    const ratingDistribution = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };

    snapshot.forEach(doc => {
      const data = doc.data();
      const rating = data.rating;
      totalRating += rating;
      totalReviews++;
      ratingDistribution[rating]++;
    });

    const averageRating = totalReviews > 0 ? totalRating / totalReviews : 0;

    await db.collection('doctorRatings').doc(doctorId).set({
      averageRating: parseFloat(averageRating.toFixed(1)),
      totalReviews,
      ratingDistribution,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`✅ Updated doctor ratings for ${doctorId}: ${averageRating.toFixed(1)} stars`);

  } catch (error) {
    console.error('❌ Error updating doctor ratings:', error);
  }
}

async function updateMedicalCenterRatings(medicalCenterId) {
  try {
    const snapshot = await db.collection('feedback')
      .where('medicalCenterId', '==', medicalCenterId)
      .where('status', '==', 'approved')
      .get();

    let totalRating = 0;
    let totalReviews = 0;
    const ratingDistribution = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };

    snapshot.forEach(doc => {
      const data = doc.data();
      const rating = data.rating;
      totalRating += rating;
      totalReviews++;
      ratingDistribution[rating]++;
    });

    const averageRating = totalReviews > 0 ? totalRating / totalReviews : 0;

    await db.collection('medicalCenterRatings').doc(medicalCenterId).set({
      averageRating: parseFloat(averageRating.toFixed(1)),
      totalReviews,
      ratingDistribution,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`✅ Updated medical center ratings for ${medicalCenterId}: ${averageRating.toFixed(1)} stars`);

  } catch (error) {
    console.error('❌ Error updating medical center ratings:', error);
  }
}

// Start server
server.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 QUEUE BACKEND + WEBRTC running on PORT 5001');
  console.log('📍 Available endpoints:');
  console.log('   http://localhost:5001/health');
  console.log('   ✅ QUEUE ENDPOINTS:');
  console.log('   POST http://localhost:5001/api/queue/start');
  console.log('   POST http://localhost:5001/api/queue/checkin');
  console.log('   GET  http://localhost:5001/api/queue/schedule/:scheduleId');
  console.log('   GET  http://localhost:5001/api/queue/patient/:patientId');
  console.log('   POST http://localhost:5001/api/queue/next');
  console.log('   ✅ PATIENT ENDPOINTS:');
  console.log('   GET  http://localhost:5001/api/patients/:patientId/appointments');
  console.log('   ✅ MEDICAL CENTER ENDPOINTS:');
  console.log('   GET  http://localhost:5001/api/medical-center/:medicalCenterId/active-queues');
  console.log('   ✅ DOCTOR ENDPOINTS:');
  console.log('   GET  http://localhost:5001/api/doctors/dashboard');
  console.log('   GET  http://localhost:5001/api/doctors/:doctorId/schedules');
  console.log('   ✅ WEBRTC ENDPOINTS:');
  console.log('   GET  http://localhost:5001/api/webrtc/health');
  console.log('   POST http://localhost:5001/api/webrtc/call/start');
  console.log('   POST http://localhost:5001/api/webrtc/call/end');
  console.log('   GET  http://localhost:5001/api/webrtc/call/:appointmentId');
  console.log('   ✅ DEBUG ENDPOINTS:');
  console.log('   GET  http://localhost:5001/api/debug-schedule-matching');
  console.log('   GET  http://localhost:5001/api/debug-schedule-relevance');
  console.log('   GET  http://localhost:5001/api/debug-appointments');
  console.log('   🔌 WebSocket: ws://localhost:5001');
  console.log('   📡 WebRTC Signaling: Active');
});