require("dotenv").config();
const admin = require('firebase-admin');

// IMPORTANT: Never commit serviceAccountKey.json to source control.
// Prefer loading from environment or secret manager. This remains for local dev only.
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

// Initialize Firestore and export both admin and db for callers
const db = admin.firestore();

module.exports = { admin, db };