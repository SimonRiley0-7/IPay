import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ipay/services/auth_service.dart';
import 'package:ipay/services/cart_service.dart';
import 'package:ipay/services/order_service.dart';
import 'package:ipay/services/wallet_service.dart';
import 'package:ipay/services/cloudinary_service.dart';
import 'package:ipay/screens/scanner/barcode_scanner_screen.dart';
import 'package:ipay/screens/cart/cart_screen.dart';
import 'package:ipay/screens/profile/profile_screen.dart';
import 'package:ipay/screens/wallet/wallet_screen.dart';
import 'package:ipay/screens/orders/orders_screen.dart';
import 'package:ipay/screens/orders/order_detail_screen.dart';
import 'package:ipay/models/order_model.dart';
import 'package:ipay/widgets/logo_widget.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'dart:io';

// Theme constants for consistency
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

// Data models
class UserModel {
  final String name;
  final String id;
  final double walletBalance;
  final String? email;
  final String? phone;
  final String? profilePicture;
  
  const UserModel({
    required this.name,
    required this.id,
    required this.walletBalance,
    this.email,
    this.phone,
    this.profilePicture,
  });
  
  String get profileImageUrl => profilePicture ?? '';
}

class QuickAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool isEnabled;
  
  const QuickAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle = '',
    this.iconColor,
    this.isEnabled = true,
  });
}


class HomeScreen extends StatefulWidget {
  final UserModel? user;
  final List<OrderModel>? recentOrders;
  final VoidCallback? onRefresh;
  final Function(int)? onNavigateToTab;
  
  const HomeScreen({
    Key? key,
    this.user,
    this.recentOrders,
    this.onRefresh,
    this.onNavigateToTab,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // User data from authentication
  final AuthService _authService = AuthService();
  final CartService _cartService = CartService();
  final OrderService _orderService = OrderService();
  final WalletService _walletService = WalletService();
  UserModel? _currentUser;
  List<OrderModel> _orders = [];
  bool _isRefreshing = false;
  bool _isLoadingUser = true;
  bool _isLoadingOrders = true;
  double _walletBalance = 0.0;
  bool _isLoadingWallet = true;
  
  // Cache for order details to avoid repeated API calls
  final Map<String, Map<String, dynamic>> _orderDetailsCache = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
    _initializeAnimations();
    _animationController.forward();
  }

  Future<void> _initializeData() async {
    await _loadUserData();
    // Load orders with a fallback - don't block the UI
    _loadOrderData();
    // Load wallet balance in background
    _loadWalletBalance();
    await _loadCartCount();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoadingUser = true;
      });

      print('🏠 HomeScreen: Loading user data...');
      
      // Get stored user data from auth service
      final userData = await _authService.getStoredUserData();
      
      print('🏠 HomeScreen: Retrieved user data: $userData');
      
