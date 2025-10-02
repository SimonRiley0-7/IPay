import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ipay/services/cart_service.dart';
import 'package:ipay/services/order_service.dart';
import 'package:ipay/services/wallet_service.dart';
import 'package:ipay/services/razorpay_service.dart';
import 'package:ipay/services/auth_service.dart';
import 'package:ipay/screens/order/order_success_screen.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:iconsax/iconsax.dart';

// Reuse the same theme from home screen
class AppTheme {
  static const Color primaryGreen = Color(0xFF4A9B8E);
  static const Color primaryGreenLight = Color(0xFF5BA8A0);
  static const Color primaryGreenDark = Color(0xFF3D8B7E);
  static const Color backgroundColor = Color(0xFFF8FFFE);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF1A202C);
  static const Color textSecondary = Color(0xFF718096);
  static const Color textTertiary = Color(0xFFA0AEC0);
  static const Color successColor = Color(0xFF38A169);
  static const Color errorColor = Color(0xFFE53E3E);
  static const Color warningColor = Color(0xFFD69E2E);
  
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXLarge = 20.0;
  
  static const EdgeInsets paddingSmall = EdgeInsets.all(8.0);
  static const EdgeInsets paddingMedium = EdgeInsets.all(16.0);
  static const EdgeInsets paddingLarge = EdgeInsets.all(20.0);
  static const EdgeInsets paddingXLarge = EdgeInsets.all(24.0);
}

class CartItem {
  final String id;
  final String name;
  final String barcode;
  final double price;
  final int quantity;
  final String? image;
  final String brand;
  final String category;
  
  const CartItem({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.quantity,
    this.image,
    required this.brand,
    required this.category,
  });
  
