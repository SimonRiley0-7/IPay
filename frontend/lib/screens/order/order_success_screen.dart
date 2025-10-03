import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../main_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final String paymentMethod;
  final double totalAmount;

  const OrderSuccessScreen({
    Key? key,
    required this.orderData,
    required this.paymentMethod,
    required this.totalAmount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Debug print to see what data we're receiving
    print('Order Success Screen - Order Data: $orderData');
    print('Order Success Screen - Payment Method: $paymentMethod');
    print('Order Success Screen - Total Amount: $totalAmount');
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Success Animation
              _buildSuccessAnimation(),
              
              const SizedBox(height: 32),
              
              // Payment Completed Text
              _buildSuccessText(),
              
              const SizedBox(height: 24),
              
              // Order Details Card
              _buildOrderDetailsCard(),
              
              const SizedBox(height: 32),
              
              // Payment Method Card
              _buildPaymentMethodCard(),
              
              const Spacer(),
              
              // Action Buttons
              _buildActionButtons(context),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF4A9B8E).withOpacity(0.1),
      ),
      child: const Icon(
        Iconsax.tick_circle,
        size: 60,
        color: Color(0xFF4A9B8E),
      ),
    );
  }

  Widget _buildSuccessText() {
    return Column(
      children: [
        const Text(
          'Payment Completed!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D3748),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your payment has been processed successfully',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
            letterSpacing: -0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOrderDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Iconsax.receipt_2,
                size: 20,
                color: Color(0xFF4A9B8E),
              ),
              const SizedBox(width: 8),
              const Text(
                'Order Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildDetailRow('Order ID', orderData['orderNumber'] ?? 'N/A'),
          const SizedBox(height: 12),
          _buildDetailRow('Order Date', _formatDate(orderData['createdAt'])),
          const SizedBox(height: 12),
          _buildDetailRow('Total Items', '${orderData['products']?.length ?? 0} items'),
          const SizedBox(height: 12),
          _buildDetailRow('Total Amount', '₹${_formatCurrency(orderData['totalAmount']?.toDouble() ?? totalAmount)}'),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                paymentMethod == 'wallet' ? Iconsax.wallet_3 : Iconsax.card,
                size: 20,
                color: const Color(0xFF4A9B8E),
              ),
              const SizedBox(width: 8),
              const Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A9B8E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  paymentMethod.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A9B8E),
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Iconsax.tick_circle,
                size: 20,
                color: Color(0xFF4A9B8E),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Continue Shopping Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              // Navigate to home screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MainScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A9B8E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              shadowColor: const Color(0xFF4A9B8E).withOpacity(0.3),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.shop, size: 22),
                SizedBox(width: 12),
                Text(
                  'Continue Shopping',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // View Orders Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () {
              // Navigate to main screen and then to orders tab
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MainScreen()),
                (route) => false,
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4A9B8E),
              side: const BorderSide(
                color: Color(0xFF4A9B8E),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.receipt_2, size: 22),
                SizedBox(width: 12),
                Text(
                  'View My Orders',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    
    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return 'N/A';
      }
      
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }
}
