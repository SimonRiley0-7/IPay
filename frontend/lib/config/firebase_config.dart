// Firebase Configuration for NeoCart
// Replace these values with your actual Firebase project configuration

class FirebaseConfig {
  // Firebase configuration for IPay project
  
  static const String apiKey = "AIzaSyDU0Pr-xX9KjAzX3zSRUV9w0PH2B5TG6tU";
  static const String authDomain = "ipay-cbe49.firebaseapp.com";
  static const String projectId = "ipay-cbe49";
  static const String storageBucket = "ipay-cbe49.appspot.com";
  static const String messagingSenderId = "1065793645097";
  static const String appId = "1:1065793645097:android:d237c17ed8d1a87d6b4a38";
  
  // Optional: Measurement ID for Google Analytics
  static const String measurementId = "G-XXXXXXXXXX";
  
  // Firebase configuration map
  static const Map<String, String> config = {
    'apiKey': apiKey,
    'authDomain': authDomain,
    'projectId': projectId,
    'storageBucket': storageBucket,
    'messagingSenderId': messagingSenderId,
    'appId': appId,
  };
}

// Instructions:
// 1. Go to Firebase Console: https://console.firebase.google.com/
// 2. Select your project
// 3. Go to Project Settings (gear icon) > General
// 4. Scroll to "Your apps" section
// 5. Click on Web app or add new web app
// 6. Copy the configuration values and replace the placeholders above
