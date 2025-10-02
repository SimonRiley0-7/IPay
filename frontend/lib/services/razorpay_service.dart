import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:ipay/services/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:ipay/config/api_config.dart';

class RazorpayService {
  static final RazorpayService _instance = RazorpayService._internal();
  factory RazorpayService() => _instance;
  RazorpayService._internal();

  late Razorpay _razorpay;
  final AuthService _authService = AuthService();
  final Dio _dio = Dio();
  
  // Razorpay configuration
  String? _keyId;
  String? _environment;
  
  Function(PaymentSuccessResponse)? onPaymentSuccess;
  Function(PaymentFailureResponse)? onPaymentError;
  // Function(PaymentExternalWalletResponse)? onExternalWalletSelected;

  Future<void> initialize() async {
    // Initialize Razorpay first
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    // _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWalletSelected);
    
    // Then fetch Razorpay configuration from backend
    await _fetchRazorpayConfig();
  }

  Future<void> _fetchRazorpayConfig() async {
    try {
      final response = await _dio.get('${ApiConfig.baseUrl}/razorpay-config');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final config = response.data['data'];
        _keyId = config['keyId'];
        _environment = config['environment'];
        print('✅ Razorpay config loaded: $_keyId ($_environment)');
      } else {
        throw Exception('Failed to load Razorpay configuration');
      }
    } catch (e) {
      print('❌ Error loading Razorpay config: $e');
      // Fallback to hardcoded test key if API fails
      _keyId = 'rzp_test_RN97mtLatfD4LW'; // Your actual test key from .env
      _environment = 'test';
      print('⚠️ Using fallback Razorpay key: $_keyId');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('Payment Success: ${response.paymentId}');
    if (onPaymentSuccess != null) {
      onPaymentSuccess!(response);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('Payment Error: ${response.code} - ${response.message}');
    if (onPaymentError != null) {
      onPaymentError!(response);
    }
  }

  // void _handleExternalWalletSelected(PaymentExternalWalletResponse response) {
  //   print('External Wallet Selected: ${response.walletName}');
  //   if (onExternalWalletSelected != null) {
  //     onExternalWalletSelected!(response);
  //   }
  // }

  Future<void> openPaymentGateway({
    required double amount,
    required String description,
    required String userEmail,
    required String userName,
    required String userPhone,
  }) async {
    try {
      // Ensure Razorpay config is loaded
      if (_keyId == null) {
        await _fetchRazorpayConfig();
      }
      
      if (_keyId == null || _keyId!.isEmpty) {
        throw Exception('Razorpay configuration not available');
      }

      // Validate amount
      if (amount <= 0) {
        throw Exception('Invalid amount: $amount');
      }

      // Get user data for payment
      final userData = await _authService.getStoredUserData();
      final email = userData?['email'] ?? userEmail;
      final name = userData?['name'] ?? userName;
      final phone = userData?['phone'] ?? userPhone;

      // Convert amount to paise (Razorpay expects amount in smallest currency unit)
      final amountInPaise = (amount * 100).toInt();

      // Validate amount in paise
      if (amountInPaise < 100) { // Minimum ₹1
        throw Exception('Minimum amount is ₹1');
      }

      var options = {
        'key': _keyId,
        'amount': amountInPaise,
        'name': 'iPay Wallet',
        'description': description,
        'prefill': {
          'contact': phone,
          'email': email,
          'name': name,
        },
        'theme': {
          'color': '#4A9B8E', // Your app's primary color
        },
        'notes': {
          'environment': _environment ?? 'test',
          'source': 'mobile_app',
        }
      };

      print('🚀 Opening Razorpay gateway with key: $_keyId');
      print('💰 Amount: ₹$amount (${amountInPaise} paise)');
      print('👤 User: $name ($email)');
      
      _razorpay.open(options);
    } catch (e) {
      print('❌ Error opening payment gateway: $e');
      if (onPaymentError != null) {
        onPaymentError!(PaymentFailureResponse(
          0,
          'Failed to open payment gateway: $e',
          {'source': 'flutter'},
        ));
      }
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}

// Payment result models
class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? errorMessage;
  final double amount;
  final String description;

  PaymentResult({
    required this.success,
    this.paymentId,
    this.orderId,
    this.signature,
    this.errorMessage,
    required this.amount,
    required this.description,
  });
}

// Wallet transaction model for Razorpay payments
class WalletTransaction {
  final String id;
  final String type; // 'credit', 'debit', 'refund'
  final double amount;
  final String description;
  final DateTime timestamp;
  final String status; // 'completed', 'pending', 'failed'
  final String? referenceId;
  final String? paymentMethod;
  final String? razorpayPaymentId;
  final String? razorpayOrderId;
  final String? razorpaySignature;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    required this.status,
    this.referenceId,
    this.paymentMethod,
    this.razorpayPaymentId,
    this.razorpayOrderId,
    this.razorpaySignature,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'referenceId': referenceId,
      'paymentMethod': paymentMethod,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpayOrderId': razorpayOrderId,
      'razorpaySignature': razorpaySignature,
    };
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] ?? json['_id'] ?? '',
      type: json['type'] ?? 'credit',
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'completed',
      referenceId: json['referenceId'],
      paymentMethod: json['paymentMethod'],
      razorpayPaymentId: json['razorpayPaymentId'],
      razorpayOrderId: json['razorpayOrderId'],
      razorpaySignature: json['razorpaySignature'],
    );
  }
}
