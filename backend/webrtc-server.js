// webrtc-server.js - WebRTC Only Server
const express = require('express');
const cors = require('cors');
const app = express();
const PORT = 5002; // Different port to avoid conflict

const http = require('http');
const socketIo = require('socket.io');

console.log('🚀 Starting WebRTC-Only Server...');

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

// ==================== BASIC ROUTES ====================

// Root route
app.get('/', (req, res) => {
  console.log('🏠 WebRTC Root route accessed from:', req.ip);
  res.json({
    message: '🚀 WebRTC Signaling Server is RUNNING!',
    status: 'OK',
    endpoints: {
      health: '/health',
      webrtcHealth: '/api/webrtc/health'
    },
    serverTime: new Date().toISOString(),
    clientIp: req.ip
  });
});

// Health check
app.get('/health', (req, res) => {
  console.log('🏥 WebRTC Health check from:', req.ip);
  res.json({ 
    status: 'OK', 
    message: 'WEBRTC SERVER IS WORKING!',
    timestamp: new Date().toISOString(),
    clientIp: req.ip
  });
});

// WebRTC Health Check
app.get('/api/webrtc/health', (req, res) => {
  console.log('📡 WebRTC Health check from:', req.ip);
  res.json({ 
    status: 'OK', 
    message: 'WEBRTC SIGNALING SERVER IS RUNNING!',
    activeRooms: Array.from(rooms.keys()),
    totalConnections: io.engine.clientsCount,
    timestamp: new Date().toISOString()
  });
});

// ==================== SOCKET.IO WEBRTC HANDLERS ====================

io.on('connection', (socket) => {
  console.log('🔗 User connected for WebRTC:', socket.id);

  // Send welcome message
  socket.emit('welcome', {
    message: 'Connected to WebRTC Server!',
    yourId: socket.id,
    serverTime: new Date().toISOString()
  });

  // Handle patient joining their personal room
  socket.on('patient-join', (data) => {
    const patientId = typeof data === 'string' ? data : data.patientId;
    const roomName = `patient_${patientId}`;
    socket.join(roomName);
    console.log(`👤 Patient ${patientId} joined their personal room: ${roomName}`);
    
    users.set(socket.id, { 
      type: 'patient', 
      patientId: patientId,
      room: roomName 
    });
    
    socket.emit('patient-joined', { room: roomName, patientId: patientId });
  });

  // Handle notify-call-started (used by doctor to notify patient)
  socket.on('notify-call-started', (data) => {
    const { patientId, roomId, doctorName, doctorId, consultationType } = data;
    console.log(`🔔 Doctor ${doctorName} notifying patient ${patientId} about call in room ${roomId}`);
    
    // Notify the specific patient
    socket.to(`patient_${patientId}`).emit('call-started', {
      roomId: roomId,
      doctorName: doctorName,
      doctorId: doctorId,
      consultationType: consultationType || 'video',
      patientId: patientId,
      timestamp: new Date().toISOString()
    });
    
    // Also emit incoming-call event for compatibility
    socket.to(`patient_${patientId}`).emit('incoming-call', {
      roomId: roomId,
      doctorName: doctorName,
      doctorId: doctorId,
      consultationType: consultationType || 'video',
      patientId: patientId,
      timestamp: new Date().toISOString()
    });
  });

  // Handle join-call-room
  socket.on('join-call-room', (data) => {
    let roomId, userId, userName, isDoctor;
    
    if (typeof data === 'string') {
      roomId = data;
      userId = socket.id;
      userName = 'Unknown';
      isDoctor = false;
    } else {
      roomId = data.roomId;
      userId = data.userId || socket.id;
      userName = data.userName || 'Unknown';
      isDoctor = data.isDoctor || false;
    }
    
    socket.join(roomId);
    
    if (!rooms.has(roomId)) {
      rooms.set(roomId, new Set());
    }
    rooms.get(roomId).add(socket.id);
    
    users.set(socket.id, { 
      type: isDoctor ? 'doctor' : 'patient',
      userId: userId,
      userName: userName,
      room: roomId
    });
    
    console.log(`🎥 ${isDoctor ? 'Doctor' : 'Patient'} ${userName} joined room: ${roomId}`);
    
    socket.to(roomId).emit('user-joined', { 
      userId: userId,
      userName: userName,
      isDoctor: isDoctor
    });
  });

  // Test events
  socket.on('test-connection', (data) => {
    console.log('🧪 Test connection from:', data);
    socket.emit('test-response', {
      message: 'WebRTC Server is working!',
      received: data,
      serverTime: new Date().toISOString()
    });
  });

  // Handle call acceptance
  socket.on('call-accepted', (data) => {
    const { to, answer } = data;
    console.log(`✅ Call accepted by ${socket.id}, sending answer to: ${to}`);
    
    socket.to(to).emit('call-accepted', {
      from: socket.id,
      answer: answer
    });
  });

  // WebRTC signaling
   // WebRTC signaling handlers
  socket.on('webrtc-offer', (data) => {
    console.log('📨 WebRTC offer relay:', { from: socket.id, to: data.to });
    socket.to(data.to).emit('webrtc-offer', {
      from: socket.id,
      offer: data.offer,
      targetUserId: data.targetUserId
    });
  });

socket.on('webrtc-answer', (data) => {
    console.log('📨 WebRTC answer relay:', { from: socket.id, to: data.to });
    socket.to(data.to).emit('webrtc-answer', {
      from: socket.id,
      answer: data.answer
    });
  });



   socket.on('ice-candidate', (data) => {
    console.log('🧊 ICE candidate relay:', { from: socket.id, to: data.to });
    socket.to(data.to).emit('ice-candidate', {
      from: socket.id,
      candidate: data.candidate
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
    console.log('🔌 User disconnected:', socket.id);
    
    const userInfo = users.get(socket.id);
    if (userInfo) {
      console.log(`   User was: ${userInfo.userName} (${userInfo.type})`);
      users.delete(socket.id);
    }
    
    rooms.forEach((users, roomId) => {
      if (users.has(socket.id)) {
        users.delete(socket.id);
        socket.to(roomId).emit('user-left', { userId: socket.id });
      }
    });
  });
});

// ==================== START SERVER ====================

server.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 WEBRTC-ONLY SERVER running on PORT 5002');
  console.log('📍 Access via: http://localhost:5002');
  console.log('📍 Access via: http://192.168.1.126:5002');
  console.log('📍 Access via: http://10.0.2.2:5002 (emulator)');
  console.log('🔌 WebSocket: ws://192.168.1.126:5002');
  console.log('📡 WebRTC Signaling: ACTIVE');
  console.log('💡 Use this for testing WebRTC calls only');
});

console.log('✅ WebRTC server setup completed');