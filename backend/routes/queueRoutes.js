const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');

// Start consultation - USING APPOINTMENTS COLLECTION + PHYSICAL ONLY
router.post('/start', async (req, res) => {
  try {
    const { scheduleId, doctorId, medicalCenterId, doctorName, medicalCenterName } = req.body;

    console.log('🔄 Starting consultation for schedule:', scheduleId);

    // 1. Validate schedule exists
    const scheduleDoc = await admin.firestore().collection('doctorSchedules').doc(scheduleId).get();
    if (!scheduleDoc.exists) {
      return res.status(404).json({ success: false, error: 'Schedule not found' });
    }

    const schedule = scheduleDoc.data();

    // 2. Get PHYSICAL appointments from appointments collection
    const appointmentsSnapshot = await admin.firestore()
      .collection('appointments')
      .where('scheduleId', '==', scheduleId)
      .where('appointmentType', '==', 'physical')
      .get();

    console.log('👥 Found PHYSICAL appointments:', appointmentsSnapshot.size);

    if (appointmentsSnapshot.empty) {
      return res.status(404).json({ 
        success: false, 
        error: 'No physical appointments found for this schedule' 
      });
    }

    // 3. Process appointments and assign token numbers
    const batch = admin.firestore().batch();
    let tokenNumber = 1;
    const patientsArray = [];

    appointmentsSnapshot.forEach(doc => {
      const appointmentRef = admin.firestore().collection('appointments').doc(doc.id);
      const appointment = doc.data();
      
      console.log(`   📝 Processing: ${appointment.patientName} - ${appointment.appointmentType}`);

      // ✅ FIX: ADD UPDATE OPERATION TO BATCH
      batch.update(appointmentRef, {
        tokenNumber: tokenNumber,
        queueStatus: 'waiting',
        currentPosition: tokenNumber,
        checkedIn: false,
        status: 'confirmed',
        updatedAt: new Date()
      });

      // Add to patients array for response
      patientsArray.push({
        appointmentId: doc.id,
        patientId: appointment.patientId,
        patientName: appointment.patientName,
        tokenNumber: tokenNumber,
        status: 'waiting',
        checkedIn: false,
        appointmentType: appointment.appointmentType,
        patientAge: appointment.patientAge,
        patientGender: appointment.patientGender,
        patientPhone: appointment.patientPhone
      });

      tokenNumber++;
    });

    // ✅ FIX: Now the batch has actual operations to commit
    await batch.commit();
    console.log('✅ Updated appointments with token numbers');

    // 4. Generate unique queueId
    const queueId = `queue_${scheduleId}_${Date.now()}`;

    // ✅ FIX: Also create the queue in doctorQueues collection
    await admin.firestore().collection('doctorQueues').doc(queueId).set({
      queueId: queueId,
      scheduleId: scheduleId,
      doctorId: doctorId,
      doctorName: doctorName,
      medicalCenterId: medicalCenterId,
      medicalCenterName: medicalCenterName,
      status: 'in-progress',
      startTime: new Date(),
      currentToken: 1,
      totalPatients: appointmentsSnapshot.size,
      patients: patientsArray,
      isActive: true,
      maxPatients: appointmentsSnapshot.size,
      createdAt: new Date(),
      updatedAt: new Date()
    });

    // 5. Update schedule with queue info
    await admin.firestore().collection('doctorSchedules').doc(scheduleId).update({
      status: 'in-progress',
      queueStarted: true,
      queueStartTime: new Date(),
      currentToken: 1,
      totalPatients: appointmentsSnapshot.size,
      queueId: queueId,
      updatedAt: new Date()
    });

    console.log('✅ Queue started successfully!');

    // 6. Return complete response
    const responseData = {
     queueId: queueId,
      scheduleId: scheduleId,
      doctorId: doctorId,
      doctorName: doctorName,
      medicalCenterId: medicalCenterId,
      medicalCenterName: medicalCenterName,
      totalPatients: appointmentsSnapshot.size,
      currentToken: 1,
      queueStarted: true,
      queueStartTime: new Date().toISOString(),
      patients: patientsArray
    };
    console.log('🔍 DEBUG Response Data Structure:', {
      hasQueueId: !!responseData.queueId,
      hasPatients: !!responseData.patients,
      patientsCount: responseData.patients.length,
      queueId: responseData.queueId,
      allFields: Object.keys(responseData)
    });

    console.log('📤 Sending response with:', {
      queueId: responseData.queueId,
      patientsCount: responseData.patients.length
    });

    // ✅ DEBUG: Log the exact response being sent
    console.log('🔍 DEBUG Full Response Data:', JSON.stringify({
      success: true, 
      message: `Queue started with ${appointmentsSnapshot.size} physical patients`,
      data: responseData
    }, null, 2));

    res.json({ 
      success: true, 
      message: `Queue started with ${appointmentsSnapshot.size} physical patients`,
      data: responseData
    });
  } catch (error) {
    console.error('❌ Error starting consultation:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
// Get queue status - USING APPOINTMENTS COLLECTION
// Get queue status - USING doctorQueues COLLECTION
router.get('/schedule/:scheduleId', async (req, res) => {
  try {
    const { scheduleId } = req.params;
    
    console.log('📋 Getting queue status for schedule:', scheduleId);

    // 1. Get active queue from doctorQueues
    const queuesSnapshot = await admin.firestore()
      .collection('doctorQueues')
      .where('scheduleId', '==', scheduleId)
      .where('isActive', '==', true)
      .limit(1)
      .get();

    if (queuesSnapshot.empty) {
      return res.status(404).json({ success: false, error: 'No active queue found for this schedule' });
    }
    
    const queueDoc = queuesSnapshot.docs[0];
    const queue = queueDoc.data();

    console.log('✅ Found queue in doctorQueues:', queue.queueId);

    // 2. Return the queue data directly from doctorQueues
    // Don't manually reconstruct or mix with appointments collection
    const responseData = {
      queueId: queue.queueId,
      scheduleId: queue.scheduleId,
      doctorId: queue.doctorId,
      doctorName: queue.doctorName,
      medicalCenterName: queue.medicalCenterName,
      queueStarted: true,
      queueStartTime: queue.startTime,
      currentToken: queue.currentToken || 1,
      totalPatients: queue.totalPatients || 0,
      patients: queue.patients || [] // This comes from the queue document itself
    };

    console.log('✅ Returning queue data from doctorQueues:', {
      queueId: responseData.queueId,
      patientsCount: responseData.patients.length,
      currentToken: responseData.currentToken
    });

    res.json({ 
      success: true, 
      data: responseData
    });
  } catch (error) {
    console.error('❌ Error getting queue:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
// Patient check-in - USING APPOINTMENTS COLLECTION
router.post('/checkin', async (req, res) => {
  try {
    const { patientId, scheduleId } = req.body;

    console.log('👤 Patient check-in:', { patientId, scheduleId });

    // Find patient's PHYSICAL appointment in this schedule
    const appointmentsSnapshot = await admin.firestore()
      .collection('appointments')
      .where('scheduleId', '==', scheduleId)
      .where('patientId', '==', patientId)
      .where('appointmentType', '==', 'physical') // ✅ ONLY PHYSICAL
      .limit(1)
      .get();

    if (appointmentsSnapshot.empty) {
      return res.status(404).json({ success: false, error: 'Physical appointment not found for this patient and schedule' });
    }

    const appointmentDoc = appointmentsSnapshot.docs[0];
    const appointment = appointmentDoc.data();

    // Update check-in status
    await appointmentDoc.ref.update({
      checkedIn: true,
      checkInTime: new Date(),
      queueStatus: 'checked-in',
      updatedAt: new Date()
    });

    console.log('✅ Patient checked in successfully:', appointment.patientName);

    res.json({ 
      success: true, 
      message: 'Patient checked in successfully',
      data: {
        patientName: appointment.patientName,
        tokenNumber: appointment.tokenNumber,
        queueStatus: 'checked-in',
        checkInTime: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('❌ Error checking in patient:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Move to next patient - USING APPOINTMENTS COLLECTION
router.post('/next', async (req, res) => {
  try {
    const { scheduleId } = req.body;

    console.log('⏭️ Moving to next patient in schedule:', scheduleId);

    // 1. Get schedule
    const scheduleDoc = await admin.firestore().collection('doctorSchedules').doc(scheduleId).get();
    if (!scheduleDoc.exists) {
      return res.status(404).json({ success: false, error: 'Schedule not found' });
    }

    const schedule = scheduleDoc.data();
    
    if (schedule.status !== 'in-progress') {
      return res.status(400).json({ success: false, error: 'No active queue found' });
    }

    const currentToken = schedule.currentToken || 1;

    // 2. Complete current PHYSICAL patient
    const currentAppointments = await admin.firestore()
      .collection('appointments')
      .where('scheduleId', '==', scheduleId)
      .where('tokenNumber', '==', currentToken)
      .where('appointmentType', '==', 'physical') // ✅ ONLY PHYSICAL
      .get();

    if (!currentAppointments.empty) {
      await currentAppointments.docs[0].ref.update({
        queueStatus: 'completed',
        consultationEndTime: new Date(),
        updatedAt: new Date()
      });
      console.log('✅ Completed physical patient with token:', currentToken);
    }

    // 3. Move to next token
    const nextToken = currentToken + 1;
    
    // Check if queue is completed (count only PHYSICAL appointments)
    const totalPhysicalAppointments = await admin.firestore()
      .collection('appointments')
      .where('scheduleId', '==', scheduleId)
      .where('appointmentType', '==', 'physical') // ✅ ONLY PHYSICAL
      .get();

    if (nextToken > totalPhysicalAppointments.size) {
      // Queue completed
      await admin.firestore().collection('doctorSchedules').doc(scheduleId).update({
        status: 'completed',
        queueStarted: false,
        updatedAt: new Date()
      });

      console.log('🏁 Queue completed for schedule:', scheduleId);

      res.json({ 
        success: true, 
        message: 'Queue completed - all physical patients seen',
        data: {
          queueActive: false,
          currentToken: nextToken - 1
        }
      });
    } else {
      // Continue queue - update next PHYSICAL patient to in-consultation
      const nextAppointments = await admin.firestore()
        .collection('appointments')
        .where('scheduleId', '==', scheduleId)
        .where('tokenNumber', '==', nextToken)
        .where('appointmentType', '==', 'physical') // ✅ ONLY PHYSICAL
        .get();

      if (!nextAppointments.empty) {
        await nextAppointments.docs[0].ref.update({
          queueStatus: 'in-consultation',
          consultationStartTime: new Date(),
          updatedAt: new Date()
        });
      }

      // Update schedule with new token
      await admin.firestore().collection('doctorSchedules').doc(scheduleId).update({
        currentToken: nextToken,
        updatedAt: new Date()
      });

      console.log('✅ Moved to next physical patient. Current token:', nextToken);

      res.json({ 
        success: true, 
        message: 'Next physical patient called',
        data: {
          currentToken: nextToken,
          queueActive: true
        }
      });
    }
  } catch (error) {
    console.error('❌ Error moving to next patient:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get queue for patient - FIXED
router.get('/patient/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;

    console.log('👤 Getting queue for patient:', patientId);

    // 1. Get patient's active appointments
    const appointmentsSnapshot = await admin.firestore()
      .collection('appointments')
      .where('patientId', '==', patientId)
      .where('status', 'in', ['confirmed', 'scheduled', 'waiting'])
      .get();

    if (appointmentsSnapshot.empty) {
      return res.status(404).json({ success: false, error: 'No active appointments found for patient' });
    }

    const patientQueues = [];

    // 2. Check each appointment's schedule for active queue
    for (const doc of appointmentsSnapshot.docs) {
      const appointment = doc.data();
      const scheduleId = appointment.scheduleId;

      if (scheduleId) {
        const scheduleDoc = await admin.firestore().collection('doctorSchedules').doc(scheduleId).get();
        
        if (scheduleDoc.exists) {
          const schedule = scheduleDoc.data();
          
          if (schedule.status === 'in-progress') {
            // This schedule has an active queue
            const appointmentsSnapshot = await admin.firestore()
              .collection('appointments')
              .where('scheduleId', '==', scheduleId)
              .orderBy('tokenNumber')
              .get();

            const allPatients = [];
            appointmentsSnapshot.forEach(aptDoc => {
              const aptData = aptDoc.data();
              allPatients.push({
                appointmentId: aptDoc.id,
                patientId: aptData.patientId,
                patientName: aptData.patientName,
                tokenNumber: aptData.tokenNumber,
                queueStatus: aptData.queueStatus,
                checkedIn: aptData.checkedIn
              });
            });

            const currentToken = schedule.currentToken || 1;
            const patientToken = appointment.tokenNumber || 0;
            const patientsAhead = Math.max(0, patientToken - currentToken);
            const estimatedWaitTime = patientsAhead * 15; // 15 mins per patient

            // ✅ FIX: Always include queueId with fallback
            const queueId = schedule.queueId || `queue_${scheduleId}`;

            patientQueues.push({
              queueId: queueId, // ✅ Always present
              scheduleId: scheduleId,
              doctorName: schedule.doctorName,
              medicalCenterName: schedule.medicalCenterName,
              appointmentDate: appointment.date,
              appointmentTime: appointment.time,
              currentToken: currentToken,
              patientToken: patientToken,
              patientsAhead: patientsAhead,
              estimatedWaitTime: estimatedWaitTime,
              totalPatients: allPatients.length,
              allPatients: allPatients,
              queueStartTime: schedule.queueStartTime,
              patientInfo: {
                patientName: appointment.patientName,
                patientId: appointment.patientId,
                tokenNumber: patientToken,
                queueStatus: appointment.queueStatus,
                checkedIn: appointment.checkedIn
              }
            });
          }
        }
      }
    }

    if (patientQueues.length === 0) {
      return res.status(404).json({ success: false, error: 'No active queues found for patient' });
    }

    res.json({ 
      success: true, 
      data: patientQueues[0] // Return the first active queue
    });
  } catch (error) {
    console.error('❌ Error getting patient queue:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Debug endpoint to check PHYSICAL appointments
router.get('/debug/physical-appointments/:scheduleId', async (req, res) => {
  try {
    const { scheduleId } = req.params;
    
    console.log('🔍 Debugging PHYSICAL appointments for schedule:', scheduleId);
    
    const appointmentsSnapshot = await admin.firestore()
      .collection('appointments')
      .where('scheduleId', '==', scheduleId)
      .where('appointmentType', '==', 'physical')
      .get();

    const appointments = [];
    appointmentsSnapshot.forEach(doc => {
      const data = doc.data();
      appointments.push({
        id: doc.id,
        patientName: data.patientName,
        status: data.status,
        patientId: data.patientId,
        scheduleId: data.scheduleId,
        appointmentType: data.appointmentType,
        date: data.date,
        time: data.time,
        tokenNumber: data.tokenNumber,
        queueStatus: data.queueStatus,
        checkedIn: data.checkedIn
      });
    });

    console.log(`📋 Found ${appointments.length} PHYSICAL appointments:`);
    appointments.forEach(apt => {
      console.log(`   - ${apt.patientName}: ${apt.status} (Type: ${apt.appointmentType}, Token: ${apt.tokenNumber})`);
    });

    res.json({
      success: true,
      scheduleId: scheduleId,
      totalPhysicalAppointments: appointments.length,
      appointments: appointments
    });
  } catch (error) {
    console.error('❌ Debug error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;