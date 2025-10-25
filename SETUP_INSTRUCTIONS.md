# MediLink Appointment System Setup Guide

## 🚀 How to Run the Project

### Prerequisites
- Node.js (v16 or higher)
- Flutter SDK (latest stable)
- Firebase project setup
- Android Studio or VS Code

---

## 📱 Backend Setup (Node.js)

### 1. Navigate to Backend Directory
```bash
cd backend
```

### 2. Install Dependencies
```bash
npm install
```

### 3. Environment Configuration
Create a `.env` file in the backend directory with your Firebase credentials:
```bash
# Firebase Configuration
FIREBASE_API_KEY=your_firebase_api_key
FIREBASE_AUTH_DOMAIN=your_project_id.firebaseapp.com
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_STORAGE_BUCKET=your_project_id.appspot.com
FIREBASE_MESSAGING_SENDER_ID=your_messaging_sender_id
FIREBASE_APP_ID=your_app_id

# Server Configuration
PORT=8080
```

### 4. Start the Backend Server
```bash
npm start
```

The server will run on `http://localhost:8080`

---

## 📱 Frontend Setup (Flutter)

### 1. Navigate to Frontend Directory
```bash
cd frontend
```

### 2. Install Flutter Dependencies
```bash
flutter pub get
```

### 3. Update Backend URL
In your Flutter files, update the `baseUrl` to match your backend:
- `lib/screens/doctor_screens/doctor_consultation_page.dart` (line ~15)
- `lib/screens/patient_screens/book_appointment_page.dart` (line ~15)
- `lib/screens/admin_screens/medical_center_dashboard.dart` (line ~20)
- `lib/screens/patient_screens/my_appointments_page.dart` (line ~15)

Change from:
```dart
final String baseUrl = 'http://localhost:8080/api';
```

To your actual backend URL (keep localhost:8080 if running locally)

### 4. Run Flutter App
```bash
flutter run
```

---

## 🏥 New Features Implemented

### ✅ Doctor Consultation Management
- **File**: `lib/screens/doctor_screens/doctor_consultation_page.dart`
- **Features**:
  - Set consultation schedule by medical center
  - Choose date and time slots
  - Select consultation type (Physical, Audio, Video)
  - View current availability

### ✅ Patient Appointment Booking
- **File**: `lib/screens/patient_screens/book_appointment_page.dart`
- **Features**:
  - Step-by-step booking process
  - Select medical center and doctor
  - Choose available time slots
  - Pick consultation type
  - Add patient notes

### ✅ Medical Center Admin Dashboard
- **File**: `lib/screens/admin_screens/medical_center_dashboard.dart`
- **Features**:
  - View **Requested** appointments (pending approval)
  - View **Confirmed** appointments (approved)
  - View **Cancelled** appointments
  - Approve/Cancel appointment actions
  - Filter by date

### ✅ Patient Appointment History
- **File**: `lib/screens/patient_screens/my_appointments_page.dart`
- **Features**:
  - View upcoming appointments
  - View past appointments
  - Track appointment status
  - Join online consultations

---

## 🔧 Backend API Endpoints

All endpoints are available at `http://localhost:8080/api/`:

### Doctor Availability
- `GET /doctor-availability` - Get doctor's available slots
- `POST /doctor-availability` - Create doctor availability

### Appointment Management
- `POST /appointments` - Book appointment
- `GET /appointments/patient` - Get patient appointments
- `GET /appointments/medical-center` - Get medical center appointments
- `PUT /appointments/:id/status` - Update appointment status

### Data Endpoints
- `GET /medical-centers` - Get all medical centers
- `GET /doctors/by-medical-center` - Get doctors by center

---

## 🏃‍♂️ Quick Start Commands

### Terminal 1 - Backend
```bash
cd backend
npm install
npm start
```

### Terminal 2 - Frontend
```bash
cd frontend
flutter pub get
flutter run
```

---

## 📊 Database Collections Used

### Firestore Collections:
- `appointments` - All appointment records
- `doctorAvailability` - Doctor consultation schedules
- `doctors` - Doctor profiles
- `medicalCenters` - Medical center information
- `patients` - Patient profiles

---

## 🎯 Testing the Features

### 1. Test Doctor Availability
- Navigate to Doctor Consultation page
- Select medical center and doctor
- Set date and time slots
- Create availability

### 2. Test Patient Booking
- Go to Book Appointment page
- Follow the step-by-step process
- Book an appointment

### 3. Test Admin Dashboard
- Open Medical Center Dashboard
- View requested appointments
- Approve or cancel appointments

### 4. Test Patient History
- Check My Appointments page
- View appointment status
- Check upcoming/past appointments

---

## 🚨 Troubleshooting

### Backend Issues:
- Make sure Firebase credentials are correct in `.env`
- Check if port 8080 is available
- Verify serviceAccountKey.json exists

### Frontend Issues:
- Run `flutter clean` then `flutter pub get`
- Check if backend URL is correct
- Ensure device/emulator is connected

### Network Issues:
- Use your computer's IP address instead of localhost for device testing
- Example: `http://192.168.1.100:8080/api`

---

## 📝 Next Steps

After running the project, you can:
1. Add sample data to Firestore
2. Test the appointment workflow
3. Customize the UI themes
4. Add more consultation types
5. Implement push notifications

Enjoy your new appointment scheduling system! 🎉


