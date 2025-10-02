import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:ipay/services/order_service.dart';
import 'package:ipay/models/order_model.dart';
import 'package:ipay/screens/orders/order_detail_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

// Reusing AppTheme for consistency
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
  static const Color infoColor = Color(0xFF3182CE); // For pending/processing

  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXLarge = 20.0;

  static const EdgeInsets paddingSmall = EdgeInsets.all(8.0);
  static const EdgeInsets paddingMedium = EdgeInsets.all(16.0);
  static const EdgeInsets paddingLarge = EdgeInsets.all(20.0);
  static const EdgeInsets paddingXLarge = EdgeInsets.all(24.0);
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderService _orderService = OrderService();
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  bool _hasError = false;
  final RefreshController _refreshController = RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final response = await _orderService.getOrders(limit: 50); // Fetch more orders
      if (response['success'] == true) {
        final orders = (response['orders'] as List).cast<Map<String, dynamic>>();
                final fetchedOrders = orders.map((order) => OrderModel(
                  id: order['_id'] ?? order['id'] ?? '',
                  displayId: order['orderNumber'] ?? '#${order['_id']?.toString().substring(0, 6).toUpperCase()}',
                  numericalID: order['numericalID'] ?? order['_id']?.toString().substring(0, 6) ?? '000000',
                  amount: (order['totalAmount'] as num?)?.toDouble() ?? 0.0,
                  status: _mapOrderStatus(order['status']),
                  createdAt: DateTime.parse(order['createdAt'] ?? DateTime.now().toIso8601String()),
                  merchantName: 'iPay Store',
                  itemCount: (order['products'] as List?)?.length ?? 0,
                )).toList();

        fetchedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (mounted) {
          setState(() {
            _orders = fetchedOrders;
            _isLoading = false;
          });
        }
        _refreshController.refreshCompleted();
      } else {
        throw Exception(response['message'] ?? 'Failed to load orders');
      }
    } catch (e) {
      print('Error loading orders: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
      _refreshController.refreshFailed();
    }
  }

  OrderStatus _mapOrderStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return OrderStatus.paid;
      case 'pending':
        return OrderStatus.pending;
      case 'failed':
        return OrderStatus.failed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'processing':
        return OrderStatus.processing;
    }
    return OrderStatus.pending;
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.paid:
        return AppTheme.successColor;
      case OrderStatus.pending:
        return AppTheme.infoColor;
      case OrderStatus.failed:
        return AppTheme.errorColor;
      case OrderStatus.cancelled:
        return AppTheme.textTertiary;
      case OrderStatus.processing:
        return AppTheme.warningColor;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.paid:
        return 'Completed';
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.failed:
        return 'Failed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.processing:
        return 'Processing';
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'en_IN', symbol: '');
    return format.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  void _navigateToOrderDetail(OrderModel order) async {
    HapticFeedback.lightImpact();
    
    // Create immediate data for instant navigation
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
      'isLoading': true,
    };
    
    // Navigate immediately
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(order: immediateData),
      ),
    );
    
    // Fetch full details in background
    try {
      final fullOrderData = await _orderService.getOrderById(order.id);
      if (fullOrderData != null) {
        // Note: In a real app, you'd want to update the screen with a callback
        // For now, user can go back and tap again for full data
      }
    } catch (e) {
      print('Failed to load full order details: $e');
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

  @override
  Widget build(BuildContext context) {
    print('🛒 OrdersScreen: Building OrdersScreen widget');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Enhanced App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Iconsax.arrow_left_2, color: AppTheme.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Iconsax.refresh, color: AppTheme.textPrimary),
                onPressed: () => _loadOrders(isRefresh: true),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'My Orders',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryGreen.withOpacity(0.1),
                      AppTheme.backgroundColor,
                    ],
                  ),
                ),
      
              ),
            ),
          ),
          
          // Stats Header
          if (!_isLoading && !_hasError && _orders.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildStatsHeader(),
            ),
          
          // Orders List
          _isLoading
              ? SliverToBoxAdapter(child: _buildLoadingState())
              : _hasError
                  ? SliverToBoxAdapter(child: _buildErrorState())
                  : _orders.isEmpty
                      ? SliverToBoxAdapter(child: _buildEmptyState())
                      : SliverPadding(
                          padding: AppTheme.paddingMedium,
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final order = _orders[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildEnhancedOrderCard(order),
                                );
                              },
                              childCount: _orders.length,
                            ),
                          ),
                        ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final totalOrders = _orders.length;
    final completedOrders = _orders.where((order) => order.status == OrderStatus.paid).length;
    final totalSpent = _orders.fold(0.0, (sum, order) => sum + order.amount);
    
    return Container(
      margin: AppTheme.paddingMedium,
      padding: AppTheme.paddingLarge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreenLight,
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Iconsax.receipt_2,
              label: 'Total Orders',
              value: '$totalOrders',
              color: Colors.white,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.3),
          ),
          Expanded(
            child: _buildStatItem(
              icon: Iconsax.tick_circle,
              label: 'Completed',
              value: '$completedOrders',
              color: Colors.white,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.3),
          ),
          Expanded(
            child: _buildStatItem(
              icon: Iconsax.wallet_3,
              label: 'Total Spent',
              value: '₹${_formatCurrency(totalSpent)}',
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedOrderCard(OrderModel order) {
    return GestureDetector(
      onTap: () => _navigateToOrderDetail(order),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with order number and status
            Container(
              padding: AppTheme.paddingMedium,
              decoration: BoxDecoration(
                color: _getStatusColor(order.status).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.borderRadiusLarge),
                  topRight: Radius.circular(AppTheme.borderRadiusLarge),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Iconsax.receipt_2,
                          color: _getStatusColor(order.status),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${order.numericalID}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            _formatDate(order.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(order.status),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Order details
            Padding(
              padding: AppTheme.paddingMedium,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Iconsax.shopping_bag,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${order.itemCount} items',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Iconsax.wallet_3,
                            size: 16,
                            color: AppTheme.primaryGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '₹${_formatCurrency(order.amount)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToOrderDetail(order),
                          icon: const Icon(Iconsax.eye, size: 16),
                          label: const Text('View Details'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryGreen,
                            side: BorderSide(color: AppTheme.primaryGreen),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _downloadOrder(order),
                          icon: const Icon(Iconsax.document_download, size: 16),
                          label: const Text('Download'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reorderItems(OrderModel order) {
    // TODO: Implement reorder functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reorder functionality coming soon!'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primaryGreen),
          SizedBox(height: 16),
          Text(
            'Loading your orders...',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: AppTheme.paddingXLarge,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated empty state illustration
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryGreen.withOpacity(0.1),
                    AppTheme.primaryGreenLight.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Icon(
                    Iconsax.receipt_2,
                    color: AppTheme.primaryGreen,
                    size: 40,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Orders Yet!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your order history will appear here once you start shopping.\nLet\'s get you started with some amazing products!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            
            // Action buttons
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Iconsax.shopping_bag, size: 20),
                  label: const Text(
                    'Start Shopping',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    // Navigate to scanner
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    // Switch to scanner tab
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    side: BorderSide(color: AppTheme.primaryGreen),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    ),
                  ),
                  icon: const Icon(Iconsax.scan, size: 20),
                  label: const Text(
                    'Scan Products',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: AppTheme.paddingXLarge,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error illustration
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.errorColor.withOpacity(0.1),
                    AppTheme.errorColor.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Icon(
                    Iconsax.warning_2,
                    color: AppTheme.errorColor,
                    size: 30,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Oops, Something Went Wrong!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'We couldn\'t load your orders. This might be due to:\n• Poor internet connection\n• Server maintenance\n• App needs to be updated',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            
            // Action buttons
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _loadOrders(isRefresh: true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Iconsax.refresh, size: 20),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.textSecondary),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                    ),
                  ),
                  icon: const Icon(Iconsax.arrow_left_2, size: 20),
                  label: const Text(
                    'Go Back',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}