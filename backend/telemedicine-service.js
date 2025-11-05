const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');

class TelemedicineService {
  constructor(io) {
    this.io = io;
    this.db = admin.firestore();
    
    // Store active rooms and users for WebRTC
    this.rooms = new Map();
    this.users = new Map();
    
    this.initializeSocketHandlers();
  }

  initializeSocketHandlers() {
    this.io.on('connection', (socket) => {
      console.log('🔗 User connected for Telemedicine:', socket.id);
      
      // Patient joins their personal room
      this.handlePatientJoin(socket);
      
      // Doctor starts consultation
      this.handleDoctorStartCall(socket);
      
      // Patient answers/rejects call
      this.handlePatientAnswerCall(socket);
      this.handlePatientRejectCall(socket);
      
      // WebRTC signaling
      this.handleWebRTCOffer(socket);
      this.handleWebRTCAnswer(socket);
      this.handleICECandidate(socket);
      
      // Call management
      this.handleJoinCallRoom(socket);
      this.handleLeaveCallRoom(socket);
      this.handleEndCall(socket);
      this.handleMediaStateChange(socket);
      
      // Test endpoints
      this.handleTestNotification(socket);
      
      // Cleanup on disconnect
      this.handleDisconnect(socket);
    });
  }

  handlePatientJoin(socket) {
    socket.on('patient-join', (data) => {
      const patientId = typeof data === 'string' ? data : data.patientId;
      const userName = data.userName || 'Unknown Patient';
      const roomName = `patient_${patientId}`;
      
      console.log(`🎯 PATIENT JOIN:`);
      console.log(`   Patient ID: ${patientId}`);
      console.log(`   Patient Name: ${userName}`);
      console.log(`   Room Name: ${roomName}`);
      console.log(`   Socket ID: ${socket.id}`);
      
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
      this.users.set(socket.id, { 
        type: 'patient', 
        patientId: patientId,
        userName: userName,
        room: roomName,
        socketId: socket.id,
        joinedAt: new Date().toISOString()
      });
      
      console.log(`✅ Patient ${patientId} (${userName}) joined room: ${roomName}`);

      socket.emit('patient-room-joined', {
        room: roomName,
        patientId: patientId,
        status: 'success'
      });

      // Debug: Log active patient rooms
      this.logActiveRooms();
    });
  }

  handleDoctorStartCall(socket) {
    socket.on('doctor-start-call', async (data) => {
      console.log(`📞 DOCTOR starting ${data.callType} call to room ${data.roomId}`);
      
      const { roomId, callType, callerName, targetUserId, offer } = data;
      
      try {
        // Update telemedicine session status
        await this.updateTelemedicineSession(roomId, 'In-Progress');
        
        // Create active call record
        await this.createActiveCallRecord(data);
        
        // Notify patient about incoming call
        socket.to(roomId).emit('incoming-call-from-doctor', {
          doctorName: callerName,
          doctorId: targetUserId,
          roomId: roomId,
          callType: callType,
          timestamp: new Date().toISOString()
        });

        // Send WebRTC offer to patient
        socket.to(roomId).emit('webrtc-offer', {
          from: socket.id,
          offer: offer,
          callType: callType,
          roomId: roomId
        });

        console.log(`✅ Doctor call initiated successfully for room ${roomId}`);
        
      } catch (error) {
        console.error('❌ Error starting doctor call:', error);
        socket.emit('call-error', { error: 'Failed to start call' });
      }
    });
  }

  handlePatientAnswerCall(socket) {
    socket.on('patient-answer-call', (data) => {
      console.log(`✅ PATIENT answered call in room ${data.roomId}`);
      
      // Notify doctor that patient answered
      socket.to(data.roomId).emit('call-answered-by-patient', {
        from: socket.id,
        answer: data.answer,
        roomId: data.roomId
      });
    });
  }

  handlePatientRejectCall(socket) {
    socket.on('patient-reject-call', (data) => {
      console.log(`❌ PATIENT rejected call in room ${data.roomId}`);
      
      // Notify doctor that patient rejected
      socket.to(data.roomId).emit('call-rejected-by-patient', {
        from: socket.id,
        reason: data.reason,
        roomId: data.roomId
      });
    });
  }

