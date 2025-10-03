// Network Configuration for Production
// Simplified configuration that only uses cloud backend

import 'dart:io';
import 'app_config.dart';

class NetworkConfig {
  // Get the current base URL (always cloud backend)
  static String get baseUrl => AppConfig.apiBaseUrl;
  
  // Get test URLs for connection testing (only cloud backend)
  static List<String> get testUrls => [
    '${AppConfig.apiBaseUrl}/test',
  ];
  
  // Health check URLs (only cloud backend)
  static List<String> get healthCheckUrls => [
    '${AppConfig.apiBaseUrl.replaceAll('/api/auth', '')}/health',
  ];
  
  // Test connectivity to cloud backend
  static Future<String?> findWorkingEndpoint() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      
      final uri = Uri.parse(testUrls.first);
      final request = await client.getUrl(uri);
      final response = await request.close();
      
      if (response.statusCode == 200) {
        client.close();
        return AppConfig.apiBaseUrl;
      }
      client.close();
    } catch (e) {
      print('❌ Failed to connect to cloud backend: $e');
    }
    return null;
  }
  
  // Debug information
  static void printDebugInfo() {
    print('🌐 Network Configuration:');
    print('   Production Mode: ${AppConfig.isProduction}');
    print('   Base URL: $baseUrl');
    print('   Test URL: ${testUrls.first}');
  }
}