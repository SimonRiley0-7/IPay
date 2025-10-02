// API Configuration for Mobile Development
import 'dart:io';
import 'network_config.dart';

class ApiConfig {
  // Get the base URL from NetworkConfig
  static String get baseUrl => NetworkConfig.baseUrl;
  
  // Get all possible base URLs for fallback
  static List<String> get allBaseUrls => NetworkConfig.allUrls;
  
  // Health check endpoint
  static String get healthCheck {
    return baseUrl.replaceAll('/api/auth', '/health');
  }
  
  // Common headers for API requests
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'iPay-Mobile/1.0',
  };
  
  // Request timeout duration (increased for better reliability)
  static const Duration timeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 10);
  
  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Debug method to test connectivity
  static void printDebugInfo() {
    print('🔧 API Configuration Debug:');
    print('📱 Platform: ${Platform.operatingSystem}');
    print('🌐 Base URL: $baseUrl');
    print('🏥 Health Check: $healthCheck');
    print('⏱️ Timeout: ${timeout.inSeconds}s, Connect: ${connectTimeout.inSeconds}s');
    print('🔄 Max Retries: $maxRetries');
  }
  
  // Test all endpoints and return the working one
  static Future<String?> findWorkingEndpoint() async {
    return await NetworkConfig.findWorkingEndpoint();
  }
  
  // Validate current configuration
  static Future<bool> validateConfiguration() async {
    return await NetworkConfig.validateConfiguration();
  }
}