import 'dart:io';
import 'package:dio/dio.dart';
import 'package:ipay/config/api_config.dart';
import 'package:ipay/config/network_config.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  Dio? _dio;
  String? _workingBaseUrl;

  // Initialize the service with automatic endpoint detection
  Future<void> initialize() async {
    print('🔧 Initializing NetworkService...');
    
    // Find working endpoint
    _workingBaseUrl = await NetworkConfig.findWorkingEndpoint();
    
    if (_workingBaseUrl == null) {
      print('❌ No working endpoints found, using default');
      _workingBaseUrl = ApiConfig.baseUrl;
    } else {
      print('✅ Using working endpoint: $_workingBaseUrl');
    }
    
    // Configure Dio with the working endpoint
    _dio = Dio(BaseOptions(
      baseUrl: _workingBaseUrl!,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.timeout,
      headers: ApiConfig.headers,
    ));
    
    // Add retry interceptor
    _dio!.interceptors.add(RetryInterceptor(
      dio: _dio!,
      logPrint: print,
      retries: ApiConfig.maxRetries,
      retryDelays: const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 3),
      ],
    ));
    
    // Add error handling interceptor
    _dio!.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        print('🌐 Network Error: ${error.message}');
        print('🔗 URL: ${error.requestOptions.uri}');
        
        // If it's a connection error, try to find a new working endpoint
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.connectionError) {
          _handleConnectionError();
        }
        
        return handler.next(error);
      },
    ));
  }

  // Get the configured Dio instance
  Dio get dio {
    if (_dio == null) {
      throw Exception('NetworkService not initialized. Call initialize() first.');
    }
    return _dio!;
  }

  // Get the current working base URL
  String? get workingBaseUrl => _workingBaseUrl;

  // Handle connection errors by trying to find a new endpoint
  Future<void> _handleConnectionError() async {
    print('🔄 Connection error detected, trying to find new endpoint...');
    
    final newEndpoint = await NetworkConfig.findWorkingEndpoint();
    if (newEndpoint != null && newEndpoint != _workingBaseUrl) {
      print('✅ Found new working endpoint: $newEndpoint');
      _workingBaseUrl = newEndpoint;
      
      // Reconfigure Dio with new endpoint
      _dio = Dio(BaseOptions(
        baseUrl: _workingBaseUrl!,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.timeout,
        headers: ApiConfig.headers,
      ));
    }
  }

  // Test connectivity to all endpoints
  Future<Map<String, bool>> testAllEndpoints() async {
    final results = <String, bool>{};
    
    for (String url in NetworkConfig.allUrls) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        
        final uri = Uri.parse(url);
        final request = await client.getUrl(uri);
        final response = await request.close();
        
        results[url] = response.statusCode == 200 || response.statusCode == 404;
        client.close();
      } catch (e) {
        results[url] = false;
      }
    }
    
    return results;
  }

  // Print network status
  void printNetworkStatus() {
    print('🌐 Network Service Status:');
    print('🔗 Working Base URL: $_workingBaseUrl');
    print('📱 Platform: ${Platform.operatingSystem}');
    print('⏱️ Timeouts: Connect=${ApiConfig.connectTimeout.inSeconds}s, Receive=${ApiConfig.timeout.inSeconds}s');
  }
}

// Retry interceptor for automatic retries
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int retries;
  final List<Duration> retryDelays;
  final void Function(String message)? logPrint;

  RetryInterceptor({
    required this.dio,
    this.retries = 3,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 3),
    ],
    this.logPrint,
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
      
      if (retryCount < retries) {
        logPrint?.call('🔄 Retrying request (${retryCount + 1}/$retries): ${err.requestOptions.uri}');
        
        await Future.delayed(retryDelays[retryCount]);
        
        err.requestOptions.extra['retryCount'] = retryCount + 1;
        
        try {
          final response = await dio.fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          if (e is DioException) {
            return onError(e, handler);
          }
          return handler.reject(err);
        }
      }
    }
    
    return handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
           err.type == DioExceptionType.connectionError ||
           err.type == DioExceptionType.receiveTimeout;
  }
}


