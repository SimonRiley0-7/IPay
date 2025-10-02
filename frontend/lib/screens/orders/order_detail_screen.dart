import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ipay/services/cloudinary_service.dart';
import 'package:ipay/services/order_service.dart';

// Reuse the same theme from other screens
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
  static const Color pendingColor = Color(0xFFED8936);
  
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXLarge = 20.0;
  
  static const EdgeInsets paddingSmall = EdgeInsets.all(8.0);
  static const EdgeInsets paddingMedium = EdgeInsets.all(16.0);
  static const EdgeInsets paddingLarge = EdgeInsets.all(20.0);
  static const EdgeInsets paddingXLarge = EdgeInsets.all(24.0);
}

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  Map<String, dynamic>? _orderData;
  bool _isLoadingFullData = false;

  @override
  void initState() {
    super.initState();
    _orderData = Map<String, dynamic>.from(widget.order);
    _initializeAnimations();
    
    // Load full order data if we only have basic data
    if (_orderData!['isLoading'] == true) {
      _loadFullOrderData();
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  Future<void> _loadFullOrderData() async {
    if (_isLoadingFullData || _orderData == null) return;
    
    setState(() {
      _isLoadingFullData = true;
    });

    try {
      // Import OrderService
      final orderService = OrderService();
      final fullOrderData = await orderService.getOrderById(_orderData!['_id']);
      
      if (fullOrderData != null && mounted) {
        setState(() {
          _orderData = fullOrderData;
          _isLoadingFullData = false;
        });
      }
    } catch (e) {
      print('Failed to load full order data: $e');
      if (mounted) {
        setState(() {
          _isLoadingFullData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'en_IN', symbol: '');
    return format.format(amount);
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'N/A';
    }
    final dateTime = DateTime.parse(dateString);
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }


  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
        return AppTheme.successColor;
      case 'pending':
        return AppTheme.pendingColor;
      case 'failed':
      case 'cancelled':
        return AppTheme.errorColor;
      case 'processing':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
        return Iconsax.tick_circle;
      case 'pending':
        return Iconsax.clock;
      case 'failed':
      case 'cancelled':
        return Iconsax.close_circle;
      case 'processing':
        return Iconsax.refresh;
      default:
        return Iconsax.document;
    }
  }

  IconData _getPaymentMethodIcon(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'wallet':
        return Iconsax.wallet_3;
      case 'razorpay':
        return Iconsax.card;
      case 'cod':
        return Iconsax.money;
      default:
        return Iconsax.card;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _orderData ?? widget.order;
    final orderNumber = order['numericalID'] ?? order['orderNumber'] ?? order['_id'] ?? 'N/A';
    final shortId = orderNumber.length > 6 ? orderNumber.substring(0, 6) : orderNumber;
    final status = order['status'] ?? 'pending';
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final createdAt = order['createdAt'] ?? '';
    final products = order['products'] as List? ?? [];
    final shippingAddress = order['shippingAddress'] as Map<String, dynamic>? ?? {};
    final paymentMethod = order['paymentMethod'] ?? 'unknown';
    final isLoading = _isLoadingFullData || (order['isLoading'] == true && products.isEmpty);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(shortId, status),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: AppTheme.paddingLarge,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOrderStatusCard(status, createdAt),
                        const SizedBox(height: 20),
                        isLoading && products.isEmpty 
                          ? _buildLoadingProductsCard()
                          : _buildOrderItemsCard(products),
                        const SizedBox(height: 20),
                        _buildOrderSummaryCard(totalAmount, paymentMethod),
                        const SizedBox(height: 20),
                       
                        _buildOrderInfoCard(_orderData ?? widget.order),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(String shortId, String status) {
    return Container(
      padding: AppTheme.paddingLarge,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Iconsax.arrow_left_2,
                color: AppTheme.primaryGreen,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$shortId',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      size: 16,
                      color: _getStatusColor(status),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusCard(String status, String createdAt) {
    return Container(
      padding: AppTheme.paddingMedium,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusMessage(status),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order placed on ${_formatDate(createdAt)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
        return 'Order Completed';
      case 'pending':
        return 'Order Pending';
      case 'failed':
        return 'Order Failed';
      case 'cancelled':
        return 'Order Cancelled';
      case 'processing':
        return 'Processing Order';
      default:
        return 'Order Status Unknown';
    }
  }

  Widget _buildLoadingProductsCard() {
    return Container(
      padding: AppTheme.paddingMedium,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircularProgressIndicator(
                color: AppTheme.primaryGreen,
                strokeWidth: 2,
              ),
              const SizedBox(width: 12),
              Text(
                'Loading order items...',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard(List products) {
    return Container(
      padding: AppTheme.paddingMedium,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...products.map((product) => _buildOrderItem(product)).toList(),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> product) {
    final name = product['name'] ?? 'Unknown Product';
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final quantity = product['quantity'] ?? 1;
    final image = product['image'] ?? '';
    final total = price * quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              color: Colors.grey.withOpacity(0.1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              child: image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: image.contains('cloudinary.com') 
                          ? CloudinaryService.getThumbnailUrl(image)
                          : image,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.withOpacity(0.1),
                        child: const Icon(
                          Iconsax.shop,
                          color: AppTheme.textTertiary,
                          size: 24,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.withOpacity(0.1),
                        child: const Icon(
                          Iconsax.shop,
                          color: AppTheme.textTertiary,
                          size: 24,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey.withOpacity(0.1),
                      child: const Icon(
                        Iconsax.shop,
                        color: AppTheme.textTertiary,
                        size: 24,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: $quantity',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_formatCurrency(price)} each',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Total Price
          Text(
            '₹${_formatCurrency(total)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(double totalAmount, String paymentMethod) {
    return Container(
      padding: AppTheme.paddingMedium,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '₹${_formatCurrency(totalAmount)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _getPaymentMethodIcon(paymentMethod),
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Paid via ${paymentMethod.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  
  Widget _buildOrderInfoCard(Map<String, dynamic> order) {
    final orderNumber = order['numericalID'] ?? order['orderNumber'] ?? order['_id'] ?? 'N/A';
    final createdAt = order['createdAt'] ?? '';
    final updatedAt = order['updatedAt'] ?? '';

    return Container(
      padding: AppTheme.paddingMedium,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Order ID', orderNumber),
          _buildInfoRow('Order Date', _formatDate(createdAt)),
          if (updatedAt.isNotEmpty)
            _buildInfoRow('Last Updated', _formatDate(updatedAt)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
