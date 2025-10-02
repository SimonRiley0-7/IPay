# Firebase Setup Guide for NeoCart

This guide will help you set up Firebase for Google Sign-In and Phone Authentication in your NeoCart application.

## 🔥 Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `neocart-app` (or your preferred name)
4. Enable Google Analytics (optional)
5. Click "Create project"

## 🔐 Step 2: Enable Authentication

1. In your Firebase project, go to **Authentication** → **Sign-in method**
2. Enable the following providers:
   - **Phone** ✅
   - **Google** ✅
   - **Email/Password** (optional for future use)

### Configure Google Sign-In:
1. Click on **Google** provider
2. Enable it
3. Add your support email
4. Add authorized domains if needed
5. Save

### Configure Phone Authentication:
1. Click on **Phone** provider  
2. Enable it
3. Save

## 📱 Step 3: Add Android App

1. Go to **Project Settings** → **General**
2. Click **Add app** → **Android**
3. Enter Android package name: `com.example.ipay`
4. Download `google-services.json`
5. Place it in `frontend/android/app/`

## 🍎 Step 4: Add iOS App (Optional)

1. Click **Add app** → **iOS**
2. Enter iOS bundle ID: `com.example.ipay`
3. Download `GoogleService-Info.plist`
4. Place it in `frontend/ios/Runner/`

## 🔑 Step 5: Generate Service Account Key

1. Go to **Project Settings** → **Service accounts**
2. Click **Generate new private key**
3. Download the JSON file
4. Extract the following values for your `.env` file:

```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY_ID=your-private-key-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
```

## 🌐 Step 6: Get Web Configuration

1. Go to **Project Settings** → **General**
2. Scroll to **Your apps** section
3. Click **Web app** (</>) icon
4. Register your web app
5. Copy the config object values:

```javascript
const firebaseConfig = {
  apiKey: "your-api-key",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "123456789",
  appId: "your-app-id"
};
```

## 📋 Step 7: Update Environment Files

### Backend (.env):
```env
# Firebase Admin SDK Configuration
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY_ID=your-private-key-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com

# Google OAuth (for additional verification)
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
```

### Frontend (create firebase_config.dart):
```dart
class FirebaseConfig {
  static const String apiKey = "your-api-key";
  static const String authDomain = "your-project.firebaseapp.com";
  static const String projectId = "your-project-id";
  static const String storageBucket = "your-project.appspot.com";
  static const String messagingSenderId = "123456789";
  static const String appId = "your-app-id";
}
```

## 🔧 Step 8: Configure OAuth Consent Screen

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Go to **APIs & Services** → **OAuth consent screen**
4. Configure the consent screen:
   - App name: "NeoCart"
   - User support email: your email
   - App domain: your domain (if any)
   - Developer contact: your email
5. Add scopes: `email`, `profile`
6. Add test users if in testing mode

## 🧪 Step 9: Test Configuration

1. Update your backend `.env` file with the Firebase credentials
2. Restart your backend server
3. Test the authentication endpoints:
   - `POST /api/auth/google` (with Firebase ID token)
   - `POST /api/auth/phone/verify` (with phone verification)

## 📱 Step 10: Frontend Integration

The frontend will need:
1. Firebase SDK initialization
2. Google Sign-In implementation
3. Phone authentication implementation
4. Token management

## 🔒 Security Notes

- Never commit your private keys to version control
- Use environment variables for all sensitive data
- Enable App Check for production (optional but recommended)
- Set up proper security rules for Firestore if you use it later

## 🆘 Troubleshooting

### Common Issues:

1. **"Project not found"**: Check your project ID in environment variables
2. **"Invalid private key"**: Ensure the private key format is correct with `\n` characters
3. **"Unauthorized domain"**: Add your domain to authorized domains in Firebase console
4. **"API not enabled"**: Enable required APIs in Google Cloud Console

### Required APIs:
- Firebase Authentication API
- Identity and Access Management (IAM) API
- Google Sign-In API

---

After completing this setup, your Firebase authentication will be ready for both Google Sign-In and Phone verification! 🚀

