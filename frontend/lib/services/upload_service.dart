import 'dart:io';
import 'package:dio/dio.dart';
import 'package:ipay/config/api_config.dart';
import 'package:ipay/services/auth_service.dart';

class UploadService {
  static final UploadService _instance = UploadService._internal();
  factory UploadService() => _instance;
  UploadService._internal() {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Add auth interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _authService.getStoredToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  final Dio _dio = Dio();
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
    try {
      // For now, we'll just use the file path as a local URL
      // In a real app, you would upload to a cloud service like AWS S3, Cloudinary, etc.
      final localUrl = imageFile.path;
      
      final response = await _dio.post(
        '/profile-picture',
        data: {
          'profilePicture': localUrl,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'profilePicture': response.data['data']['user']['profilePicture'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to update profile picture',
        };
      }
    } on DioException catch (e) {
      print('Dio error updating profile picture: ${e.response?.data ?? e.message}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    } catch (e) {
      print('Error updating profile picture: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> removeProfilePicture() async {
    try {
      final response = await _dio.post(
        '/profile-picture',
        data: {
          'profilePicture': null,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'message': response.data['message'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to remove profile picture',
        };
      }
    } on DioException catch (e) {
      print('Dio error removing profile picture: ${e.response?.data ?? e.message}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    } catch (e) {
      print('Error removing profile picture: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }
}
