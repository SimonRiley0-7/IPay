// App Configuration - Easy switching between local and production
class AppConfig {
  // Set this to true when you want to build for distribution
  static const bool isProduction = false; // Change to true for APK builds
  
  // Production URLs (replace with your actual cloud URL)
  static const String productionBackendUrl = 'https://ipay-2oc7.onrender.com';
  
  // Local development URLs
  static const String localBackendUrl = 'http://localhost:3000';
  
  // Get the current backend URL
  static String get backendUrl {
    return isProduction ? productionBackendUrl : localBackendUrl;
  }
  
  // Get the current API base URL
  static String get apiBaseUrl {
    return '$backendUrl/api/auth';
  }
  
  // Debug info
  static void printConfig() {
    print('🔧 App Configuration:');
    print('🌍 Environment: ${isProduction ? "PRODUCTION" : "DEVELOPMENT"}');
    print('🔗 Backend URL: $backendUrl');
    print('📡 API Base URL: $apiBaseUrl');
  }
  
  // Print config on class initialization
  static void init() {
    printConfig();
  }
}

