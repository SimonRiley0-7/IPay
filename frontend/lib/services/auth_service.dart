import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ipay/config/api_config.dart';
import 'package:ipay/config/network_config.dart';
import 'package:ipay/services/network_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  
  // Google Sign-In v7 API - Use singleton instance
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;
  GoogleSignInAccount? _currentUser; // Manual state management required in v7
  
  final NetworkService _networkService = NetworkService();
  Dio? _dio;

  // Initialize the service
  Future<void> initializeNetwork() async {
    await _networkService.initialize();
    _dio = _networkService.dio;
    
    // Debug: Print current configuration
    print('🔧 AuthService initialized with base URL: ${_dio?.options.baseUrl}');
  }

  // Get Dio instance with automatic initialization
  Dio get dio {
    if (_dio == null) {
      throw Exception('AuthService not initialized. Call initialize() first.');
    }
    return _dio!;
  }

  // Current user stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;
  
  // Google Sign-In current user (manually managed in v7)
  GoogleSignInAccount? get currentGoogleUser => _currentUser;

  // Initialize method - REQUIRED in v7
  Future<void> initialize() async {
    await _initializeGoogleSignIn();
    _initializeDio();
  }
  
  // Test backend connection (useful for mobile debugging)
  Future<bool> testConnection() async {
    NetworkConfig.printDebugInfo();
    print('🔄 Testing connection to backend...');
    
    // Try all available test URLs (which include /test endpoint)
    final urlsToTry = NetworkConfig.testUrls;
    
    for (String url in urlsToTry) {
      try {
        print('🌐 Trying: $url');
        final response = await dio.get(url, options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ));
        
        if (response.statusCode == 200) {
          print('✅ Connection successful! Status: ${response.statusCode}');
          print('📦 Response: ${response.data}');
          print('🎯 Working URL: $url');
          
          // Update the base URL to the working one
          if (url != ApiConfig.baseUrl) {
            print('🔄 Updating base URL to working URL...');
            // Update base URL for the working endpoint
            // Note: This will be handled by NetworkService now
          }
          
          return true;
        }
      } catch (e) {
        print('❌ Failed to connect to $url: $e');
        continue;
      }
    }
    
    print('❌ All connection attempts failed!');
    print('🔧 Make sure:');
    print('   1. Backend server is running on port 3000');
    print('   2. Mobile device/emulator is properly configured');
    print('   3. Firewall allows port 3000');
    print('   4. Try running: npm run dev in the backend directory');
    return false;
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize();
      _isGoogleSignInInitialized = true;
      print('Google Sign-In initialized successfully');
    } catch (e) {
      print('Failed to initialize Google Sign-In: $e');
      _isGoogleSignInInitialized = false;
    }
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await _initializeGoogleSignIn();
    }
  }

  // Initialize Dio with interceptors
  void _initializeDio() {
    // Network configuration is now handled by NetworkService
    // This method is kept for backward compatibility but does nothing

  // Add token interceptor with automatic refresh
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await getStoredToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        print('🔑 Using token: ${token.substring(0, 20)}...');
      } else {
        print('❌ No token found for request to: ${options.path}');
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      print('API Error: ${error.message}');
      print('Status Code: ${error.response?.statusCode}');
      print('Request URL: ${error.requestOptions.uri}');
      
      // Handle 401 Unauthorized - try to refresh token
      if (error.response?.statusCode == 401) {
        print('🔄 401 Unauthorized - attempting token refresh...');
        
        try {
          final refreshResult = await _refreshToken();
          if (refreshResult) {
            print('✅ Token refreshed successfully, retrying request...');
            
            // Retry the original request with new token
            final newToken = await getStoredToken();
            if (newToken != null) {
              print('🔑 Using new token: ${newToken.substring(0, 20)}...');
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              
              // Retry the request
              final response = await dio.fetch(error.requestOptions);
              handler.resolve(response);
              return;
            } else {
              print('❌ No new token available after refresh');
            }
          } else {
            print('❌ Token refresh failed');
          }
        } catch (e) {
          print('❌ Token refresh error: $e');
          // If refresh fails, clear stored data and redirect to login
          await clearAllStoredData();
        }
      }
      
      handler.next(error);
    },
  ));
  }

  // Store JWT token with 30-day expiration
  Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final expirationDate = now.add(const Duration(days: 30));
    
    await prefs.setString('jwt_token', token);
    await prefs.setString('token_expiration', expirationDate.toIso8601String());
  }

  // Get stored JWT token (check if still valid)
  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final expirationString = prefs.getString('token_expiration');
    
    if (token == null || expirationString == null) {
      return null;
    }
    
    try {
      final expirationDate = DateTime.parse(expirationString);
      final now = DateTime.now();
      
      // If token is expired, try to refresh it instead of clearing
      if (now.isAfter(expirationDate)) {
        print('🔄 Token expired, attempting refresh...');
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Get the new token
          final newToken = prefs.getString('jwt_token');
          print('✅ Token refreshed successfully');
          return newToken;
        } else {
          // If refresh fails, then clear the token
          print('❌ Token refresh failed, clearing stored data');
          await clearStoredToken();
          return null;
        }
      }
      
      return token;
    } catch (e) {
      print('❌ Error checking token validity: $e');
      // If parsing fails, clear the token
      await clearStoredToken();
      return null;
    }
  }

  // Clear stored token
  Future<void> clearStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('token_expiration');
  }

  // Store user data
  Future<void> storeUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(userData));
  }

  // Get stored user data
  Future<Map<String, dynamic>?> getStoredUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }

  // Clear all stored data
  Future<void> clearAllStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('token_expiration');
    await prefs.remove('user_data');
  }

  // Refresh JWT token (private method for interceptor)
  Future<bool> _refreshToken() async {
    try {
      print('🔄 Refreshing JWT token...');
      
      // Get the current token to send for refresh
      final prefs = await SharedPreferences.getInstance();
      final currentToken = prefs.getString('jwt_token');
      
      if (currentToken == null) {
        print('❌ No token found for refresh');
        return false;
      }
      
      // Create a new dio instance for refresh to avoid interceptor loops
      final refreshDio = Dio();
      refreshDio.options.baseUrl = ApiConfig.baseUrl;
      refreshDio.options.connectTimeout = const Duration(seconds: 10);
      refreshDio.options.receiveTimeout = const Duration(seconds: 10);
      
      final response = await refreshDio.post(
        '/refresh',
        options: Options(
          headers: {
            'Authorization': 'Bearer $currentToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final newToken = response.data['data']['token'];
        await storeToken(newToken);
        print('✅ Token refreshed successfully');
        return true;
      } else {
        print('❌ Token refresh failed: ${response.data}');
        return false;
      }
    } catch (e) {
      print('❌ Token refresh error: $e');
      
      // If refresh fails with 401, the token is completely invalid
      if (e is DioException && e.response?.statusCode == 401) {
        print('🚨 Token is completely invalid, clearing stored data...');
        await clearAllStoredData();
      }
      
      return false;
    }
  }

  // Public method to refresh token
  Future<bool> refreshToken() async {
    return await _refreshToken();
  }

  // Google Sign-In v7 implementation
  Future<AuthResult> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();
      
      // Sign out first to ensure clean state
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      _currentUser = null;
      
      // Check if authenticate method is supported
      if (!_googleSignIn.supportsAuthenticate()) {
        return AuthResult(
          success: false,
          message: 'Google Sign-In authentication is not supported on this platform',
        );
      }
      
      // Authenticate with Google using v7 API
      GoogleSignInAccount googleUser;
      try {
        googleUser = await _googleSignIn.authenticate(
          scopeHint: ['email', 'profile'],
        );
        _currentUser = googleUser; // Update manual state management
      } on GoogleSignInException catch (e) {
        print('Google Sign-In Exception: ${e.code.name} - ${e.description}');
        return AuthResult(
          success: false,
          message: _getGoogleSignInErrorMessage(e),
        );
      } catch (e) {
        print('Google Sign-In Error: $e');
        return AuthResult(
          success: false,
          message: 'Google sign-in failed. Please try again.',
        );
      }

      // Get authentication details - now synchronous in v7
      GoogleSignInAuthentication googleAuth;
      try {
        googleAuth = googleUser.authentication; // No await needed in v7
      } catch (e) {
        print('Google Auth Error: $e');
        return AuthResult(
          success: false,
          message: 'Failed to get Google authentication details',
        );
      }

      if (googleAuth.idToken == null) {
        return AuthResult(
          success: false,
          message: 'Failed to get Google ID token',
        );
      }

      // In v7, we need to get access token through authorization client if needed
      // For Firebase Auth, idToken is usually sufficient, but we'll try to get accessToken
      String? accessToken;
      try {
        final authClient = _googleSignIn.authorizationClient;
        final authorization = await authClient.authorizationForScopes(['email', 'profile']);
        accessToken = authorization?.accessToken;
      } catch (e) {
        print('Failed to get access token: $e');
        // accessToken is optional for Firebase, continue with null
        accessToken = null;
      }

      // Create Firebase credential
      // Note: In v7, accessToken comes from authorization client, not GoogleSignInAuthentication
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken, // From authorization client or null
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with better error handling
      UserCredential? userCredential;
      try {
        userCredential = await _firebaseAuth.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        print('Firebase Auth Exception: ${e.code} - ${e.message}');
        String errorMessage = _getFirebaseAuthErrorMessage(e.code);
        return AuthResult(
          success: false,
          message: errorMessage,
        );
      } catch (e) {
        print('Firebase Auth Error: $e');
        return AuthResult(
          success: false,
          message: 'Firebase authentication failed: ${e.toString()}',
        );
      }

      if (userCredential.user == null) {
        return AuthResult(
          success: false,
          message: 'Failed to authenticate with Firebase',
        );
      }

      // Get Firebase ID token
      String? firebaseIdToken;
      try {
        firebaseIdToken = await userCredential.user!.getIdToken();
      } catch (e) {
        print('Firebase ID Token Error: $e');
        return AuthResult(
          success: false,
          message: 'Failed to get Firebase ID token',
        );
      }
        
      if (firebaseIdToken == null) {
        return AuthResult(
          success: false,
          message: 'Failed to get Firebase ID token',
        );
      }

      // Send to backend for verification and user creation/login
      try {
        print('📡 Sending Firebase ID token to backend...');
        print('🌐 Backend URL: ${ApiConfig.baseUrl}/google');
        
        final response = await dio.post('/google', 
          data: {
            'idToken': firebaseIdToken,
          },
          options: Options(
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
          ),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.data['data'];
          print('✅ Google authentication successful. Response: ${response.data}');
          
          // Store JWT token and user data
          await storeToken(data['token']);
          await storeUserData(data['user']);

          return AuthResult(
            success: true,
            message: response.data['message'],
            user: data['user'],
            token: data['token'],
            isNewUser: data['isNewUser'] ?? false,
            showPhonePrompt: data['showPhonePrompt'] ?? false,
          );
        } else {
          print('❌ Google authentication failed. Status: ${response.statusCode}, Response: ${response.data}');
          return AuthResult(
            success: false,
            message: response.data['message'] ?? 'Authentication failed',
          );
        }
      } on DioException catch (e) {
        print('Backend API Error: ${e.response?.data}');
        String errorMessage = 'Backend authentication failed';
        
        if (e.response?.data != null && e.response!.data is Map) {
          errorMessage = e.response!.data['message'] ?? errorMessage;
        }
        
        return AuthResult(
          success: false,
          message: errorMessage,
        );
      } catch (e) {
        print('Backend Error: $e');
        return AuthResult(
          success: false,
          message: 'Backend authentication failed: ${e.toString()}',
        );
      }

    } catch (e) {
      print('Unexpected Google Sign-In Error: $e');
      
      // Clean up on any error
      try {
        await _googleSignIn.signOut();
        await _firebaseAuth.signOut();
        _currentUser = null;
      } catch (signOutError) {
        print('Sign out cleanup error: $signOutError');
      }
      
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred during sign-in. Please try again.',
      );
    }
  }

  // Helper method to get user-friendly Google Sign-In error messages
  String _getGoogleSignInErrorMessage(GoogleSignInException e) {
    switch (e.code.name) {
      case 'canceled':
        return 'Sign-in was cancelled. Please try again if you want to continue.';
      case 'interrupted':
        return 'Sign-in was interrupted. Please try again.';
      case 'clientConfigurationError':
        return 'There is a configuration issue with Google Sign-In. Please contact support.';
      case 'providerConfigurationError':
        return 'Google Sign-In is currently unavailable. Please try again later.';
      case 'uiUnavailable':
        return 'Google Sign-In is currently unavailable. Please try again later.';
      case 'userMismatch':
        return 'There was an issue with your account. Please sign out and try again.';
      case 'unknownError':
      default:
        return 'An unexpected error occurred during Google Sign-In. Please try again.';
    }
  }

  // Helper method to get user-friendly Firebase Auth error messages
  String _getFirebaseAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method';
      case 'invalid-credential':
        return 'The credential received is malformed or has expired';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled for this project';
      case 'user-disabled':
        return 'This user account has been disabled';
      case 'user-not-found':
        return 'No user found for this email';
      case 'wrong-password':
        return 'Wrong password provided';
      case 'too-many-requests':
        return 'Too many requests. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication failed. Please try again';
    }
  }

  // Attempt silent/lightweight authentication
  Future<GoogleSignInAccount?> attemptSilentSignIn() async {
    await _ensureGoogleSignInInitialized();
    
    try {
      final result = _googleSignIn.attemptLightweightAuthentication();
      // Handle both sync and async returns
      if (result is Future<GoogleSignInAccount?>) {
        final account = await result;
        _currentUser = account;
        return account;
      } else {
        final account = result as GoogleSignInAccount?;
        _currentUser = account;
        return account;
      }
    } catch (error) {
      print('Silent sign-in failed: $error');
      return null;
    }
  }

  // Phone Authentication - Send OTP via Twilio Backend
  Future<AuthResult> sendPhoneOTP(String phoneNumber) async {
    try {
      print('📱 Sending OTP to: $phoneNumber via Twilio backend');
      
      final response = await dio.post('/send-otp', data: {
        'phoneNumber': phoneNumber,
      });

      if (response.statusCode == 200) {
        print('✅ OTP sent successfully. Response: ${response.data}');
        return AuthResult(
          success: true,
          message: response.data['message'] ?? 'OTP sent successfully',
          verificationId: response.data['verificationId'],
        );
      } else {
        print('❌ OTP send failed. Status: ${response.statusCode}, Response: ${response.data}');
        return AuthResult(
          success: false,
          message: response.data['message'] ?? 'Failed to send OTP',
        );
      }

    } catch (e) {
      print('Send OTP Error: $e');
      
      // Handle DioException
      if (e is DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          return AuthResult(
            success: false,
            message: e.response!.data['message'],
          );
        }
      }
      
      return AuthResult(
        success: false,
        message: 'Failed to send OTP: ${e.toString()}',
      );
    }
  }

  // Phone Authentication - Verify OTP via Twilio Backend
  Future<AuthResult> verifyPhoneOTP(String verificationId, String otp, String phoneNumber) async {
    try {
      print('🔍 Verifying OTP: $otp for phone: $phoneNumber via Twilio backend');
      
      final response = await dio.post('/verify-otp', data: {
        'verificationId': verificationId,
        'otp': otp,
        'phoneNumber': phoneNumber,
      });

      print('📡 Backend response status: ${response.statusCode}');
      print('📡 Backend response data: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data['data'];
        
        if (data['isNewUser'] == true) {
          // New user - requires registration
          print('🆕 New user detected - requiresRegistration = true');
          return AuthResult(
            success: true,
            message: response.data['message'],
            requiresRegistration: true,
            phoneNumber: phoneNumber,
            firebaseUid: 'twilio_verified',
          );
        } else {
          // Existing user - login successful
          print('👤 Existing user login - storing token and user data');
          await storeToken(data['token']);
          await storeUserData(data['user']);

          return AuthResult(
            success: true,
            message: response.data['message'],
            user: data['user'],
            token: data['token'],
            isNewUser: false,
          );
        }
      } else {
        return AuthResult(
          success: false,
          message: response.data['message'] ?? 'Phone verification failed',
        );
      }

    } catch (e) {
      print('Verify OTP Error: $e');
      return AuthResult(
        success: false,
        message: 'OTP verification failed: ${e.toString()}',
      );
    }
  }

  // Complete Phone Registration
  Future<AuthResult> completePhoneRegistration({
    required String name,
    required String phone,
    String? referralCode,
  }) async {
    try {
      print('📝 Completing phone registration for: $phone');
      
      // Create a separate Dio instance for registration calls
      final regDio = Dio();
      regDio.options.baseUrl = ApiConfig.baseUrl.replaceAll('/api/auth', '');
      regDio.options.connectTimeout = ApiConfig.connectTimeout;
      regDio.options.receiveTimeout = ApiConfig.timeout;
      regDio.options.headers = ApiConfig.headers;
      
      final response = await regDio.post('/api/auth/register', data: {
        'step': 3,
        'phoneNumber': phone,
        'name': name,
        'referralCode': referralCode,
      });

      print('📡 Registration response: ${response.data}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        await storeToken(response.data['token']);
        await storeUserData(response.data['user']);

        return AuthResult(
          success: true,
          message: 'Registration completed successfully',
          user: response.data['user'],
          token: response.data['token'],
          isNewUser: true,
        );
      } else {
        return AuthResult(
          success: false,
          message: response.data['message'] ?? 'Registration failed',
        );
      }
    } catch (e) {
      print('Complete registration error: $e');
      
      // Handle DioException
      if (e is DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          return AuthResult(
            success: false,
            message: e.response!.data['message'],
          );
        }
      }
      
      return AuthResult(
        success: false,
        message: 'Registration failed: ${e.toString()}',
      );
    }
  }

  // Add phone to Google user (via MessageCentral OTP verification)
  Future<AuthResult> addPhoneToGoogleUser(String phoneNumber, String otp) async {
    try {
      // First verify OTP with MessageCentral
      final otpVerification = await verifyPhoneOTP('', otp, phoneNumber);
      
      if (!otpVerification.success) {
        return otpVerification; // Return OTP verification error
      }

      // Get current user token
      final token = await getStoredToken();
      if (token == null) {
        return AuthResult(
          success: false,
          message: 'User not authenticated',
        );
      }

      final response = await dio.post('/google/add-phone', 
        data: {
          'phone': phoneNumber,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        await storeUserData(data['user']);

        return AuthResult(
          success: true,
          message: response.data['message'],
          user: data['user'],
        );
      } else {
        return AuthResult(
          success: false,
          message: response.data['message'] ?? 'Failed to add phone number',
        );
      }

    } catch (e) {
      print('Add Phone Error: $e');
      return AuthResult(
        success: false,
        message: 'Failed to add phone: ${e.toString()}',
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
      _currentUser = null; // Clear manual state
      await clearAllStoredData();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getStoredToken();
    final userData = await getStoredUserData();
    return token != null && userData != null;
  }

  // Get current user profile
  Future<AuthResult> getCurrentUserProfile() async {
    try {
      final response = await dio.get('/me');
      
      if (response.statusCode == 200) {
        final data = response.data['data'];
        await storeUserData(data['user']);
        
        return AuthResult(
          success: true,
          message: 'Profile retrieved successfully',
          user: data['user'],
        );
      } else {
        return AuthResult(
          success: false,
          message: response.data['message'] ?? 'Failed to get profile',
        );
      }
    } catch (e) {
      print('Get Profile Error: $e');
      return AuthResult(
        success: false,
        message: 'Failed to get profile: ${e.toString()}',
      );
    }
  }

  // Update user profile
  Future<AuthResult> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? address,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      
      if (name != null) updateData['name'] = name;
      if (email != null) updateData['email'] = email;
      if (phone != null) updateData['phone'] = phone;
      if (address != null) updateData['address'] = address;
      
      print('📝 Updating profile with data: $updateData');
      
      final response = await dio.put('/profile', data: updateData);
      
      if (response.statusCode == 200) {
        final data = response.data['data'];
        await storeUserData(data['user']);
        
        return AuthResult(
          success: true,
          message: response.data['message'] ?? 'Profile updated successfully',
          user: data['user'],
        );
      } else {
        return AuthResult(
          success: false,
          message: response.data['message'] ?? 'Failed to update profile',
        );
      }
    } catch (e) {
      print('Update Profile Error: $e');
      return AuthResult(
        success: false,
        message: 'Failed to update profile: ${e.toString()}',
      );
    }
  }

  // Send email verification
  Future<AuthResult> sendEmailVerification() async {
    try {
      print('📧 Sending email verification...');
      
      final response = await dio.post('/verify-email');
      
      if (response.statusCode == 200) {
        return AuthResult(
          success: true,
          message: response.data['message'] ?? 'Verification email sent successfully',
        );
      } else {
        return AuthResult(
          success: false,
          message: response.data['message'] ?? 'Failed to send verification email',
        );
      }
    } catch (e) {
      print('Email Verification Error: $e');
      return AuthResult(
        success: false,
        message: 'Failed to send verification email: ${e.toString()}',
      );
    }
  }

  // Send phone verification OTP
  Future<AuthResult> sendPhoneVerification() async {
    try {
      print('📱 Sending phone verification OTP...');
      
      final response = await dio.post('/verify-phone');
      
      if (response.statusCode == 200) {
        return AuthResult(
          success: true,
          message: response.data['message'] ?? 'Verification OTP sent successfully',
        );
      } else {
        return AuthResult(
          success: false,
          message: response.data['message'] ?? 'Failed to send verification OTP',
        );
      }
    } catch (e) {
      print('Phone Verification Error: $e');
      return AuthResult(
        success: false,
        message: 'Failed to send verification OTP: ${e.toString()}',
      );
    }
  }
}

// Auth Result Model
class AuthResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? user;
  final String? token;
  final bool isNewUser;
  final bool showPhonePrompt;
  final bool requiresRegistration;
  final String? phoneNumber;
  final String? firebaseUid;
  final String? verificationId;

  AuthResult({
    required this.success,
    required this.message,
    this.user,
    this.token,
    this.isNewUser = false,
    this.showPhonePrompt = false,
    this.requiresRegistration = false,
    this.phoneNumber,
    this.firebaseUid,
    this.verificationId,
  });

  @override
  String toString() {
    return 'AuthResult{success: $success, message: $message, isNewUser: $isNewUser, requiresRegistration: $requiresRegistration, phoneNumber: $phoneNumber, user: ${user != null ? user!['name'] : 'null'}}';
  }
}