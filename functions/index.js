const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({origin: true});

admin.initializeApp();

exports.healthaiStatus = functions.https.onRequest((req, res) => {
  cors(req, res, () => {
    res.json({
      success: true,
      service: 'HealthAI Cloud',
      status: 'RUNNING',
      timestamp: new Date().toISOString()
    });
  });
});

exports.healthaiPredict = functions.https.onRequest(async (req, res) => {
  cors(req, res, async () => {
    try {
      const patientId = req.params[0] || req.body.patientId;
      
      console.log(`HealthAI prediction for: ${patientId}`);
      
      // Get patient data from Firestore
      const patientDoc = await admin.firestore().collection('patients').doc(patientId).get();
      
      if (!patientDoc.exists) {
        return res.json({
          success: false,
          error: 'Patient not found'
        });
      }
      
      const patientData = patientDoc.data();
      
      // Simple health prediction logic
      const age = patientData.age || 40;
      const bmi = patientData.bmi || 25;
      const hasDiabetes = patientData.additionalDetails?.familyDiabetes === 'Yes';
      
      // Calculate risk scores
      let diabetesScore = 0;
      const factors = [];
      
      if (bmi >= 25) diabetesScore += 30;
      if (bmi >= 30) diabetesScore += 20;
      if (age > 45) diabetesScore += 15;
      if (hasDiabetes) diabetesScore += 25;
      
      diabetesScore = Math.min(diabetesScore, 100);
      
      const riskLevel = diabetesScore >= 70 ? 'HIGH' : diabetesScore >= 40 ? 'MEDIUM' : 'LOW';
      const emoji = diabetesScore >= 70 ? '🔴' : diabetesScore >= 40 ? '🟡' : '🟢';
      
      const result = {
        success: true,
        data: {
          patient_id: patientId,
          timestamp: new Date().toISOString(),
          predictions: {
            diabetes: {
              risk_score: diabetesScore,
              risk_level: riskLevel,
              emoji: emoji,
              key_factors: factors,
              next_check: '3 months'
            },
            heart_disease: {
              risk_score: 40,
              risk_level: 'MEDIUM',
              emoji: '🟡',
              key_factors: []
            },
            general_health: {
              overall_score: Math.round((diabetesScore + 40) / 2),
              condition: diabetesScore >= 70 ? 'Needs attention' : 'Fair'
            }
          },
          recommendations: [
            'Schedule annual checkup',
            'Maintain healthy diet',
            'Exercise regularly',
            'Monitor blood pressure'
          ],
          data_quality: {
            confidence: 'HIGH',
            source: 'Firebase Cloud AI'
          }
        }
      };
      
      // Save to predictions collection
      await admin.firestore().collection('health_predictions').doc(patientId).set({
        ...result.data,
        created_at: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      res.json(result);
      
    } catch (error) {
      console.error('HealthAI error:', error);
      res.json({
        success: false,
        error: error.message
      });
    }
  });
});