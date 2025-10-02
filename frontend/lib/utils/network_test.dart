import 'dart:io';
import 'package:ipay/config/network_config.dart';
import 'package:ipay/services/network_service.dart';

class NetworkTest {
  static Future<void> runNetworkTest() async {
    print('🧪 Starting Network Connectivity Test...\n');
    
    // Test 1: Check all endpoints
    print('1️⃣ Testing all available endpoints:');
    await _testAllEndpoints();
    
    // Test 2: Test NetworkService initialization
    print('\n2️⃣ Testing NetworkService initialization:');
    await _testNetworkService();
    
    // Test 3: Print debug information
    print('\n3️⃣ Debug Information:');
    NetworkConfig.printDebugInfo();
    
    print('\n✅ Network test completed!');
  }
  
  static Future<Map<String, bool>> _testAllEndpoints() async {
    final results = <String, bool>{};
    
    // Test test endpoints first
    print('   Testing test endpoints:');
    for (String url in NetworkConfig.testUrls) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        
        final uri = Uri.parse(url);
        final request = await client.getUrl(uri);
        final response = await request.close();
        
        final isWorking = response.statusCode == 200;
        results[url] = isWorking;
        
        print('   ${isWorking ? '✅' : '❌'} $url (${response.statusCode})');
        client.close();
      } catch (e) {
        results[url] = false;
        print('   ❌ $url (Error: ${e.toString().split('\n').first})');
      }
    }
    
    // Test base endpoints
    print('   Testing base endpoints:');
    for (String url in NetworkConfig.allUrls) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        
        final uri = Uri.parse(url);
        final request = await client.getUrl(uri);
        final response = await request.close();
        
        final isWorking = response.statusCode == 200 || response.statusCode == 404;
        results[url] = isWorking;
        
        print('   ${isWorking ? '✅' : '❌'} $url (${response.statusCode})');
        client.close();
      } catch (e) {
        results[url] = false;
        print('   ❌ $url (Error: ${e.toString().split('\n').first})');
      }
    }
    
    return results;
  }
  
  static Future<void> _testNetworkService() async {
    try {
      final networkService = NetworkService();
      await networkService.initialize();
      
      print('   ✅ NetworkService initialized successfully');
      print('   🔗 Working URL: ${networkService.workingBaseUrl}');
      
      // Test the service
      final testResults = await networkService.testAllEndpoints();
      print('   📊 Endpoint test results:');
      testResults.forEach((url, isWorking) {
        print('      ${isWorking ? '✅' : '❌'} $url');
      });
      
    } catch (e) {
      print('   ❌ NetworkService initialization failed: $e');
    }
  }
}
