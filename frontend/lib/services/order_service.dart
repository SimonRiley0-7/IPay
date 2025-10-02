import 'package:dio/dio.dart';
import 'package:ipay/config/api_config.dart';
import 'package:ipay/services/auth_service.dart';

class OrderService {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal() {
    _dio.options.baseUrl = '${ApiConfig.baseUrl.replaceAll('/auth', '')}/orders';
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

  /// Create a new order
  Future<Map<String, dynamic>> createOrder({
    required List<Map<String, dynamic>> products,
    required double totalAmount,
    required String paymentMethod,
    Map<String, dynamic>? shippingAddress,
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
    String? notes,
  }) async {
    try {
      final requestData = {
        'products': products,
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        if (shippingAddress != null) 'shippingAddress': shippingAddress,
        if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
        if (razorpayOrderId != null) 'razorpayOrderId': razorpayOrderId,
        if (razorpaySignature != null) 'razorpaySignature': razorpaySignature,
        if (notes != null) 'notes': notes,
      };

      print('Creating order with data: $requestData');

      final response = await _dio.post('/create', data: requestData);

      if (response.statusCode == 201 && response.data['success'] == true) {
        return {
          'success': true,
          'order': response.data['order'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to create order',
        };
      }
    } catch (e) {
      print('Error creating order: $e');
      if (e is DioException) {
        final errorData = e.response?.data;
        return {
          'success': false,
          'message': errorData?['message'] ?? 'Failed to create order: ${e.message}',
          'error': errorData,
        };
      }
      return {
        'success': false,
        'message': 'Failed to create order: ${e.toString()}',
      };
    }
  }

  /// Get user's orders
  Future<Map<String, dynamic>> getOrders({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get('/', queryParameters: {
        'page': page,
        'limit': limit,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'orders': response.data['data']['orders'],
          'pagination': response.data['data']['pagination'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to fetch orders',
        };
      }
    } catch (e) {
      print('Error fetching orders: $e');
      return {
        'success': false,
        'message': 'Failed to fetch orders: ${e.toString()}',
      };
    }
  }

  /// Get specific order details
  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    try {
      final response = await _dio.get('/$orderId');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'order': response.data['data']['order'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to fetch order details',
        };
      }
    } catch (e) {
      print('Error fetching order details: $e');
      return {
        'success': false,
        'message': 'Failed to fetch order details: ${e.toString()}',
      };
    }
  }

  /// Get order by ID (alias for getOrderDetails for compatibility)
  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    final result = await getOrderDetails(orderId);
    if (result['success'] == true) {
      return result['order'];
    }
    return null;
  }

  /// Get order statistics
  Future<Map<String, dynamic>> getOrderStats() async {
    try {
      final response = await _dio.get('/stats/summary');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'stats': response.data['data']['stats'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to fetch order statistics',
        };
      }
    } catch (e) {
      print('Error fetching order stats: $e');
      return {
        'success': false,
        'message': 'Failed to fetch order statistics: ${e.toString()}',
      };
    }
  }

  /// Update order status (for future use)
  Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      final response = await _dio.put('/$orderId/status', data: {
        'status': status,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'order': response.data['data']['order'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to update order status',
        };
      }
    } catch (e) {
      print('Error updating order status: $e');
      return {
        'success': false,
        'message': 'Failed to update order status: ${e.toString()}',
      };
    }
  }
}
