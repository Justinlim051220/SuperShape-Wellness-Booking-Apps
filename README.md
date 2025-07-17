# SuperShape Wellness Mobile App

<div align="center">
  <img src="assets/logo.png" alt="SuperShape Wellness Logo" width="200"/>
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.7.2+-02569B?style=flat&logo=flutter)](https://flutter.dev)
  [![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=black)](https://firebase.google.com)
  [![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart)](https://dart.dev)
</div>

A comprehensive wellness booking mobile application built with Flutter and Firebase, featuring role-based access for students and instructors to manage fitness classes, events, and wellness programs.

## 🌟 Features

### 🎓 **Student Features**
- **Class Booking System**: Book fitness classes, yoga sessions, and wellness events
- **Timetable Management**: View personalized class schedules and upcoming events
- **Credit Management**: Track class credits, packages, and payment history
- **Event Participation**: Join special events and manage event cancellations
- **Waiting Lists**: Join waiting lists for fully booked classes
- **Profile Management**: Update personal information and preferences
- **Notifications**: Real-time announcements and booking confirmations
- **Payment Integration**: Multiple payment methods and receipt uploads
- **Digital Signatures**: Legal declarations with digital signature support

### 👨‍🏫 **Instructor Features**
- **Course Management**: Create and manage fitness classes and events
- **Student Tracking**: Monitor class attendance and student progress
- **Performance Analytics**: View teaching statistics and class metrics
- **Schedule Management**: Manage teaching timetables and availability
- **Profile Customization**: Update instructor bio, certifications, and specializations
- **Notification System**: Send announcements to students

### 🔐 **Authentication & Security**
- Firebase Authentication with email/password
- Role-based access control (Student/Instructor)
- Secure user data management
- Password reset functionality
- Terms & conditions acceptance with digital signatures

## 🛠️ Tech Stack

### **Frontend**
- **Flutter** (3.7.2+) - Cross-platform mobile development
- **Dart** - Programming language
- **Material Design** - UI components with custom theming

### **Backend & Services**
- **Firebase Core** - Backend infrastructure
- **Firebase Auth** - User authentication
- **Cloud Firestore** - Real-time database
- **Firebase Storage** - File and image storage

### **Key Dependencies**
```yaml
firebase_core: ^3.0.0          # Firebase integration
firebase_auth: ^5.0.0          # Authentication
cloud_firestore: ^5.0.0       # Database
firebase_storage: ^12.2.0     # File storage
provider: ^6.1.2               # State management
intl: ^0.19.0                  # Internationalization
image_picker: ^1.1.2           # Image selection
signature: ^5.4.0              # Digital signatures
fl_chart: ^0.69.0              # Charts and analytics
pdf: ^3.10.1                   # PDF generation
printing: ^5.10.0              # Document printing
```

## 📱 Screenshots & App Flow

### Authentication Flow
- **Splash Screen** → **Login** → **Registration** → **Profile Setup** → **Declaration & T&C**

### Student Journey
1. **Login** → **Timetable** → **Class Booking** → **Payment** → **Confirmation**
2. **Profile** → **My Bookings** → **Credit Management** → **Notifications**

### Instructor Journey
1. **Login** → **Instructor Dashboard** → **Course Management** → **Performance Analytics**
2. **Profile Management** → **Student Tracking** → **Notifications**

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.7.2 or higher)
- Dart SDK
- Android Studio / VS Code
- Firebase account
- Android/iOS development environment

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/supershape-wellness-app.git
   cd supershape-wellness-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Enable Authentication, Firestore, and Storage
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place configuration files in appropriate directories
   - Run Firebase CLI setup:
     ```bash
     firebase login
     flutterfire configure
     ```

4. **Configure Firebase Collections**
   Set up the following Firestore collections:
   ```
   ├── users/                    # User profiles
   ├── class/                    # Classes and events
   ├── notifications/            # System notifications
   ├── declarations/             # Legal declarations
   ├── terms_and_conditions/     # T&C content
   └── bookings/                 # User bookings (subcollection)
   ```

5. **Run the application**
   ```bash
   flutter run
   ```

### Firebase Rules Setup

**Firestore Security Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Bookings subcollection
      match /bookings/{bookingId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Classes and events are readable by authenticated users
    match /class/{classId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'instructor';
    }
    
    // Notifications are readable by all authenticated users
    match /notifications/{notificationId} {
      allow read: if request.auth != null;
    }
  }
}
```

## 🏗️ Project Structure

```
lib/
├── auth/                      # Authentication modules
│   ├── data/                  # Firebase auth implementation
│   ├── domain/                # Auth entities and repositories
│   ├── login_screen.dart      # Login interface
│   ├── profile_setup_screen.dart
│   └── declaration_screen.dart
├── screens/                   # Main app screens
│   ├── course/                # Course-related screens
│   ├── profile/               # User profile screens
│   ├── payment/               # Payment interfaces
│   ├── timetable_screen.dart  # Class schedules
│   └── splash_screen.dart     # App initialization
├── Instructor_part/           # Instructor-specific features
│   ├── Instructor_screen/     # Instructor interfaces
│   ├── Instructor_widgets/    # Custom instructor widgets
│   └── Instuctor_model/       # Instructor data models
├── widgets/                   # Reusable UI components
├── utils/                     # Utilities and themes
├── models/                    # Data models
├── services/                  # Business logic services
└── main.dart                  # App entry point
```

## 🎨 UI/UX Design

### Color Scheme
- **Primary Color**: `#BDA25B` (Gold/Bronze)
- **Background**: White (`#FFFFFF`)
- **Text**: Various gray shades
- **Accent**: Gold theme throughout

### Key UI Components
- **Custom Buttons**: Rounded with gold theme
- **Form Fields**: Outlined with focus states
- **Cards**: Elevated with shadows
- **Bottom Navigation**: Role-based navigation
- **Charts**: Interactive performance analytics

## 🔧 Configuration

### Environment Setup
1. **Development**: Uses Firebase emulators (optional)
2. **Production**: Live Firebase services

### App Configuration
```dart
// Theme configuration
final ThemeData myTheme = ThemeData(
  primaryColor: const Color(0xFFBDA25B),
  scaffoldBackgroundColor: Colors.white,
  // Custom button and input themes
);

// Firebase configuration
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## 📊 Data Models

### User Model
```dart
class AppUser {
  final String uid;
  final String email;
  final String role; // 'student' or 'instructor'
  final String fullName;
  final String phone;
  final String dob;
}
```

### Class Model
```dart
class ClassModel {
  final String id;
  final String title;
  final String date;
  final String time;
  final String instructorId;
  final int slots;
  final int booked;
  final double price;
  final String type; // 'class' or 'event'
}
```

## 🚦 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Generate test coverage
flutter test --coverage
```

## 📦 Build & Release

### Android
```bash
# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

### iOS
```bash
# Build iOS
flutter build ios --release
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


# SuperShape-Wellness-Booking-Apps