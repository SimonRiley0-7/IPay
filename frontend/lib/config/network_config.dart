// Network Configuration for Mobile Development
// This file provides a robust solution for network connectivity issues

import 'dart:io';
import 'app_config.dart';

class NetworkConfig {
  // Your computer's current IP address (automatically detected)
  static const String computerIP = '192.168.1.38';
  
  // Available connection methods with fallback
  static const String localhost = 'http://localhost:3000';
  static const String computerIPUrl = 'http://$computerIP:3000';
  static const String androidEmulator = 'http://10.0.2.2:3000';
  
  // Current connection method (automatically determined)
  static ConnectionMethod get currentMethod {
    if (Platform.isAndroid) {
      // For Android physical devices, always use computer IP
      return ConnectionMethod.computerIP;
    } else if (Platform.isIOS) {
      // For iOS, try computer IP first
      return ConnectionMethod.computerIP;
    } else {
      // For web or other platforms
      return ConnectionMethod.localhost;
    }
  }
  
  // Get the current base URL with automatic fallback
  static String get baseUrl {
    // If production mode is enabled, use cloud URL
    if (AppConfig.isProduction) {
      return AppConfig.apiBaseUrl;
    }
    
    // Otherwise use local development logic
    switch (currentMethod) {
      case ConnectionMethod.localhost:
        return '$localhost/api/auth';
      case ConnectionMethod.computerIP:
        return '$computerIPUrl/api/auth';
      case ConnectionMethod.androidEmulator:
        return '$androidEmulator/api/auth';
    }
  }
  
  // Get all possible URLs for connection testing (in order of preference)
  static List<String> get allUrls => [
    '$computerIPUrl/api/auth',  // Primary for physical devices
    '$localhost/api/auth',       // Fallback
    '$androidEmulator/api/auth', // Android emulator fallback
  ];
  
  // Get test URLs for connection testing
  static List<String> get testUrls => [
    '$computerIPUrl/api/auth/test',  // Primary for physical devices
    '$localhost/api/auth/test',       // Fallback
    '$androidEmulator/api/auth/test', // Android emulator fallback
  ];
  
  // Health check URLs
  static List<String> get healthCheckUrls => [
    '$computerIPUrl/health',
    '$localhost/health',
    '$androidEmulator/health',
  ];
  
  // Test connectivity to all available endpoints
  static Future<String?> findWorkingEndpoint() async {
    // First try test endpoints
    for (String url in testUrls) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        
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
        client.connectionTimeout = const Duration(seconds: 5);
        
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
    print('🔧 Network Configuration Debug:');
    print('📱 Platform: ${Platform.operatingSystem}');
    print('🌐 Current Method: $currentMethod');
    print('🖥️ Computer IP: $computerIP');
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
  localhost,
  computerIP,
  androidEmulator,
}