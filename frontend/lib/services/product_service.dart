import 'package:dio/dio.dart';
import 'package:ipay/services/auth_service.dart';
import 'package:ipay/config/api_config.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  final Dio _dio = Dio();
  final AuthService _authService = AuthService();

  // Initialize Dio with base configuration
  void _initializeDio() {
    _dio.options.baseUrl = ApiConfig.baseUrl.replaceAll('/api/auth', '/api/products');
    _dio.options.connectTimeout = ApiConfig.timeout;
    _dio.options.receiveTimeout = ApiConfig.timeout;
    _dio.options.headers.addAll(ApiConfig.headers);
  }

  // Get product by barcode from backend API
  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    try {
      _initializeDio();
      print('🔍 Looking up product with barcode: $barcode');
      
      final response = await _dio.get('/barcode/$barcode');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final product = response.data['product'];
        print('✅ Product found: ${product['name']} - ₹${product['price']}');
        return product;
      } else {
        print('❌ Product not found for barcode: $barcode');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching product: $e');
      
      // Fallback to sample products if backend is not available
      return _getSampleProduct(barcode);
    }
  }

  // Get all products with pagination
  Future<List<Map<String, dynamic>>> getAllProducts({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      _initializeDio();
      
      final response = await _dio.get('/', queryParameters: {
        'page': page,
        'limit': limit,
      });
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return List<Map<String, dynamic>>.from(response.data['products']);
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Error fetching products: $e');
      return [];
    }
  }

  // Search products
  Future<List<Map<String, dynamic>>> searchProducts({
    String? query,
    String? category,
    String? brand,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      _initializeDio();
      
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      
      if (query != null && query.isNotEmpty) queryParams['q'] = query;
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (brand != null && brand.isNotEmpty) queryParams['brand'] = brand;
      
      final response = await _dio.get('/search', queryParameters: queryParams);
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return List<Map<String, dynamic>>.from(response.data['products']);
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Error searching products: $e');
      return [];
    }
  }

  // Get product categories
  Future<List<String>> getCategories() async {
    try {
      _initializeDio();
      
      final response = await _dio.get('/categories');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return List<String>.from(response.data['categories']);
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Error fetching categories: $e');
      return [];
    }
  }

  // Get product brands
  Future<List<String>> getBrands() async {
    try {
      _initializeDio();
      
      final response = await _dio.get('/brands');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return List<String>.from(response.data['brands']);
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Error fetching brands: $e');
      return [];
    }
  }

  // Fallback sample products (for offline/fallback scenarios)
  Map<String, dynamic>? _getSampleProduct(String barcode) {
    final sampleProducts = {
      '8901030611234': {
        'id': 'prod_001',
        'barcode': '8901030611234',
        'name': 'Maggi 2-Minute Noodles Masala',
        'price': 14.0,
        'category': 'Instant Food',
        'brand': 'Maggi',
        'image': 'https://via.placeholder.com/150x150?text=Maggi+Masala',
        'description': 'Instant noodles with masala flavor - 70g pack',
        'stock': 50,
        'weight': '70g',
        'tags': ['instant', 'noodles', 'masala', 'vegetarian'],
      },
      '8901030823456': {
        'id': 'prod_002',
        'barcode': '8901030823456',
        'name': 'Britannia Good Day Cookies',
        'price': 20.0,
        'category': 'Biscuits',
        'brand': 'Britannia',
        'image': 'https://via.placeholder.com/150x150?text=Good+Day',
        'description': 'Butter cookies with cashew and almonds - 100g pack',
        'stock': 40,
        'weight': '100g',
        'tags': ['biscuits', 'cookies', 'butter', 'cashew', 'almonds'],
      },
      '8901030934567': {
        'id': 'prod_003',
        'barcode': '8901030934567',
        'name': 'Parle-G Glucose Biscuits',
        'price': 10.0,
        'category': 'Biscuits',
        'brand': 'Parle',
        'image': 'https://via.placeholder.com/150x150?text=Parle-G',
        'description': 'Classic glucose biscuits - 100g pack',
        'stock': 100,
        'weight': '100g',
        'tags': ['biscuits', 'glucose', 'classic', 'energy'],
      },
      '8901030845678': {
        'id': 'prod_004',
        'barcode': '8901030845678',
        'name': 'Coca-Cola Soft Drink',
        'price': 25.0,
        'category': 'Beverages',
        'brand': 'Coca-Cola',
        'image': 'https://via.placeholder.com/150x150?text=Coca-Cola',
        'description': 'Classic Coca-Cola soft drink - 300ml bottle',
        'stock': 75,
        'weight': '300ml',
        'tags': ['soft drink', 'cola', 'carbonated', 'refreshing'],
      },
      '8901030956789': {
        'id': 'prod_005',
        'barcode': '8901030956789',
        'name': 'Amul Milk Chocolate',
        'price': 30.0,
        'category': 'Chocolates',
        'brand': 'Amul',
        'image': 'https://via.placeholder.com/150x150?text=Amul+Chocolate',
        'description': 'Creamy milk chocolate bar - 40g',
        'stock': 45,
        'weight': '40g',
        'tags': ['chocolate', 'milk', 'creamy', 'sweet'],
      },
    };
    
    return sampleProducts[barcode];
  }

  // Test backend connection
  Future<bool> testConnection() async {
    try {
      _initializeDio();
      print('🔄 Testing product API connection...');
      
      final response = await _dio.get('/categories');
      
      if (response.statusCode == 200) {
        print('✅ Product API connection successful!');
        return true;
      } else {
        print('❌ Product API connection failed');
        return false;
      }
    } catch (e) {
      print('❌ Product API connection error: $e');
      return false;
    }
  }
}