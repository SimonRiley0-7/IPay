# 🔥 Firebase Setup Instructions for NeoCart

## Quick Setup Checklist

### ✅ **Step 1: Create Firebase Project**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Create a project"**
3. Project name: `neocart-app`
4. Enable Google Analytics (optional)
5. Click **"Create project"**

### ✅ **Step 2: Enable Authentication**
1. Go to **Authentication** → **Sign-in method**
2. Enable **Phone** authentication
3. Enable **Google** authentication
   - Add your support email
   - Save configuration

### ✅ **Step 3: Add Android App**
1. **Project Settings** → **General** → **Add app** → **Android**
2. **Android package name**: `com.example.ipay`
3. **Download `google-services.json`**
4. **Place file**: `frontend/android/app/google-services.json`

### ✅ **Step 4: Get Backend Credentials**
1. **Project Settings** → **Service accounts**
2. **Generate new private key** (downloads JSON file)
3. **Extract values** for backend `.env`:

```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY_ID=your-private-key-id  
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
```

### ✅ **Step 5: Get Frontend Configuration**
1. **Project Settings** → **General** → **Add app** → **Web**
2. **App name**: `NeoCart Web`
3. **Copy configuration** and update `frontend/lib/config/firebase_config.dart`:

```dart
static const String apiKey = "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
static const String authDomain = "your-project.firebaseapp.com";
static const String projectId = "your-project-id";
static const String storageBucket = "your-project.appspot.com";
static const String messagingSenderId = "123456789";
static const String appId = "1:123456789:web:abcdefghijklmnop";
```

## 🔧 Configuration Files to Update

### **Backend: Create `.env` file**
```env
# Copy from backend/env.example and update with your values
MONGODB_URI=mongodb+srv://user1:neocart@ipay.gkxq3oi.mongodb.net/?retryWrites=true&w=majority&appName=IPay
JWT_SECRET=your_super_secret_jwt_key_here
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY_ID=your-private-key-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_KEY\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
```

### **Frontend: Update `firebase_config.dart`**
Replace the placeholder values in `frontend/lib/config/firebase_config.dart` with your actual Firebase configuration.

### **Android: Enable Google Services**
Uncomment this line in `frontend/android/app/build.gradle.kts`:
```kotlin
id("com.google.gms.google-services")
```

## 🧪 Testing Your Setup

### **1. Test Backend**
```bash
cd backend
npm run dev
```
Should show: "📊 MongoDB Connected" and "🚀 iPay Backend Server running"

### **2. Test Frontend**
```bash
cd frontend  
flutter run -d chrome
```
Click "Sign in using Google" - should open Google sign-in popup

### **3. Test Full Flow**
1. Click Google Sign-In button
2. Complete Google authentication
3. Check backend logs for user creation
4. Verify user appears in MongoDB

## 🚨 Common Issues & Solutions

### **"Project not found"**
- Check `FIREBASE_PROJECT_ID` matches your Firebase project ID exactly

### **"Invalid private key"**
- Ensure private key includes `\n` characters: `"-----BEGIN PRIVATE KEY-----\nYOUR_KEY\n-----END PRIVATE KEY-----\n"`
- Make sure the key is wrapped in quotes

### **"Unauthorized domain"**
- Add your domain to Firebase Console → Authentication → Settings → Authorized domains

### **"API not enabled"**
- Go to Google Cloud Console → APIs & Services
- Enable: Firebase Authentication API, Identity and Access Management API

### **Android build fails****
- Ensure `google-services.json` is in `frontend/android/app/`
- Uncomment Google Services plugin in `build.gradle.kts`

## 📞 Need Help?

If you encounter issues:
1. Check Firebase Console for error messages
2. Look at browser developer console for frontend errors  
3. Check backend terminal for server errors
4. Verify all configuration values are correct

## 🎯 Next Steps After Setup

Once Firebase is configured:
1. Test Google Sign-In functionality
2. Implement phone number authentication
3. Add user profile management
4. Set up product catalog and cart system

---

**Ready to test?** Follow the steps above, then run your app and try the Google Sign-In! 🚀

