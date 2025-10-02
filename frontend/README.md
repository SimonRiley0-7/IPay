# iPay Flutter App

A smart shopping mobile application built with Flutter that revolutionizes the retail checkout experience.

## Features

- 🔐 Multi-method authentication (Google, Email, Phone OTP)
- 📷 Barcode scanning for product identification
- 🛒 Digital cart management
- 💳 UPI payments via Razorpay
- 🧾 Digital receipts with QR codes
- 📚 Order history and tracking
- 🎨 Modern, intuitive UI/UX

## Tech Stack

- **Framework**: Flutter (SDK >=3.0.0)
- **State Management**: Provider
- **Authentication**: Firebase Auth + Google Sign-In
- **HTTP Client**: Dio
- **Barcode Scanning**: mobile_scanner
- **Payment**: Razorpay Flutter SDK
- **Local Storage**: SharedPreferences
- **QR Generation**: qr_flutter

## Project Structure

```
frontend/
├── lib/
│   ├── main.dart              # App entry point
│   ├── models/                # Data models
│   ├── providers/             # State management providers
│   ├── screens/               # UI screens
│   │   ├── auth/              # Authentication screens
│   │   ├── home/              # Home and dashboard
│   │   ├── cart/              # Cart management
│   │   ├── checkout/          # Payment and checkout
│   │   ├── history/           # Order history
│   │   └── profile/           # User profile
│   ├── widgets/               # Reusable UI components
│   ├── services/              # API and external services
│   ├── utils/                 # Utilities and helpers
│   └── constants/             # App constants and themes
├── assets/
│   ├── images/                # Image assets
│   └── icons/                 # Icon assets
├── android/                   # Android-specific files
├── ios/                       # iOS-specific files
├── pubspec.yaml               # Dependencies and configuration
└── README.md                  # This file
```

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- Firebase project setup
- Razorpay merchant account

### Installation

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Set up Firebase:
   - Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Configure Firebase Authentication and enable required sign-in methods

4. Configure Razorpay:
   - Update API keys in the configuration

5. Run the app:
   ```bash
   flutter run
   ```

## Configuration

### Firebase Setup
1. Create a new Firebase project
2. Enable Authentication with Google, Email/Password, and Phone providers
3. Download configuration files and place in respective platform directories

### Razorpay Setup
1. Create merchant account on Razorpay
2. Get API keys from dashboard
3. Update configuration in the app

## Key Dependencies

- `provider`: State management across the app
- `firebase_auth`: Authentication services
- `google_sign_in`: Google OAuth integration
- `mobile_scanner`: Camera-based barcode scanning
- `razorpay_flutter`: Payment processing
- `dio`: HTTP client for API communication
- `shared_preferences`: Local data storage

## Development

```bash
# Get dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Build for Android
flutter build apk

# Build for iOS
flutter build ios

# Run tests
flutter test
```

## App Architecture

The app follows a clean architecture pattern with:

- **Models**: Data structures and business entities
- **Providers**: State management using Provider pattern
- **Services**: External API communication and business logic
- **Screens**: UI pages and navigation
- **Widgets**: Reusable UI components

## Supported Platforms

- ✅ Android (API 21+)
- ✅ iOS (iOS 11.0+)

## Contributing

1. Follow Flutter coding conventions
2. Write tests for new features
3. Update documentation for API changes
4. Ensure cross-platform compatibility
















