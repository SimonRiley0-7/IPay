import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ipay/services/auth_service.dart';
import 'package:dio/dio.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final Dio _dio = Dio();
  final AuthService _authService = AuthService();
  
  // Local cart storage key
  static const String _cartKey = 'user_cart';

  // Initialize cart service
  Future<void> initialize() async {
    // TODO: Initialize with API base URL
  }

  // Add product to cart
  Future<bool> addToCart(Map<String, dynamic> product) async {
    try {
      // Get current cart
      List<Map<String, dynamic>> cart = await getCart();
      
      // Check if product already exists in cart
      int existingIndex = cart.indexWhere(
        (item) => item['barcode'] == product['barcode'],
      );
      
      if (existingIndex != -1) {
        // Product exists, increase quantity
        cart[existingIndex]['quantity'] = (cart[existingIndex]['quantity'] ?? 1) + 1;
        cart[existingIndex]['totalPrice'] = 
            (cart[existingIndex]['price'] ?? 0) * cart[existingIndex]['quantity'];
      } else {
        // New product, add to cart
        cart.add({
          'id': product['id'],
          'barcode': product['barcode'],
          'name': product['name'],
          'price': product['price'],
          'quantity': 1,
          'totalPrice': product['price'],
          'image': product['image'],
          'addedAt': DateTime.now().toIso8601String(),
        });
      }
      
      // Save cart locally
      await _saveCartLocally(cart);
      
      // TODO: Sync with backend API
      // await _syncCartWithBackend(cart);
      
      print('✅ Product added to cart: ${product['name']}');
      return true;
    } catch (e) {
      print('❌ Error adding product to cart: $e');
      return false;
    }
  }

  // Get current cart
  Future<List<Map<String, dynamic>>> getCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_cartKey);
      
      if (cartJson != null) {
        final List<dynamic> cartData = jsonDecode(cartJson);
        return cartData.cast<Map<String, dynamic>>();
      }
      
      return [];
    } catch (e) {
      print('Error getting cart: $e');
      return [];
    }
  }

  // Remove product from cart
  Future<bool> removeFromCart(String itemId) async {
    try {
      List<Map<String, dynamic>> cart = await getCart();
      cart.removeWhere((item) => 
        item['id'] == itemId || item['barcode'] == itemId
      );
      
      await _saveCartLocally(cart);
      // TODO: Sync with backend
      
      print('✅ Removed item from cart: $itemId');
      return true;
    } catch (e) {
      print('Error removing from cart: $e');
      return false;
    }
  }

  // Update quantity of product in cart
  Future<bool> updateQuantity(String itemId, int quantity) async {
    try {
      List<Map<String, dynamic>> cart = await getCart();
      
      // Try to find item by id first, then by barcode
      int index = cart.indexWhere((item) => 
        item['id'] == itemId || item['barcode'] == itemId
      );
      
      if (index != -1) {
        if (quantity <= 0) {
          cart.removeAt(index);
        } else {
          cart[index]['quantity'] = quantity;
          cart[index]['totalPrice'] = (cart[index]['price'] ?? 0) * quantity;
        }
        
        await _saveCartLocally(cart);
        // TODO: Sync with backend
        
        print('✅ Updated quantity for item: ${cart[index]['name']} to $quantity');
        return true;
      }
      
      print('❌ Item not found in cart: $itemId');
      return false;
    } catch (e) {
      print('Error updating quantity: $e');
      return false;
    }
  }

  // Clear cart
  Future<bool> clearCart() async {
    try {
      await _saveCartLocally([]);
      // TODO: Sync with backend
      return true;
    } catch (e) {
      print('Error clearing cart: $e');
      return false;
    }
  }

  // Get cart total
  Future<double> getCartTotal() async {
    try {
      List<Map<String, dynamic>> cart = await getCart();
      double total = 0.0;
      
      for (var item in cart) {
        total += (item['totalPrice'] ?? 0.0).toDouble();
      }
      
      return total;
    } catch (e) {
      print('Error calculating cart total: $e');
      return 0.0;
    }
  }

  // Get cart item count
  Future<int> getCartItemCount() async {
    try {
      List<Map<String, dynamic>> cart = await getCart();
      int count = 0;
      
      for (var item in cart) {
        count += (item['quantity'] ?? 0) as int;
      }
      
      return count;
    } catch (e) {
      print('Error getting cart count: $e');
      return 0;
    }
  }

  // Save cart locally
  Future<void> _saveCartLocally(List<Map<String, dynamic>> cart) async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = jsonEncode(cart);
    await prefs.setString(_cartKey, cartJson);
  }

  // TODO: Sync cart with backend API
  // ignore: unused_element
  Future<void> _syncCartWithBackend(List<Map<String, dynamic>> cart) async {
    try {
      // Get user token
      final token = await _authService.getStoredToken();
      if (token == null) return;

      // Send cart data to backend
      final response = await _dio.post('/api/cart/sync',
        data: {'cart': cart},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        print('✅ Cart synced with backend');
      }
    } catch (e) {
      print('❌ Error syncing cart with backend: $e');
      // Continue with local storage even if backend sync fails
    }
  }

  // Load cart from backend
  Future<void> loadCartFromBackend() async {
    try {
      final token = await _authService.getStoredToken();
      if (token == null) return;

      final response = await _dio.get('/api/cart',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success']) {
        final List<dynamic> backendCart = response.data['data']['items'] ?? [];
        await _saveCartLocally(backendCart.cast<Map<String, dynamic>>());
        print('✅ Cart loaded from backend');
      }
    } catch (e) {
      print('❌ Error loading cart from backend: $e');
      // Continue with local cart if backend fails
    }
  }
}
