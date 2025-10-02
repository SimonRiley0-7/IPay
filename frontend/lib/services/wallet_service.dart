import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:ipay/services/razorpay_service.dart';
import 'package:dio/dio.dart';
import 'package:ipay/config/api_config.dart';
import 'package:ipay/services/auth_service.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal() {
    _dio.options.baseUrl = '${ApiConfig.baseUrl.replaceAll('/auth', '')}/wallet';
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

  static const String _walletBalanceKey = 'wallet_balance';
  static const String _transactionsKey = 'wallet_transactions';

  // Get current wallet balance
  Future<double> getWalletBalance() async {
    try {
      // Try to get from backend first
      final response = await _dio.get('/balance');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final balance = (response.data['data']['balance'] as num).toDouble();
        // Cache the balance locally
        await _cacheWalletBalance(balance);
        return balance;
      }
    } catch (e) {
      print('Error getting wallet balance from backend: $e');
      // Fallback to local storage
      return await _getCachedWalletBalance();
    }
    
    // Fallback to local storage
    return await _getCachedWalletBalance();
  }

  // Cache wallet balance locally
  Future<void> _cacheWalletBalance(double balance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_walletBalanceKey, balance);
    } catch (e) {
      print('Error caching wallet balance: $e');
    }
  }

  // Get cached wallet balance
  Future<double> _getCachedWalletBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_walletBalanceKey) ?? 0.0;
    } catch (e) {
      print('Error getting cached wallet balance: $e');
      return 0.0;
    }
  }

  // Update wallet balance
  Future<bool> updateWalletBalance(double newBalance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_walletBalanceKey, newBalance);
      return true;
    } catch (e) {
      print('Error updating wallet balance: $e');
      return false;
    }
  }

  // Add money to wallet
  Future<bool> addMoneyToWallet(double amount) async {
    try {
      final currentBalance = await getWalletBalance();
      final newBalance = currentBalance + amount;
      return await updateWalletBalance(newBalance);
    } catch (e) {
      print('Error adding money to wallet: $e');
      return false;
    }
  }

  // Deduct money from wallet
  Future<bool> deductMoneyFromWallet(double amount) async {
    try {
      final currentBalance = await getWalletBalance();
      if (currentBalance >= amount) {
        final newBalance = currentBalance - amount;
        return await updateWalletBalance(newBalance);
      }
      return false; // Insufficient balance
    } catch (e) {
      print('Error deducting money from wallet: $e');
      return false;
    }
  }

  // Get all transactions
  Future<List<WalletTransaction>> getTransactions() async {
    try {
      // Try to get from backend first
      final response = await _dio.get('/transactions');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final transactionsData = response.data['data']['allTransactions'] as List;
        return transactionsData.map((json) => WalletTransaction.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error getting transactions from backend: $e');
      // Fallback to local storage
      return await _getCachedTransactions();
    }
    
    // Fallback to local storage
    return await _getCachedTransactions();
  }

  // Get cached transactions
  Future<List<WalletTransaction>> _getCachedTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionsJson = prefs.getStringList(_transactionsKey) ?? [];
      
      return transactionsJson.map((jsonString) {
        final json = jsonDecode(jsonString);
        return WalletTransaction.fromJson(json);
      }).toList();
    } catch (e) {
      print('Error getting cached transactions: $e');
      return [];
    }
  }

  // Add a new transaction
  Future<bool> addTransaction(WalletTransaction transaction) async {
    try {
      final transactions = await getTransactions();
      transactions.insert(0, transaction); // Add to beginning of list
      
      final prefs = await SharedPreferences.getInstance();
      final transactionsJson = transactions.map((t) => jsonEncode(t.toJson())).toList();
      
      await prefs.setStringList(_transactionsKey, transactionsJson);
      return true;
    } catch (e) {
      print('Error adding transaction: $e');
      return false;
    }
  }

  // Add money transaction (for Razorpay payments)
  Future<bool> addMoneyTransaction({
    required double amount,
    required String paymentMethod,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    try {
      final requestData = {
        'amount': amount,
        'paymentMethod': paymentMethod,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpayOrderId': razorpayOrderId,
        'razorpaySignature': razorpaySignature,
      };
      
      print('Sending add-money request: $requestData');
      
      // Send to backend API
      final response = await _dio.post('/add-money', data: requestData);

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Update local cache
        final newBalance = (response.data['data']['newBalance'] as num).toDouble();
        await _cacheWalletBalance(newBalance);
        
        // Add transaction to local history for offline viewing
        final transaction = WalletTransaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'credit',
          amount: amount,
          description: 'Added money via $paymentMethod',
          timestamp: DateTime.now(),
          status: 'completed',
          referenceId: razorpayPaymentId,
          paymentMethod: paymentMethod,
          razorpayPaymentId: razorpayPaymentId,
          razorpayOrderId: razorpayOrderId,
          razorpaySignature: razorpaySignature,
        );
        await addTransaction(transaction);
        
        return true;
      }
      return false;
    } catch (e) {
      print('Error adding money transaction: $e');
      return false;
    }
  }

  // Clear all data (for testing)
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_walletBalanceKey);
      await prefs.remove(_transactionsKey);
    } catch (e) {
      print('Error clearing wallet data: $e');
    }
  }

  // Get transaction statistics
  Future<Map<String, dynamic>> getTransactionStats() async {
    try {
      final transactions = await getTransactions();
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month);
      
      double totalAdded = 0;
      double totalSpent = 0;
      double thisMonthAdded = 0;
      double thisMonthSpent = 0;
      
      for (final transaction in transactions) {
        if (transaction.type == 'credit') {
          totalAdded += transaction.amount;
          if (transaction.timestamp.isAfter(thisMonth)) {
            thisMonthAdded += transaction.amount;
          }
        } else if (transaction.type == 'debit') {
          totalSpent += transaction.amount;
          if (transaction.timestamp.isAfter(thisMonth)) {
            thisMonthSpent += transaction.amount;
          }
        }
      }
      
      return {
        'totalAdded': totalAdded,
        'totalSpent': totalSpent,
        'thisMonthAdded': thisMonthAdded,
        'thisMonthSpent': thisMonthSpent,
        'totalTransactions': transactions.length,
      };
    } catch (e) {
      print('Error getting transaction stats: $e');
      return {
        'totalAdded': 0.0,
        'totalSpent': 0.0,
        'thisMonthAdded': 0.0,
        'thisMonthSpent': 0.0,
        'totalTransactions': 0,
      };
    }
  }
}
