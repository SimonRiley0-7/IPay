import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ipay/services/auth_service.dart';
import 'package:ipay/services/razorpay_service.dart';
import 'package:ipay/services/wallet_service.dart';
import 'package:ipay/widgets/bottom_navigation_bar.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:iconsax/iconsax.dart';

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
  
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXLarge = 20.0;
  
  static const EdgeInsets paddingSmall = EdgeInsets.all(8.0);
  static const EdgeInsets paddingMedium = EdgeInsets.all(16.0);
  static const EdgeInsets paddingLarge = EdgeInsets.all(20.0);
  static const EdgeInsets paddingXLarge = EdgeInsets.all(24.0);
}

// WalletTransaction is now imported from razorpay_service.dart

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final RazorpayService _razorpayService = RazorpayService();
  final WalletService _walletService = WalletService();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Wallet data
  double _walletBalance = 0.0;
  bool _isLoading = true;
  bool _isAddingMoney = false;
  
  // Transaction data
  List<WalletTransaction> _transactions = [];
  bool _isLoadingTransactions = false;
  
  // Add money dialog
  final TextEditingController _amountController = TextEditingController();
  final List<String> _paymentMethods = ['UPI', 'Credit Card', 'Debit Card', 'Net Banking'];
  String _selectedPaymentMethod = 'UPI';
  double _pendingPaymentAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeRazorpay();
    _loadWalletData();
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

  Future<void> _initializeRazorpay() async {
    await _razorpayService.initialize();
    _razorpayService.onPaymentSuccess = _handlePaymentSuccess;
    _razorpayService.onPaymentError = _handlePaymentError;
    // _razorpayService.onExternalWalletSelected = _handleExternalWalletSelected;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _amountController.dispose();
    _razorpayService.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load wallet balance from wallet service
      final balance = await _walletService.getWalletBalance();
      
      setState(() {
        _walletBalance = balance;
        _isLoading = false;
      });
      _animationController.forward();
      _loadTransactions();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load wallet data: $e');
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoadingTransactions = true;
    });

    try {
      // Load transactions from wallet service
      final transactions = await _walletService.getTransactions();
      
      print('Loaded ${transactions.length} transactions from backend');
      for (var transaction in transactions) {
        print('Transaction: ${transaction.type} - ${transaction.amount} - ${transaction.description}');
      }
      
      setState(() {
        _transactions = transactions;
        _isLoadingTransactions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTransactions = false;
      });
      print('Error loading transactions: $e');
      _showErrorSnackBar('Failed to load transactions: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Razorpay payment callbacks
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('Payment Success: ${response.paymentId}');
    print('Payment Response: ${response.toString()}');
    
    // Extract payment details
    final paymentId = response.paymentId ?? '';
    final orderId = response.orderId ?? 'order_${DateTime.now().millisecondsSinceEpoch}';
    final signature = response.signature ?? 'sig_${DateTime.now().millisecondsSinceEpoch}';
    
    print('Extracted - PaymentId: $paymentId, OrderId: $orderId, Signature: $signature');
    
    // Use the stored amount from the payment initiation
    final amount = _pendingPaymentAmount;
    
    // Add money to wallet and create transaction
    _processSuccessfulPayment(
      amount: amount,
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('Payment Error: ${response.code} - ${response.message}');
    _showErrorSnackBar('Payment failed: ${response.message}');
  }

  // void _handleExternalWalletSelected(PaymentExternalWalletResponse response) {
  //   print('External Wallet Selected: ${response.walletName}');
  //   _showSuccessSnackBar('External wallet selected: ${response.walletName}');
  // }

  Future<void> _processSuccessfulPayment({
    required double amount,
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      // Add money transaction to wallet
      final success = await _walletService.addMoneyTransaction(
        amount: amount,
        paymentMethod: _selectedPaymentMethod,
        razorpayPaymentId: paymentId,
        razorpayOrderId: orderId,
        razorpaySignature: signature,
      );

      if (success) {
        // Refresh wallet data
        await _loadWalletData();
        await _loadTransactions();
        
        _showSuccessSnackBar('₹${amount.toStringAsFixed(0)} added to wallet successfully!');
        HapticFeedback.lightImpact();
      } else {
        _showErrorSnackBar('Failed to update wallet balance');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to process payment: $e');
    }
  }

  void _showAddMoneyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Iconsax.wallet_3,
                              color: AppTheme.primaryGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Add Money',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              _amountController.clear();
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Iconsax.close_circle,
                                color: AppTheme.textSecondary,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        children: [
                          // Amount input
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.textPrimary,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              hintText: 'Enter amount',
                              prefixText: '₹ ',
                              prefixStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryGreen,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryGreen,
                                  width: 1,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              labelStyle: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                              hintStyle: TextStyle(
                                color: AppTheme.textTertiary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Payment method selection
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Payment Method',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Payment method options
                          ..._paymentMethods.map((method) => 
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: _selectedPaymentMethod == method 
                                    ? AppTheme.primaryGreen.withOpacity(0.05)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedPaymentMethod == method 
                                      ? AppTheme.primaryGreen.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: RadioListTile<String>(
                                title: Text(
                                  method,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: _selectedPaymentMethod == method 
                                        ? AppTheme.primaryGreen
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                                value: method,
                                groupValue: _selectedPaymentMethod,
                                onChanged: (value) {
                                  setDialogState(() {
                                    _selectedPaymentMethod = value!;
                                  });
                                },
                                activeColor: AppTheme.primaryGreen,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ).toList(),
                        ],
                      ),
                    ),
                    
                    // Actions
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          // Cancel button
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _amountController.clear();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.textSecondary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Add Money button
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isAddingMoney ? null : _handleAddMoney,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              child: _isAddingMoney
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Add Money',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleAddMoney() async {
    final amount = double.tryParse(_amountController.text);
    
    if (amount == null || amount <= 0) {
      _showErrorSnackBar('Please enter a valid amount');
      return;
    }
    
    if (amount < 10) {
      _showErrorSnackBar('Minimum amount is ₹10');
      return;
    }
    
    if (amount > 50000) {
      _showErrorSnackBar('Maximum amount is ₹50,000');
      return;
    }
    
    setState(() {
      _isAddingMoney = true;
    });
    
    try {
      // Get user data for payment
      final userData = await _authService.getStoredUserData();
      final email = userData?['email'] ?? 'user@example.com';
      final name = userData?['name'] ?? 'User';
      final phone = userData?['phone'] ?? '+919876543210';
      
      // Store the amount for later use in payment success callback
      _pendingPaymentAmount = amount;
      
      // Close dialog first
      Navigator.of(context).pop();
      _amountController.clear();
      
      // Open Razorpay payment gateway
      await _razorpayService.openPaymentGateway(
        amount: amount,
        description: 'Add money to iPay wallet',
        userEmail: email,
        userName: name,
        userPhone: phone,
      );
      
      setState(() {
        _isAddingMoney = false;
      });
    } catch (e) {
      setState(() {
        _isAddingMoney = false;
      });
      _showErrorSnackBar('Failed to open payment gateway: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('💰 WalletScreen: Building WalletScreen widget');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
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
                                _buildWalletBalanceCard(),
                                const SizedBox(height: 24),
                                _buildAddMoneyButton(),
                                const SizedBox(height: 32),
                                _buildTransactionsHeader(),
                                const SizedBox(height: 16),
                                _buildTransactionsList(),
                                const SizedBox(height: 40), // Bottom padding
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
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: 2, // Wallet tab
        onTap: (index) {
          if (index != 2) {
            Navigator.pop(context);
          }
        },
        cartItemCount: 0,
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
          ),
          SizedBox(height: 16),
          Text(
            'Loading wallet...',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Wallet',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        background: Container(
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildWalletBalanceCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
            blurRadius: 20,
            offset: const Offset(0, 8),
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
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Iconsax.wallet_3,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Wallet Balance',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Text(
              '₹${_walletBalance.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -1.0,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Available for payments',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMoneyButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreenLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          onTap: _showAddMoneyDialog,
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.add_circle,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Add Money',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Iconsax.clock,
            color: AppTheme.primaryGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Transaction History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList() {
    if (_isLoadingTransactions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.receipt_2,
                size: 40,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your wallet transactions will appear here\nAdd money to get started!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddMoneyDialog,
              icon: const Icon(Iconsax.add_circle, size: 20),
              label: const Text('Add Money'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _transactions.map((transaction) => 
        _buildTransactionItem(transaction)
      ).toList(),
    );
  }

  Widget _buildTransactionItem(WalletTransaction transaction) {
    final isCredit = transaction.type == 'credit' || transaction.type == 'wallet_credit' || transaction.type == 'razorpay_payment';
    final isCompleted = transaction.status == 'completed';
    
    // Map transaction types to better descriptions
    String getTransactionTypeDescription() {
      switch (transaction.type) {
        case 'wallet_credit':
          return 'Money Added to Wallet';
        case 'razorpay_payment':
          return 'Money Added via Razorpay';
        case 'wallet_debit':
          return 'Money Spent from Wallet';
        case 'refund':
          return 'Refund Received';
        default:
          return isCredit ? 'Credit' : 'Debit';
      }
    }
    
    // Get appropriate icon
    IconData getTransactionIcon() {
      switch (transaction.type) {
        case 'wallet_credit':
          return Iconsax.wallet_3;
        case 'razorpay_payment':
          return Iconsax.card;
        case 'wallet_debit':
          return Iconsax.shopping_cart;
        case 'refund':
          return Iconsax.refresh;
        default:
          return isCredit ? Iconsax.add_circle : Iconsax.minus;
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
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
        padding: AppTheme.paddingLarge,
        child: Row(
          children: [
            // Transaction icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCredit 
                    ? AppTheme.successColor.withOpacity(0.1)
                    : AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                getTransactionIcon(),
                color: isCredit ? AppTheme.successColor : AppTheme.errorColor,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description.isNotEmpty ? transaction.description : getTransactionTypeDescription(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Row(
                    children: [
                      Text(
                        _formatDate(transaction.timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppTheme.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        transaction.paymentMethod ?? 'Wallet',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  
                  
                ],
              ),
            ),
            
            // Amount and status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isCredit ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? AppTheme.successColor.withOpacity(0.1)
                        : AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    transaction.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? AppTheme.successColor : AppTheme.warningColor,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