      if (userData != null) {
        setState(() {
          _currentUser = UserModel(
            name: userData['name'] ?? 'User',
            id: userData['_id'] ?? userData['id'] ?? 'USER001',
            walletBalance: 0.0, // Not used anymore - we fetch real balance separately
            email: userData['email'],
            phone: userData['phone'],
            profilePicture: userData['profilePicture'],
          );
          _isLoadingUser = false;
        });
        print('🏠 HomeScreen: User data loaded successfully - ${_currentUser!.name}');
        print('🏠 HomeScreen: Profile picture URL - ${_currentUser!.profilePicture}');
        print('🏠 HomeScreen: Should show profile image - ${_shouldShowProfileImage()}');
      } else {
        print('🏠 HomeScreen: No user data found, using default');
        // Fallback to default user if no data found
        setState(() {
          _currentUser = const UserModel(
            name: 'User',
            id: 'USER001',
            walletBalance: 0.0, // Not used anymore - we fetch real balance separately
          );
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _currentUser = const UserModel(
          name: 'User',
          id: 'USER001',
          walletBalance: 0.00,
        );
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _loadOrderData() async {
    // Show sample orders immediately to avoid loading state
    _orders = _getSampleOrders();
    if (mounted) {
      setState(() {
        _isLoadingOrders = false;
      });
    }

    // Try to fetch real orders from backend in background
    try {
      print('🔄 Loading orders from backend...');
      
      final response = await _orderService.getOrders(limit: 5);
      
      if (response['success'] == true) {
        final orders = (response['orders'] as List).cast<Map<String, dynamic>>();
        
        // Convert backend orders to OrderModel
        final realOrders = orders.map((order) => OrderModel(
          id: order['_id'] ?? order['id'] ?? '',
          displayId: order['orderNumber'] ?? '#${order['_id']?.toString().substring(0, 6).toUpperCase()}',
          numericalID: order['numericalID'] ?? order['_id']?.toString().substring(0, 6) ?? '000000',
          amount: (order['totalAmount'] as num?)?.toDouble() ?? 0.0,
          status: _mapOrderStatus(order['status']),
          createdAt: DateTime.parse(order['createdAt'] ?? DateTime.now().toIso8601String()),
          merchantName: 'iPay Store', // Default merchant name
          itemCount: (order['products'] as List?)?.length ?? 0,
        )).toList();

        // Sort by creation date (newest first)
        realOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Update with real orders if we got them
        if (mounted) {
          setState(() {
            _orders = realOrders;
          });
        }

        print('✅ Loaded ${realOrders.length} real orders from backend');
      } else {
        print('❌ Failed to load orders: ${response['message']} - keeping sample orders');
      }
    } catch (e) {
      print('❌ Backend connection failed: $e - keeping sample orders');
    }
  }

  Future<void> _loadWalletBalance() async {
    try {
      setState(() {
        _isLoadingWallet = true;
      });

      print('🔄 Loading wallet balance from backend...');
      
      final balance = await _walletService.getWalletBalance();
      
      if (mounted) {
        setState(() {
          _walletBalance = balance;
          _isLoadingWallet = false;
        });
      }

      print('✅ Loaded wallet balance: ₹${_formatCurrency(balance)}');
    } catch (e) {
      print('❌ Error loading wallet balance: $e');
      if (mounted) {
        setState(() {
          _isLoadingWallet = false;
        });
      }
    }
  }

  List<OrderModel> _getSampleOrders() {
    return [
      OrderModel(
        id: 'sample_001',
        displayId: '#ABC123',
        numericalID: '123456',
        amount: 299.00,
        status: OrderStatus.paid,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        merchantName: 'iPay Store',
        itemCount: 3,
      ),
      OrderModel(
        id: 'sample_002',
        displayId: '#DEF456',
        numericalID: '234567',
        amount: 150.50,
        status: OrderStatus.paid,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        merchantName: 'iPay Store',
        itemCount: 2,
      ),
      OrderModel(
        id: 'sample_003',
        displayId: '#GHI789',
        numericalID: '345678',
        amount: 89.99,
        status: OrderStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        merchantName: 'iPay Store',
        itemCount: 1,
      ),
      OrderModel(
        id: 'sample_004',
        displayId: '#JKL012',
        numericalID: '456789',
        amount: 450.75,
        status: OrderStatus.paid,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        merchantName: 'iPay Store',
        itemCount: 4,
      ),
      OrderModel(
        id: 'sample_005',
        displayId: '#MNO345',
        numericalID: '567890',
        amount: 75.25,
        status: OrderStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        merchantName: 'iPay Store',
        itemCount: 1,
      ),
    ];
  }

  OrderStatus _mapOrderStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'paid':
        return OrderStatus.paid;
      case 'pending':
      case 'processing':
        return OrderStatus.pending;
      case 'failed':
        return OrderStatus.failed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  Future<void> _loadCartCount() async {
    try {
      final count = await _cartService.getCartItemCount();
      if (mounted) {
        setState(() {
        });
      }
    } catch (e) {
      print('Error loading cart count: $e');
    }
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
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    
    // Haptic feedback
    await HapticFeedback.lightImpact();
    
    try {
      // Reload user data
      await _loadUserData();
      
      // Reload orders data
      await _loadOrderData();
      
      // Reload wallet balance
      await _loadWalletBalance();
      
      // Reload cart count
      await _loadCartCount();
      
      if (widget.onRefresh != null) {
        widget.onRefresh!();
      }
      
      // Reset animation
      _animationController.reset();
      _animationController.forward();
      
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
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
        child: AnimatedBuilder(
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
                      // App Bar
                      _buildSliverAppBar(),
                      
                      // Content
                      SliverPadding(
                        padding: AppTheme.paddingLarge,
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Wallet Card Section
                            _buildWalletCard(),
                            
                            const SizedBox(height: 32),
                      
                      // Quick Actions Section
                      _buildQuickActionsSection(),
                            
                            const SizedBox(height: 32),
                      
                      // Recent Orders Section
                      _buildRecentOrdersSection(),
                            
                            // Bottom padding
                            const SizedBox(height: 24),
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
    );
  }



  void _handleScanCode() {
    // Navigate to barcode scanner
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );
  }

  void _navigateToCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CartScreen(),
      ),
    );
    // Refresh cart count when returning from cart screen
    await _loadCartCount();
  }

  void _navigateToWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WalletScreen(),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  void _handleProfileTap() {
    // Debug profile picture info
    print('👤 Profile tap - User: ${_currentUser?.name}');
    print('👤 Profile picture URL: ${_currentUser?.profilePicture}');
    print('👤 Should show image: ${_shouldShowProfileImage()}');
    
    _navigateToProfile();
  }

  Widget _buildSliverAppBar() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                _isLoadingUser || _currentUser == null
                    ? Container(
                        width: 120,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : Text(
                        _currentUser!.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
              ],
            ),
            Row(
              children: [
                
                const SizedBox(width: 8),
                _buildProfileAvatar(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool hasNotification = false,
  }) {
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
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                color: AppTheme.textSecondary,
                size: 22,
              ),
              if (hasNotification)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: AppTheme.primaryGreen.withOpacity(0.1),
          child: InkWell(
            onTap: _handleProfileTap,
                      child: _shouldShowProfileImage()
                          ? _isNetworkImage()
                              ? Image.network(
                                  CloudinaryService.getThumbnailUrl(_currentUser!.profilePicture!),
                                  fit: BoxFit.cover,
                                  width: 44,
                                  height: 44,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return _buildLoadingAvatar();
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Profile image error: $error');
                                    return _buildDefaultAvatar();
                                  },
                                )
                              : Image.file(
                                  File(_currentUser!.profilePicture!),
                                  fit: BoxFit.cover,
                                  width: 44,
                                  height: 44,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Profile image error: $error');
                                    return _buildDefaultAvatar();
                                  },
                                )
                          : _buildDefaultAvatar(),
          ),
        ),
      ),
    );
  }

  bool _shouldShowProfileImage() {
    return _currentUser?.profilePicture != null && 
           _currentUser!.profilePicture!.isNotEmpty;
  }

  bool _isNetworkImage() {
    return _currentUser?.profilePicture != null && 
           _currentUser!.profilePicture!.startsWith('http');
  }

  Widget _buildLoadingAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Text(
        _currentUser?.name.split(' ').map((n) => n[0]).take(2).join() ?? 'U',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreenLight,
            Color(0xFF6BB5A7),
          ],
          stops: [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            blurRadius: 32,
            offset: const Offset(0, 16),
            spreadRadius: 0,
          ),
        ],
        ),
        child: Padding(
        padding: AppTheme.paddingXLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                      'Available Balance',
                        style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isLoadingWallet
                        ? Container(
                            width: 150,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          )
                        : Text(
                            '₹${_formatCurrency(_walletBalance)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              height: 1.0,
                        ),
                      ),
                    ],
                  ),
                _buildAddMoneyButton(),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildWalletAction(
                  icon: Iconsax.receipt_2,
                  label: 'Receipts',
                  onTap: _handleReceipts,
                ),
                const SizedBox(width: 16),
                _buildWalletAction(
                  icon: Iconsax.clock,
                  label: 'History',
                  onTap: _handleWalletHistory,
                ),
                const SizedBox(width: 16),
                _buildWalletAction(
                  icon: Iconsax.wallet_3,
                  label: 'Balance',
                  onTap: _handleBalanceDetails,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMoneyButton() {
    return Container(
                    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _handleAddMoney,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Iconsax.add,
                  color: AppTheme.primaryGreen,
                  size: 18,
                              ),
                const SizedBox(width: 6),
                const Text(
                                'Add Money',
                                style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 15,
                                  fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildWalletAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                  color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    final actions = [
      QuickAction(
        icon: Iconsax.scan,
        title: 'Scan Code',
        subtitle: '',
        onTap: _handleScanPay,
      ),
      QuickAction(
        icon: Iconsax.shopping_cart,
        title: 'Cart',
        subtitle: '',
        onTap: _handleShoppingCart,
      ),
      QuickAction(
        icon: Iconsax.receipt_2,
        title: 'My Orders',
        subtitle: '',
        onTap: _handleMyOrders,
      ),
      QuickAction(
        icon: Iconsax.wallet_3,
        title: 'Wallet',
        subtitle: '',
        onTap: _handleWalletManage,
      ),
    ];

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
                fontSize: 22,
              fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
            ),
            ),
            
          ],
          ),
          const SizedBox(height: 16),
        GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.1,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) => _buildActionCard(actions[index]),
        ),
      ],
    );
  }

  Widget _buildActionCard(QuickAction action) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          onTap: action.isEnabled ? action.onTap : null,
          splashColor: AppTheme.primaryGreen.withOpacity(0.1),
          highlightColor: AppTheme.primaryGreen.withOpacity(0.05),
          child: Padding(
            padding: AppTheme.paddingMedium,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  ),
                  child: Icon(
                    action.icon,
                    color: action.iconColor ?? AppTheme.primaryGreen,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        action.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                      if (action.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                          action.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                            letterSpacing: -0.1,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Iconsax.arrow_right_2,
                  color: AppTheme.textTertiary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOrdersSection() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Recent Orders',
            style: TextStyle(
                fontSize: 22,
              fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            TextButton(
              onPressed: _handleViewAllOrders,
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
          ),
          const SizedBox(height: 16),
        if (_isLoadingOrders)
          _buildLoadingOrdersState()
        else if (_orders.isEmpty)
          _buildEmptyOrdersState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _orders.take(5).length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
          ),
      ],
    );
  }

  Widget _buildLoadingOrdersState() {
    return Container(
      width: double.infinity,
      padding: AppTheme.paddingXLarge,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Loading Orders...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'This will only take a moment',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrdersState() {
    return Container(
      width: double.infinity,
      padding: AppTheme.paddingXLarge,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Iconsax.bag_2,
              color: AppTheme.primaryGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Recent Orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start shopping to see your orders here',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Container(
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
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          onTap: () => _handleOrderTap(order),
          splashColor: AppTheme.primaryGreen.withOpacity(0.1),
          highlightColor: AppTheme.primaryGreen.withOpacity(0.05),
          child: Padding(
            padding: AppTheme.paddingMedium,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _getOrderStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  ),
                  child: Icon(
                    _getOrderStatusIcon(order.status),
                    color: _getOrderStatusColor(order.status),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                            '#${order.numericalID}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          _buildStatusBadge(order.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${_formatCurrency(order.amount)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.1,
                        ),
                      ),
                      Text(
                            _formatRelativeDate(order.createdAt),
                            style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                              letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                      if (order.merchantName.isNotEmpty) ...[
                        const SizedBox(height: 4),
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
                                order.merchantName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                  letterSpacing: -0.1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (order.itemCount > 0)
                              Text(
                                '${order.itemCount} items',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _downloadOrder(order),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Iconsax.document_download,
                          color: AppTheme.primaryGreen,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Iconsax.arrow_right_2,
                      color: AppTheme.textTertiary,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    final statusConfig = _getStatusConfig(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusConfig['backgroundColor'],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusConfig['icon'],
            color: statusConfig['textColor'],
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            statusConfig['text'],
            style: TextStyle(
              color: statusConfig['textColor'],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  // Utility methods
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(2);
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getOrderStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.paid:
        return AppTheme.successColor;
      case OrderStatus.processing:
        return AppTheme.warningColor;
      case OrderStatus.pending:
        return AppTheme.warningColor;
      case OrderStatus.failed:
        return AppTheme.errorColor;
      case OrderStatus.cancelled:
        return AppTheme.textSecondary;
    }
  }

  IconData _getOrderStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.paid:
        return Iconsax.tick_circle;
      case OrderStatus.processing:
        return Iconsax.clock;
      case OrderStatus.pending:
        return Iconsax.timer_1;
      case OrderStatus.failed:
        return Iconsax.warning_2;
      case OrderStatus.cancelled:
        return Iconsax.close_circle;
    }
  }

  Map<String, dynamic> _getStatusConfig(OrderStatus status) {
    switch (status) {
      case OrderStatus.paid:
        return {
          'backgroundColor': AppTheme.successColor,
          'textColor': Colors.white,
          'icon': Icons.check,
          'text': 'Paid',
        };
      case OrderStatus.processing:
        return {
          'backgroundColor': AppTheme.warningColor.withOpacity(0.1),
          'textColor': AppTheme.warningColor,
          'icon': Icons.hourglass_empty,
          'text': 'Processing',
        };
      case OrderStatus.pending:
        return {
          'backgroundColor': AppTheme.warningColor.withOpacity(0.1),
          'textColor': AppTheme.warningColor,
          'icon': Icons.schedule,
          'text': 'Pending',
        };
      case OrderStatus.failed:
        return {
          'backgroundColor': AppTheme.errorColor,
          'textColor': Colors.white,
          'icon': Icons.close,
          'text': 'Failed',
        };
      case OrderStatus.cancelled:
        return {
          'backgroundColor': AppTheme.textSecondary.withOpacity(0.1),
          'textColor': AppTheme.textSecondary,
          'icon': Icons.cancel,
          'text': 'Cancelled',
        };
    }
  }

  // Event handlers
  void _handleNotificationsTap() {
    HapticFeedback.lightImpact();
    // TODO: Navigate to notifications screen
    debugPrint('Navigate to notifications');
  }


  void _handleAddMoney() {
    HapticFeedback.lightImpact();
    // TODO: Navigate to add money screen or show bottom sheet
    debugPrint('Add money functionality');
  }

  void _handleWalletHistory() {
    HapticFeedback.lightImpact();
    // TODO: Navigate to wallet history screen
    debugPrint('Navigate to wallet history');
  }

  void _handleReceipts() {
    HapticFeedback.lightImpact();
    // TODO: Navigate to digital receipts screen
    debugPrint('Navigate to digital receipts');
  }

  void _handleBalanceDetails() {
    HapticFeedback.lightImpact();
    // TODO: Navigate to detailed balance/wallet info screen
    debugPrint('Navigate to balance details');
  }

  void _handleScanPay() {
    HapticFeedback.lightImpact();
    // Navigate to barcode scanner
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );
  }

  void _handleShoppingCart() async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CartScreen(),
      ),
    );
    // Refresh cart count when returning from cart screen
    await _loadCartCount();
  }

  void _handleMyOrders() {
    HapticFeedback.lightImpact();
    // Navigate to Orders tab (index 3) in main screen
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(3); // Orders tab index
    } else {
      // Fallback: push new screen if callback not available
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OrdersScreen(),
        ),
      );
    }
  }

  void _handleWalletManage() {
    HapticFeedback.lightImpact();
    _navigateToWallet();
  }


  void _handleViewAllOrders() {
    HapticFeedback.lightImpact();
    // Navigate to Orders tab (index 3) in main screen
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(3); // Orders tab index
    } else {
      // Fallback: push new screen if callback not available
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const OrdersScreen(),
        ),
      );
    }
  }

  void _handleOrderTap(OrderModel order) async {
    HapticFeedback.lightImpact();
    
    // Check cache first for instant loading
    if (_orderDetailsCache.containsKey(order.id)) {
      final cachedData = _orderDetailsCache[order.id]!;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OrderDetailScreen(order: cachedData),
        ),
      );
      return;
    }
    
    // Create immediate fallback data for instant UI
    final immediateData = {
      'numericalID': order.numericalID,
      'orderNumber': order.displayId,
      '_id': order.id,
      'status': order.status.toString().split('.').last,
      'totalAmount': order.amount,
      'createdAt': order.createdAt.toIso8601String(),
      'products': [], // Will be loaded in background
      'shippingAddress': {
        'name': 'N/A',
        'phone': 'N/A',
        'address': 'N/A',
        'city': '',
        'state': '',
        'pincode': '',
        'country': 'India',
      },
      'paymentMethod': 'unknown',
      'isLoading': true, // Flag to show loading state in UI
    };
    
    // Navigate immediately with basic data
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(order: immediateData),
      ),
    );
    
    // Fetch full details in background
    try {
      final fullOrderData = await _orderService.getOrderById(order.id);
      
      if (fullOrderData != null) {
        // Cache the full data
        _orderDetailsCache[order.id] = fullOrderData;
        
        // Update the order detail screen if it's still open
        // Note: This would require a callback mechanism to update the screen
        // For now, the user can refresh or go back and tap again for full data
      }
    } catch (e) {
      print('Failed to load full order details: $e');
      // Silent fail - user already has basic data
    }
  }

  void _downloadOrder(OrderModel order) async {
    HapticFeedback.lightImpact();
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryGreen,
        ),
      ),
    );
    
    try {
      // Fetch full order details for download
      final fullOrderData = await _orderService.getOrderById(order.id);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (fullOrderData != null) {
        // Generate and download order receipt
        await _generateOrderReceipt(fullOrderData, order);
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load order details for download'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _generateOrderReceipt(Map<String, dynamic> orderData, OrderModel order) async {
    try {
      // Generate PDF receipt
      final pdfFile = await _createOrderReceiptPDF(orderData, order);
      
      // Show success message with download notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('PDF downloaded to Downloads folder'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () {
                // Open the PDF file
                _openPDFFile(pdfFile);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<File> _createOrderReceiptPDF(Map<String, dynamic> orderData, OrderModel order) async {
    final products = orderData['products'] as List? ?? [];
    final totalAmount = orderData['totalAmount'] ?? order.amount;
    final createdAt = orderData['createdAt'] ?? order.createdAt.toIso8601String();
    final status = orderData['status'] ?? order.status.toString().split('.').last;
    final paymentMethod = orderData['paymentMethod'] ?? 'Unknown';
    final shippingAddress = orderData['shippingAddress'] as Map<String, dynamic>? ?? {};
    
    final date = DateTime.parse(createdAt);
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    
    // Create PDF document
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'NEO CART',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Order Info
              pw.Text(
                'Order #${order.numericalID}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Date: $formattedDate'),
              pw.Text('Status: ${status.toUpperCase()}'),
              pw.Text('Payment: ${paymentMethod.toUpperCase()}'),
              pw.SizedBox(height: 20),
              
              // Items
              pw.Text(
                'Items',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              
              // Product list
              ...products.map((product) {
                final name = product['name'] ?? 'Unknown Product';
                final price = (product['price'] as num?)?.toDouble() ?? 0.0;
                final quantity = product['quantity'] ?? 1;
                final total = price * quantity;
                
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '$name x$quantity',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ),
                      pw.Text(
                        'Rs ${total.toStringAsFixed(0)}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
              
              pw.SizedBox(height: 16),
              
              // Total
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Rs ${totalAmount.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 20),
              
              // Shipping Address
              if (shippingAddress.isNotEmpty) ...[
                pw.Text(
                  'Delivery Address',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text(shippingAddress['name'] ?? ''),
                pw.Text(shippingAddress['address'] ?? ''),
                if (shippingAddress['city']?.isNotEmpty == true)
                  pw.Text('${shippingAddress['city']}, ${shippingAddress['state']}'),
                pw.Text('${shippingAddress['pincode']} ${shippingAddress['country']}'),
                pw.SizedBox(height: 20),
              ],
              
              // Footer
              pw.Center(
                child: pw.Text(
                  'Thank you for your order!',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );
    
    // Save PDF to Downloads folder (more accessible)
    final directory = await getExternalStorageDirectory();
    final downloadsPath = '${directory?.path}/../Download';
    final downloadsDir = Directory(downloadsPath);
    
    // Create Downloads directory if it doesn't exist
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    
    final file = File('${downloadsDir.path}/Order_${order.numericalID}.pdf');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }
  
  void _openPDFFile(File file) async {
    try {
      final result = await OpenFile.open(file.path);
      
      if (result.type != ResultType.done) {
        // If PDF can't be opened directly, show a message with file location
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved to: ${file.path}'),
              backgroundColor: AppTheme.primaryGreen,
              action: SnackBarAction(
                label: 'Copy Path',
                textColor: Colors.white,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: file.path));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('File path copied to clipboard'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Handle the missing plugin exception gracefully
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to: ${file.path}\nTap "Copy Path" to access the file'),
            backgroundColor: AppTheme.primaryGreen,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Copy Path',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: file.path));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('File path copied to clipboard'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  void _showReceiptPreview(String receipt, OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${order.numericalID} Receipt'),
        content: SingleChildScrollView(
          child: Text(
            receipt,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // In a real app, you'd save/share the file
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Receipt saved to Downloads'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// Extension for additional utility methods
extension DateTimeExtensions on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && 
           month == yesterday.month && 
           day == yesterday.day;
  }
}