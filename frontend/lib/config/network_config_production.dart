// Production Network Configuration for Cloud Deployment
// This file is optimized for cloud hosting (Render, Railway, etc.)

import 'dart:io';

class NetworkConfig {
  // Production URL (replace with your actual cloud URL)
  static const String productionURL = 'https://your-app-name.onrender.com';
  
  // Development URLs (for local testing)
  static const String localhost = 'http://localhost:3000';
  static const String computerIP = '192.168.1.38';
  static const String computerURL = 'http://$computerIP:3000';
  static const String androidEmulator = 'http://10.0.2.2:3000';
  
  // Environment detection
  static bool get isProduction {
    // You can set this via environment variable or build configuration
    return const bool.fromEnvironment('PRODUCTION', defaultValue: false);
  }
  
  // Current connection method based on environment
  static ConnectionMethod get currentMethod {
    if (isProduction) {
      return ConnectionMethod.production;
    } else if (Platform.isAndroid) {
      return ConnectionMethod.computerIP;
    } else if (Platform.isIOS) {
      return ConnectionMethod.computerIP;
    } else {
      return ConnectionMethod.localhost;
    }
  }
  
  // Get the current base URL with automatic fallback
  static String get baseUrl {
    switch (currentMethod) {
      case ConnectionMethod.production:
        return '$productionURL/api/auth';
      case ConnectionMethod.localhost:
        return '$localhost/api/auth';
      case ConnectionMethod.computerIP:
        return '$computerURL/api/auth';
      case ConnectionMethod.androidEmulator:
        return '$androidEmulator/api/auth';
    }
  }
  
  // Get all possible URLs for connection testing (production first)
  static List<String> get allUrls => isProduction ? [
    '$productionURL/api/auth',  // Production first
    '$computerURL/api/auth',    // Local fallback
    '$localhost/api/auth',      // Localhost fallback
  ] : [
    '$computerURL/api/auth',    // Local development
    '$localhost/api/auth',      // Localhost fallback
    '$androidEmulator/api/auth', // Android emulator fallback
  ];
  
  // Get test URLs for connection testing
  static List<String> get testUrls => isProduction ? [
    '$productionURL/api/auth/test',  // Production first
    '$computerURL/api/auth/test',    // Local fallback
    '$localhost/api/auth/test',      // Localhost fallback
  ] : [
    '$computerURL/api/auth/test',    // Local development
    '$localhost/api/auth/test',      // Localhost fallback
    '$androidEmulator/api/auth/test', // Android emulator fallback
  ];
  
  // Health check URLs
  static List<String> get healthCheckUrls => isProduction ? [
    '$productionURL/health',
    '$computerURL/health',
    '$localhost/health',
  ] : [
    '$computerURL/health',
    '$localhost/health',
    '$androidEmulator/health',
  ];
  
  // Test connectivity to all available endpoints
  static Future<String?> findWorkingEndpoint() async {
    // First try test endpoints
    for (String url in testUrls) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 10); // Longer timeout for production
        
        final uri = Uri.parse(url);
        final request = await client.getUrl(uri);
        final response = await request.close();
        
        if (response.statusCode == 200) {
          // Server is responding correctly
          client.close();
          // Return the base URL (without /test)
          return url.replaceAll('/test', '');
        }
        client.close();
      } catch (e) {
        print('❌ Failed to connect to $url: $e');
        continue;
      }
    }
    
    // If test endpoints fail, try base URLs
    for (String url in allUrls) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 10);
        
        final uri = Uri.parse(url);
        final request = await client.getUrl(uri);
        final response = await request.close();
        
        if (response.statusCode == 200 || response.statusCode == 404) {
          // Server is responding (404 is okay, means server is up)
          client.close();
          return url;
        }
        client.close();
      } catch (e) {
        print('❌ Failed to connect to $url: $e');
        continue;
      }
    }
    return null;
  }
  
  // Debug information
  static void printDebugInfo() {
    print('🔧 Production Network Configuration Debug:');
    print('🌍 Environment: ${isProduction ? "PRODUCTION" : "DEVELOPMENT"}');
    print('📱 Platform: ${Platform.operatingSystem}');
    print('🌐 Current Method: $currentMethod');
    print('🔗 Base URL: $baseUrl');
    print('📋 All URLs to try:');
    for (int i = 0; i < allUrls.length; i++) {
      print('   ${i + 1}. ${allUrls[i]}');
    }
  }
  
  // Validate current configuration
  static Future<bool> validateConfiguration() async {
    try {
      final workingUrl = await findWorkingEndpoint();
      if (workingUrl != null) {
        print('✅ Found working endpoint: $workingUrl');
        return true;
      } else {
        print('❌ No working endpoints found');
        return false;
      }
    } catch (e) {
      print('❌ Configuration validation failed: $e');
      return false;
    }
  }
}

enum ConnectionMethod {
  production,
  localhost,
  computerIP,
  androidEmulator,
}

