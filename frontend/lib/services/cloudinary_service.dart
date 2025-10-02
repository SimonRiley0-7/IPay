import 'dart:io';
import 'package:dio/dio.dart';
import 'package:ipay/config/api_config.dart';
import 'package:ipay/services/auth_service.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal() {
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

  /// Upload profile picture to Cloudinary via backend
  Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
    try {
      print('📤 Uploading profile picture to Cloudinary...');
      
      // Create FormData for file upload
      final formData = FormData.fromMap({
        'profilePicture': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'profile_picture_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });
      
      final response = await _dio.post(
        '/profile-picture',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final cloudinaryUrl = response.data['data']['cloudinaryUrl'] ?? 
                             response.data['data']['user']['profilePicture'];
        
        print('✅ Profile picture uploaded successfully: $cloudinaryUrl');
        
        return {
          'success': true,
          'profilePicture': cloudinaryUrl,
          'message': response.data['message'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to upload profile picture',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio error uploading profile picture: ${e.response?.data ?? e.message}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    } catch (e) {
      print('❌ Error uploading profile picture: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  /// Remove profile picture from Cloudinary via backend
  Future<Map<String, dynamic>> removeProfilePicture() async {
    try {
      print('🗑️ Removing profile picture from Cloudinary...');
      
      final response = await _dio.post(
        '/profile-picture',
        data: {
          'profilePicture': null,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('✅ Profile picture removed successfully');
        
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
      print('❌ Dio error removing profile picture: ${e.response?.data ?? e.message}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    } catch (e) {
      print('❌ Error removing profile picture: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  /// Get optimized image URL with transformations
  static String getOptimizedImageUrl(String cloudinaryUrl, {
    int? width,
    int? height,
    String crop = 'fill',
    String quality = 'auto:good',
  }) {
    if (!cloudinaryUrl.contains('cloudinary.com')) {
      return cloudinaryUrl;
    }

    try {
      final uri = Uri.parse(cloudinaryUrl);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length < 3) return cloudinaryUrl;
      
      // Find the index of 'upload' in the path
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex >= pathSegments.length - 1) {
        return cloudinaryUrl;
      }
      
      final cloudName = pathSegments[0];
      // Get everything after 'upload' as the image path
      final imagePath = pathSegments.sublist(uploadIndex + 1).join('/');
      
      String transformations = '';
      if (width != null || height != null) {
        transformations += 'w_${width ?? 'auto'},h_${height ?? 'auto'},c_$crop,q_$quality/';
      } else {
        transformations += 'q_$quality/';
      }
      
      final optimizedUrl = 'https://res.cloudinary.com/$cloudName/image/upload/$transformations$imagePath';
      print('🔗 Original URL: $cloudinaryUrl');
      print('🔗 Optimized URL: $optimizedUrl');
      return optimizedUrl;
    } catch (e) {
      print('❌ Error parsing Cloudinary URL: $e');
      return cloudinaryUrl; // Return original URL if parsing fails
    }
  }

  /// Get thumbnail URL (small version)
  static String getThumbnailUrl(String cloudinaryUrl) {
    return getOptimizedImageUrl(cloudinaryUrl, width: 100, height: 100);
  }

  /// Get medium size URL
  static String getMediumUrl(String cloudinaryUrl) {
    return getOptimizedImageUrl(cloudinaryUrl, width: 400, height: 400);
  }

  /// Get large size URL
  static String getLargeUrl(String cloudinaryUrl) {
    return getOptimizedImageUrl(cloudinaryUrl, width: 800, height: 800);
  }
}