  double get totalPrice => price * quantity;
}

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  final CartService _cartService = CartService();
  final OrderService _orderService = OrderService();
  final WalletService _walletService = WalletService();
  final RazorpayService _razorpayService = RazorpayService();
  final AuthService _authService = AuthService();
  
  List<Map<String, dynamic>> _cartItems = [];
  bool _isRefreshing = false;
  bool _isLoading = true;
  
  // Payment method selection
  String _selectedPaymentMethod = 'Wallet';
  bool _showPaymentDropdown = false;
  
  // Checkout state
  bool _isProcessingPayment = false;
  double _walletBalance = 0.0;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadCartItems();
    _loadWalletBalance();
    _initializeRazorpay();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _razorpayService.dispose();
    super.dispose();
  }

  Future<void> _loadWalletBalance() async {
    try {
      final balance = await _walletService.getWalletBalance();
      setState(() {
        _walletBalance = balance;
      });
    } catch (e) {
      print('Error loading wallet balance: $e');
    }
  }

  Future<void> _initializeRazorpay() async {
    await _razorpayService.initialize();
    _razorpayService.onPaymentSuccess = _handleRazorpaySuccess;
    _razorpayService.onPaymentError = _handleRazorpayError;
  }

  Future<void> _processWalletPayment() async {
    try {
      // Check wallet balance
      if (_walletBalance < _totalAmount) {
        _showErrorSnackBar('Insufficient wallet balance. Required: ₹${_formatCurrency(_totalAmount)}, Available: ₹${_formatCurrency(_walletBalance)}');
        return;
      }

      // Create order with wallet payment
      final orderResult = await _createOrder('wallet');
      print('Wallet order result: $orderResult');
      if (orderResult['success']) {
        print('Order data being passed to success screen: ${orderResult['order']}');
        await _handleSuccessfulPayment(orderResult['order']);
      } else {
        _showErrorSnackBar(orderResult['message'] ?? 'Failed to process wallet payment');
      }
    } catch (e) {
      print('Wallet payment error: $e');
      _showErrorSnackBar('Failed to process wallet payment: ${e.toString()}');
    }
  }

  Future<void> _processRazorpayPayment() async {
    try {
      // Get user data for Razorpay
      final userData = await _authService.getStoredUserData();
      if (userData == null) {
        _showErrorSnackBar('User data not found');
        return;
      }

      // Open Razorpay payment gateway
      await _razorpayService.openPaymentGateway(
        amount: _totalAmount,
        description: 'Payment for ${_cartItems.length} items',
        userEmail: userData['email'] ?? '',
        userName: userData['name'] ?? '',
        userPhone: userData['phone'] ?? '',
      );
    } catch (e) {
      print('Razorpay payment error: $e');
      _showErrorSnackBar('Failed to open payment gateway: ${e.toString()}');
    }
  }

  void _showPaymentNotSupported() {
    _showErrorSnackBar('Payment method not supported yet');
  }

  Future<Map<String, dynamic>> _createOrder(String paymentMethod, {
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
  }) async {
    try {
      // Prepare products data
      final products = _cartItems.map((item) => {
        'productId': item['id'],
        'name': item['name'],
        'price': item['price'],
        'quantity': item['quantity'],
        'image': item['image'] ?? '',
        'category': item['category'] ?? '',
        'productSnapshot': {
          'name': item['name'],
          'price': item['price'],
          'image': item['image'] ?? '',
          'category': item['category'] ?? '',
        }
      }).toList();

      // Get user data for shipping address
      final userData = await _authService.getStoredUserData();
      final shippingAddress = {
        'name': userData?['name'] ?? '',
        'phone': userData?['phone'] ?? '',
        'address': userData?['address'] ?? '',
        'city': '',
        'state': '',
        'pincode': '',
        'country': 'India',
      };

      final result = await _orderService.createOrder(
        products: products,
        totalAmount: _totalAmount,
        paymentMethod: paymentMethod,
        shippingAddress: shippingAddress,
        razorpayPaymentId: razorpayPaymentId,
        razorpayOrderId: razorpayOrderId,
        razorpaySignature: razorpaySignature,
        notes: 'Order from iPay app',
      );

      return result;
    } catch (e) {
      print('Create order error: $e');
      return {
        'success': false,
        'message': 'Failed to create order: ${e.toString()}',
      };
    }
  }

  Future<void> _handleSuccessfulPayment(Map<String, dynamic> order) async {
    try {
      // Clear cart
      await _cartService.clearCart();
      
      // Refresh cart items
      await _loadCartItems();
      
      // Refresh wallet balance
      await _loadWalletBalance();

      // Navigate to order success screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => OrderSuccessScreen(
            orderData: order,
            paymentMethod: _selectedPaymentMethod,
            totalAmount: _totalAmount,
          ),
        ),
      );
      
    } catch (e) {
      print('Handle successful payment error: $e');
      _showErrorSnackBar('Order created but failed to clear cart');
    }
  }

  void _handleRazorpaySuccess(PaymentSuccessResponse response) {
    print('Razorpay Payment Success: ${response.paymentId}');
    
    // Create order with Razorpay payment details
    _createOrderWithRazorpay(
      paymentId: response.paymentId ?? '',
      orderId: response.orderId ?? '',
      signature: response.signature ?? '',
    );
  }

  void _handleRazorpayError(PaymentFailureResponse response) {
    print('Razorpay Payment Error: ${response.message}');
    _showErrorSnackBar('Payment failed: ${response.message}');
  }

  Future<void> _createOrderWithRazorpay({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      final orderResult = await _createOrder(
        'razorpay',
        razorpayPaymentId: paymentId,
        razorpayOrderId: orderId,
        razorpaySignature: signature,
      );

      print('Razorpay order result: $orderResult');
      if (orderResult['success']) {
        print('Order data being passed to success screen: ${orderResult['order']}');
        await _handleSuccessfulPayment(orderResult['order']);
      } else {
        _showErrorSnackBar(orderResult['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      print('Create order with Razorpay error: $e');
      _showErrorSnackBar('Payment successful but failed to create order');
    }
  }

  Future<void> _loadCartItems() async {
    try {
      setState(() => _isLoading = true);
      
      final cartData = await _cartService.getCart();
      
      if (mounted) {
        setState(() {
          _cartItems = cartData;
          _isLoading = false;
        });
        
        _animationController.forward();
      }
    } catch (e) {
      print('Error loading cart items: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    await HapticFeedback.lightImpact();
    
    try {
      await _loadCartItems();
      _animationController.reset();
      _animationController.forward();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _updateQuantity(String itemId, int newQuantity) async {
    if (newQuantity <= 0) {
      await _removeItem(itemId);
      return;
    }
    
    try {
      await _cartService.updateQuantity(itemId, newQuantity);
      await _loadCartItems();
      await HapticFeedback.lightImpact();
    } catch (e) {
      print('Error updating quantity: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update quantity'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeItem(String itemId) async {
    try {
      await _cartService.removeFromCart(itemId);
      await _loadCartItems();
      await HapticFeedback.mediumImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Item removed from cart'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error removing item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to remove item'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            ),
          ),
        );
      }
    }
  }

  Future<void> _clearCart() async {
    try {
      await _cartService.clearCart();
      await _loadCartItems();
      await HapticFeedback.mediumImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cart cleared successfully'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error clearing cart: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to clear cart'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            ),
          ),
        );
      }
    }
  }

  void _togglePaymentDropdown() {
    setState(() {
      _showPaymentDropdown = !_showPaymentDropdown;
    });
    
    HapticFeedback.lightImpact();
  }

  void _selectPaymentMethod(String method) {
    setState(() {
      _selectedPaymentMethod = method;
      _showPaymentDropdown = false;
    });
    
    HapticFeedback.lightImpact();
  }

  Future<void> _proceedToCheckout() async {
    if (_cartItems.isEmpty) {
      _showErrorSnackBar('Your cart is empty');
      return;
    }

    if (_isProcessingPayment) return;
    
    HapticFeedback.mediumImpact();

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      switch (_selectedPaymentMethod) {
        case 'Wallet':
          await _processWalletPayment();
          break;
        case 'Razorpay':
          await _processRazorpayPayment();
          break;
        default:
          _showPaymentNotSupported();
      }
    } finally {
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }


  double get _totalAmount {
    return _cartItems.fold(0.0, (sum, item) => sum + (item['totalPrice'] ?? 0.0));
  }

  int get _totalItems {
    return _cartItems.fold(0, (sum, item) => sum + ((item['quantity'] ?? 0) as int));
  }

  double get _savings {
    // TODO: Calculate actual savings from discounts
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppTheme.primaryGreen,
        backgroundColor: Colors.white,
        displacement: 60,
        child: SafeArea(
          child: _isLoading 
              ? _buildLoadingState()
              : AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            _buildSliverAppBar(),
                            
                            SliverPadding(
                              padding: AppTheme.paddingLarge,
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  if (_cartItems.isEmpty)
                                    _buildEmptyCartState()
                                  else ...[
                                    _buildCartItemsSection(),
                                    
                                    const SizedBox(height: 24),
                                    _buildOrderSummarySection(),
                                    SizedBox(height: _showPaymentDropdown ? 120 : 80),
                                  ],
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      bottomSheet: _cartItems.isEmpty ? null : _buildBottomCheckoutBar(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryGreen,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your cart...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: const Icon(
                        Iconsax.arrow_left_2,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shopping Cart',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (_cartItems.isNotEmpty)
                      Text(
                        '$_totalItems ${_totalItems == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                          letterSpacing: -0.1,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (_cartItems.isNotEmpty)
              _buildClearCartButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildClearCartButton() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            _showClearCartDialog();
          },
          child: const Icon(
            Iconsax.trash,
            color: AppTheme.errorColor,
            size: 22,
          ),
        ),
      ),
    );
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        title: const Text(
          'Clear Cart',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        content: const Text(
          'Are you sure you want to remove all items from your cart?',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCart();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Clear Cart',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCartState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Iconsax.shopping_cart,
              size: 60,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Start shopping by scanning products\nor browsing our catalog',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
              letterSpacing: -0.1,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
                elevation: 0,
                shadowColor: AppTheme.primaryGreen.withOpacity(0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Iconsax.scan, size: 22),
                  SizedBox(width: 12),
                  Text(
                    'Start Scanning',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Cart Items',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '$_totalItems ${_totalItems == 1 ? 'item' : 'items'}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _cartItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildCartItemCard(_cartItems[index]),
        ),
      ],
    );
  }

  Widget _buildCartItemCard(Map<String, dynamic> item) {
    return Dismissible(
      key: Key(item['id'] ?? item['barcode'] ?? ''),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        child: const Icon(
          Iconsax.trash,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (direction) {
        _removeItem(item['id'] ?? item['barcode'] ?? '');
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          border: Border.all(
            color: Colors.grey.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: AppTheme.paddingMedium,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                ),
                child: item['image'] != null && item['image'].isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                        child: Image.network(
                          item['image'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                              _buildDefaultProductImage(),
                        ),
                      )
                    : _buildDefaultProductImage(),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'Unknown Product',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Iconsax.shop,
                          size: 14,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item['brand'] ?? 'Unknown Brand',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                              letterSpacing: -0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${_formatCurrency((item['price'] ?? 0.0).toDouble())}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if ((item['quantity'] ?? 0) > 1) ...[
                              const SizedBox(height: 2),
                              Text(
                                '₹${_formatCurrency((item['totalPrice'] ?? 0.0).toDouble())} total',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        _buildQuantityControls(item),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultProductImage() {
    return const Center(
      child: Icon(
        Iconsax.bag_2,
        color: AppTheme.primaryGreen,
        size: 32,
      ),
    );
  }

  Widget _buildQuantityControls(Map<String, dynamic> item) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQuantityButton(
            icon: Iconsax.minus,
            onTap: () => _updateQuantity(item['id'] ?? item['barcode'] ?? '', (item['quantity'] ?? 1) - 1),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${item['quantity'] ?? 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
                letterSpacing: -0.2,
              ),
            ),
          ),
          _buildQuantityButton(
            icon: Iconsax.add,
            onTap: () => _updateQuantity(item['id'] ?? item['barcode'] ?? '', (item['quantity'] ?? 1) + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: AppTheme.primaryGreen,
            size: 18,
          ),
        ),
      ),
    );
  }

 

  Widget _buildOrderSummarySection() {
    return Container(
      padding: AppTheme.paddingLarge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen.withOpacity(0.08),
            AppTheme.primaryGreenLight.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          _buildSummaryRow(
            'Subtotal',
            '₹${_formatCurrency(_totalAmount)}',
            false,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Delivery Fee',
            'Free',
            false,
            valueColor: AppTheme.successColor,
          ),
          if (_savings > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryRow(
              'Savings',
              '-₹${_formatCurrency(_savings)}',
              false,
              valueColor: AppTheme.successColor,
            ),
          ],
          const SizedBox(height: 16),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.textTertiary.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            'Total Amount',
            '₹${_formatCurrency(_totalAmount)}',
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label, 
    String value, 
    bool isTotal, 
    {Color? valueColor}
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? AppTheme.textPrimary : AppTheme.textSecondary,
            letterSpacing: -0.2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 22 : 16,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? (isTotal ? AppTheme.primaryGreen : AppTheme.textPrimary),
            letterSpacing: isTotal ? -0.4 : -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomCheckoutBar() {
    return GestureDetector(
      onTap: () {
        // Close dropdown when tapping outside
        if (_showPaymentDropdown) {
          setState(() {
            _showPaymentDropdown = false;
          });
        }
      },
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                _buildPaymentMethodSelector(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                    onPressed: _isProcessingPayment ? null : _proceedToCheckout,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _isProcessingPayment 
                          ? AppTheme.primaryGreen.withOpacity(0.6)
                          : AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    ),
                    elevation: 0,
                    shadowColor: AppTheme.primaryGreen.withOpacity(0.3),
                  ),
                    child: _isProcessingPayment
                        ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Processing...',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Iconsax.shopping_cart, size: 22),
                              const SizedBox(width: 12),
                              Text(
                                'Proceed to Checkout • ₹${_formatCurrency(_totalAmount)}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Iconsax.arrow_right_2, size: 20),
                            ],
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(2);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        ),
      ),
    );
  }


  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
        
        // Payment method display
        GestureDetector(
          onTap: _togglePaymentDropdown,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              border: Border.all(
                color: _showPaymentDropdown 
                    ? AppTheme.primaryGreen 
                    : Colors.grey[300]!,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Payment method icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getPaymentMethodIcon(_selectedPaymentMethod),
                    size: 18,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                // Payment method text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PAY USING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedPaymentMethod,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                // Dropdown arrow
                Icon(
                  _showPaymentDropdown 
                      ? Iconsax.arrow_up_2
                      : Iconsax.arrow_down_2,
                  size: 20,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        
        // Simple dropdown - just show/hide
        if (_showPaymentDropdown) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildPaymentOption('Wallet', Iconsax.wallet_3),
                _buildPaymentOption('Razorpay', Iconsax.card),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentOption(String method, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;
    
    return GestureDetector(
      onTap: () => _selectPaymentMethod(method),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppTheme.primaryGreen.withOpacity(0.15)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? AppTheme.primaryGreen : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                method,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Iconsax.tick_circle,
                size: 20,
                color: AppTheme.primaryGreen,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method) {
      case 'Wallet':
        return Iconsax.wallet_3;
      case 'Razorpay':
        return Iconsax.card;
      default:
        return Iconsax.card;
    }
  }
}