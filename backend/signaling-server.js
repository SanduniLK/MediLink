// signaling-server.js
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Store active rooms and users
const rooms = new Map();
const users = new Map();

app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Video Call Signaling Server is running!',
    activeRooms: Array.from(rooms.keys()),
    totalConnections: io.engine.clientsCount,
    timestamp: new Date().toISOString()
  });
});

// WebRTC Socket.io connection handling
io.on('connection', (socket) => {
  console.log('🔗 User connected:', socket.id);

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

  // Patient joins their personal room for notifications
  socket.on('patient-join', (patientId) => {
    socket.join(patientId);
    console.log(`👤 Patient ${patientId} joined personal room (Socket: ${socket.id})`);
  });

  // Handle call notifications (Doctor → Patient)
// In your Node.js signaling server - UPDATE the call notification:

socket.on('notify-call-started', (data) => {
  const { patientId, roomId, doctorName, doctorId, consultationType = 'video' } = data;
  
  console.log(`📞 Doctor ${doctorName} starting ${consultationType} call for patient ${patientId} in room ${roomId}`);
  
  // Notify the specific patient
  socket.to(`patient-${patientId}`).emit('call-started', {
    roomId: roomId,
    doctorName: doctorName,
    doctorId: doctorId,
    consultationType: consultationType,
    timestamp: new Date().toISOString()
  });
});

  // Handle call initiation
  socket.on('initiate-call', (data) => {
    const { targetUserId, roomId, offer, callerName, callType, callerId } = data;
    console.log(`📞 Call initiated by ${callerName} to ${targetUserId} in room ${roomId}`);
    
    socket.to(roomId).emit('incoming-call', {
      from: socket.id,
      fromUserId: callerId,
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

  // WebRTC signaling - Offer
  socket.on('webrtc-offer', (data) => {
    console.log(`📨 WebRTC offer from ${socket.id} to ${data.to}`);
    socket.to(data.to).emit('webrtc-offer', {
      from: socket.id,
      offer: data.offer
    });
  });

  // WebRTC signaling - Answer
  socket.on('webrtc-answer', (data) => {
    console.log(`📨 WebRTC answer from ${socket.id} to ${data.to}`);
    socket.to(data.to).emit('webrtc-answer', {
      from: socket.id,
      answer: data.answer
    });
  });

  // ICE candidates
  socket.on('ice-candidate', (data) => {
    socket.to(data.to).emit('ice-candidate', {
      from: socket.id,
      candidate: data.candidate
    });
  });

  // Media controls
  socket.on('toggle-media', (data) => {
    const { roomId, mediaType, isEnabled } = data;
    console.log(`🎛️ ${socket.id} toggled ${mediaType}: ${isEnabled}`);
    
    socket.to(roomId).emit('user-media-updated', {
      userId: socket.id,
      mediaType: mediaType,
      isEnabled: isEnabled
    });
  });
  // Add to your socket.io server
socket.on('join-patient-room', (data) => {
  const { patientId, patientName } = data;
  socket.join(`patient-${patientId}`);
  console.log(`Patient ${patientName} joined room: patient-${patientId}`);
});

socket.on('doctor-start-call', (data) => {
  const { patientId, roomId, doctorName, doctorId } = data;
  
  // Notify the specific patient
  io.to(`patient-${patientId}`).emit('doctor-call-started', {
    roomId: roomId,
    doctorName: doctorName,
    doctorId: doctorId,
    timestamp: new Date().toISOString()
  });
  
  console.log(`Doctor ${doctorName} started call for patient ${patientId} in room ${roomId}`);
});

  // Handle call end
  socket.on('end-call', (data) => {
    const { roomId } = data;
    console.log(`📞 Call ended by ${socket.id} in room ${roomId}`);
    
    socket.to(roomId).emit('call-ended', {
      endedBy: socket.id,
      timestamp: new Date().toISOString()
    });

    // Clean up room
    if (rooms.has(roomId)) {
      rooms.get(roomId).delete(socket.id);
      if (rooms.get(roomId).size === 0) {
        rooms.delete(roomId);
      }
    }
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

  // Handle disconnect
  socket.on('disconnect', () => {
    console.log('🔌 User disconnected:', socket.id);
    
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

    // Remove from users map
    users.delete(socket.id);
  });
});

const PORT = process.env.PORT || 5001;
server.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 VIDEO CALL SIGNALING SERVER running on PORT', PORT);
  console.log('📍 Available endpoints:');
  console.log('   http://localhost:5001/health');
  console.log('🔌 WebSocket: ws://localhost:5001');
  console.log('📡 WebRTC Signaling: Active');
});