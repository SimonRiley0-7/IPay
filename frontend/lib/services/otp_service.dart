import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:ipay/config/api_config.dart';

class OTPService {
  static final OTPService _instance = OTPService._internal();
  factory OTPService() => _instance;
  OTPService._internal();

  final Dio _dio = Dio();

  // Initialize Dio with base configuration
  void _initializeDio() {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    _dio.options.connectTimeout = ApiConfig.connectTimeout;
    _dio.options.receiveTimeout = ApiConfig.timeout;
    _dio.options.headers = ApiConfig.headers;
  }

  // Send OTP to mobile number
  Future<Map<String, dynamic>> sendOTP(String mobileNumber) async {
    try {
      _initializeDio();
      
      print('📱 Sending OTP to: $mobileNumber');
      
      final response = await _dio.post('/otp/send', data: {
        'mobileNumber': mobileNumber,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ OTP sent successfully');
        return {
          'success': true,
          'message': response.data['message'],
          'verificationId': response.data['data']['verificationId'],
          'mobileNumber': response.data['data']['mobileNumber'],
        };
      } else {
        print('❌ OTP send failed: ${response.data}');
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to send OTP',
          'error': response.data['error'],
        };
      }
    } on DioException catch (e) {
      print('❌ OTP send error: ${e.message}');
      return {
        'success': false,
        'message': _handleDioError(e),
        'error': e.message,
      };
    } catch (e) {
      print('❌ Unexpected error sending OTP: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
        'error': e.toString(),
      };
    }
  }

  // Verify OTP
  Future<Map<String, dynamic>> verifyOTP({
    required String verificationId,
    required String otp,
    required String mobileNumber,
  }) async {
    try {
      _initializeDio();
      
      print('🔍 Verifying OTP for mobile: $mobileNumber');
      
      final response = await _dio.post('/otp/verify', data: {
        'verificationId': verificationId,
        'otp': otp,
        'mobileNumber': mobileNumber,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ OTP verified successfully');
        return {
          'success': true,
          'message': response.data['message'],
          'user': response.data['data']['user'],
          'token': response.data['data']['token'],
          'isNewUser': response.data['data']['isNewUser'] ?? false,
        };
      } else {
        print('❌ OTP verification failed: ${response.data}');
        return {
          'success': false,
          'message': response.data['message'] ?? 'Invalid OTP',
          'error': response.data['error'],
        };
      }
    } on DioException catch (e) {
      print('❌ OTP verification error: ${e.message}');
      return {
        'success': false,
        'message': _handleDioError(e),
        'error': e.message,
      };
    } catch (e) {
      print('❌ Unexpected error verifying OTP: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
        'error': e.toString(),
      };
    }
  }

  // Resend OTP
  Future<Map<String, dynamic>> resendOTP(String mobileNumber) async {
    try {
      _initializeDio();
      
      print('🔄 Resending OTP to: $mobileNumber');
      
      final response = await _dio.post('/otp/resend', data: {
        'mobileNumber': mobileNumber,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ OTP resent successfully');
        return {
          'success': true,
          'message': response.data['message'],
          'verificationId': response.data['data']['verificationId'],
          'mobileNumber': response.data['data']['mobileNumber'],
        };
      } else {
        print('❌ OTP resend failed: ${response.data}');
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to resend OTP',
          'error': response.data['error'],
        };
      }
    } on DioException catch (e) {
      print('❌ OTP resend error: ${e.message}');
      return {
        'success': false,
        'message': _handleDioError(e),
        'error': e.message,
      };
    } catch (e) {
      print('❌ Unexpected error resending OTP: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
        'error': e.toString(),
      };
    }
  }

  // Test MessageCentral connection
  Future<Map<String, dynamic>> testConnection() async {
    try {
      _initializeDio();
      
      print('🧪 Testing MessageCentral connection...');
      
      final response = await _dio.get('/otp/test');

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ MessageCentral connection successful');
        return {
          'success': true,
          'message': response.data['message'],
          'data': response.data['data'],
        };
      } else {
        print('❌ MessageCentral connection failed: ${response.data}');
        return {
          'success': false,
          'message': response.data['message'] ?? 'MessageCentral connection failed',
          'error': response.data['error'],
        };
      }
    } on DioException catch (e) {
      print('❌ MessageCentral test error: ${e.message}');
      return {
        'success': false,
        'message': _handleDioError(e),
        'error': e.message,
      };
    } catch (e) {
      print('❌ Unexpected error testing MessageCentral: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred while testing connection.',
        'error': e.toString(),
      };
    }
  }

  // Handle Dio errors
  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 400) {
          return 'Invalid request. Please check your input.';
        } else if (e.response?.statusCode == 401) {
          return 'Unauthorized. Please try again.';
        } else if (e.response?.statusCode == 429) {
          return 'Too many requests. Please wait a moment and try again.';
        } else if (e.response?.statusCode == 500) {
          return 'Server error. Please try again later.';
        } else {
          return 'Request failed. Please try again.';
        }
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      case DioExceptionType.badCertificate:
        return 'Security error. Please try again.';
      case DioExceptionType.unknown:
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}