  handleWebRTCOffer(socket) {
    socket.on('webrtc-offer', (data) => {
      console.log(`📨 WebRTC offer from ${socket.id} to room ${data.to}`);
      
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
  }

  handleWebRTCAnswer(socket) {
    socket.on('webrtc-answer', (data) => {
      console.log(`📨 WebRTC answer from ${socket.id} to ${data.to}`);
      socket.to(data.to).emit('webrtc-answer', {
        from: socket.id,
        answer: data.answer,
        timestamp: new Date().toISOString()
      });
    });
  }

  handleICECandidate(socket) {
    socket.on('ice-candidate', (data) => {
      console.log(`🧊 ICE candidate from ${socket.id} to ${data.to}`);
      socket.to(data.to).emit('ice-candidate', {
        from: socket.id,
        candidate: data.candidate
      });
    });
  }

  handleJoinCallRoom(socket) {
    socket.on('join-call-room', (roomId) => {
      socket.join(roomId);
      
      if (!this.rooms.has(roomId)) {
        this.rooms.set(roomId, new Set());
      }
      this.rooms.get(roomId).add(socket.id);
      
      console.log(`🎥 User ${socket.id} joined call room: ${roomId}`);
      
      // Notify others in the room
      socket.to(roomId).emit('user-joined', { userId: socket.id });
      
      // Send current room participants count
      const roomSize = this.rooms.get(roomId).size;
      this.io.to(roomId).emit('room-size-update', { size: roomSize });
    });
  }

  handleLeaveCallRoom(socket) {
    socket.on('leave-call-room', (roomId) => {
      socket.leave(roomId);
      
      if (this.rooms.has(roomId)) {
        this.rooms.get(roomId).delete(socket.id);
        if (this.rooms.get(roomId).size === 0) {
          this.rooms.delete(roomId);
        }
      }
      
      console.log(`🚪 User ${socket.id} left call room: ${roomId}`);
      socket.to(roomId).emit('user-left', { userId: socket.id });
    });
  }

  handleEndCall(socket) {
    socket.on('end-call', async (data) => {
      const { roomId, endedBy } = data;
      console.log(`📞 Call ended by ${socket.id} in room ${roomId}`);
      
      try {
        // Update telemedicine session status
        await this.updateTelemedicineSession(roomId, 'Completed');
        
        // Update active call record
        await this.endActiveCallRecord(roomId, endedBy);
        
        // Notify all participants
        socket.to(roomId).emit('call-ended', {
          endedBy: endedBy,
          timestamp: new Date().toISOString()
        });
        
        console.log(`✅ Call ended successfully for room ${roomId}`);
        
      } catch (error) {
        console.error('❌ Error ending call:', error);
      }
    });
  }

  handleMediaStateChange(socket) {
    socket.on('media-state-changed', (data) => {
      console.log(`🎛️ Media state changed: ${data.mediaType} = ${data.enabled}`);
      socket.to(data.roomId).emit('media-state-changed', data);
    });
  }

  handleTestNotification(socket) {
    socket.on('test-patient-notification', (data) => {
      console.log('🧪 TEST PATIENT NOTIFICATION:', data);
      socket.emit('test-response', {
        message: 'Test notification received by server',
        patientId: data.patientId,
        timestamp: new Date().toISOString()
      });
    });
  }

  handleDisconnect(socket) {
    socket.on('disconnect', () => {
      console.log('🔌 User disconnected from Telemedicine:', socket.id);
      
      // Remove user from all rooms
      this.rooms.forEach((users, roomId) => {
        if (users.has(socket.id)) {
          users.delete(socket.id);
          socket.to(roomId).emit('user-left', { userId: socket.id });
          
          if (users.size === 0) {
            this.rooms.delete(roomId);
          }
        }
      });
      
      // Remove user info
      this.users.delete(socket.id);
    });
  }

  // Database Methods
  async updateTelemedicineSession(appointmentId, status) {
    try {
      await this.db.collection('telemedicine_sessions').doc(appointmentId).update({
        status: status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(status === 'Completed' && { endedAt: admin.firestore.FieldValue.serverTimestamp() })
      });
    } catch (error) {
      console.error('❌ Error updating telemedicine session:', error);
      throw error;
    }
  }

  async createActiveCallRecord(callData) {
    try {
      const callRecord = {
        callId: uuidv4(),
        appointmentId: callData.roomId,
        chatRoomId: callData.roomId,
        consultationType: callData.callType,
        doctorId: callData.callerId,
        patientId: callData.targetUserId,
        status: 'connecting',
        doctorJoined: true,
        patientJoined: false,
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      await this.db.collection('active_calls').doc(callData.roomId).set(callRecord);
      return callRecord;
    } catch (error) {
      console.error('❌ Error creating active call record:', error);
      throw error;
    }
  }

  async endActiveCallRecord(roomId, endedBy) {
    try {
      await this.db.collection('active_calls').doc(roomId).update({
        status: 'ended',
        endedBy: endedBy,
        endedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (error) {
      console.error('❌ Error ending active call record:', error);
      throw error;
    }
  }

  // Utility Methods
  logActiveRooms() {
    console.log('\n🔍 ACTIVE TELEMEDICINE ROOMS:');
    const patientRooms = Array.from(this.io.sockets.adapter.rooms.keys())
      .filter(room => room.startsWith('patient_'));
    console.log(`   Patient rooms: ${patientRooms.join(', ') || 'NONE'}`);
    
    const callRooms = Array.from(this.rooms.keys());
    console.log(`   Active call rooms: ${callRooms.join(', ') || 'NONE'}`);
  }

  // Monitoring (call this from your main server)
  startMonitoring() {
    setInterval(() => {
      console.log('\n🏠 TELEMEDICINE CONNECTION MONITOR:');
      console.log(`   Total connections: ${this.io.engine.clientsCount}`);
      
      const rooms = this.io.sockets.adapter.rooms;
      const patientRooms = Array.from(rooms.keys()).filter(room => room.startsWith('patient_'));
      
      console.log(`   Patient rooms: ${patientRooms.length}`);
      patientRooms.forEach(roomName => {
        const room = rooms.get(roomName);
        const patientId = roomName.replace('patient_', '');
        console.log(`   👤 ${roomName}: ${room.size} socket(s)`);
        
        Array.from(room).forEach(socketId => {
          const userInfo = this.users.get(socketId);
          if (userInfo) {
            console.log(`      → ${userInfo.userName} (${socketId})`);
          }
        });
      });
      
      const callRooms = Array.from(this.rooms.keys());
      console.log(`   Active call rooms: ${callRooms.length}`);
      callRooms.forEach(roomName => {
        const room = this.rooms.get(roomName);
        console.log(`   📞 ${roomName}: ${room.size} participant(s)`);
      });
    }, 15000);
  }

  // Get service health
  getHealth() {
    return {
      status: 'OK',
      activePatientRooms: Array.from(this.io.sockets.adapter.rooms.keys()).filter(room => room.startsWith('patient_')).length,
      activeCallRooms: this.rooms.size,
      totalConnections: this.io.engine.clientsCount,
      timestamp: new Date().toISOString()
    };
  }
}

module.exports = TelemedicineService;