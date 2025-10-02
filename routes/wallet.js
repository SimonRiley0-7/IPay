const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Transaction = require('../models/Transaction');
const { verifyJWTToken } = require('../middleware/auth');
const { body, validationResult } = require('express-validator');

// @route   GET /api/wallet/balance
// @desc    Get user's wallet balance
// @access  Private
router.get('/balance', verifyJWTToken, async (req, res) => {
  try {
    const user = req.user;
    
    res.json({
      success: true,
      data: {
        balance: user.total_balance,
        userId: user._id,
        walletTransactions: user.wallet.length
      }
    });
  } catch (error) {
    console.error('Get wallet balance error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error while fetching wallet balance'
    });
  }
});

// @route   POST /api/wallet/add-money
// @desc    Add money to wallet via Razorpay
// @access  Private
router.post('/add-money', [
  verifyJWTToken,
  body('amount').isNumeric().withMessage('Amount must be a number'),
  body('amount').isFloat({ min: 1 }).withMessage('Amount must be at least ₹1'),
  body('paymentMethod').notEmpty().withMessage('Payment method is required'),
  body('razorpayPaymentId').notEmpty().withMessage('Razorpay payment ID is required'),
  // Make orderId and signature optional since Razorpay might not always provide them
  body('razorpayOrderId').optional().isString().withMessage('Razorpay order ID must be a string'),
  body('razorpaySignature').optional().isString().withMessage('Razorpay signature must be a string'),
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const { amount, paymentMethod, razorpayPaymentId, razorpayOrderId, razorpaySignature } = req.body;
    const user = req.user;

    console.log('Add money request received:', {
      amount,
      paymentMethod,
      razorpayPaymentId,
      razorpayOrderId,
      razorpaySignature,
      userId: user._id
    });

    // Check if transaction already exists (prevent duplicate)
    const existingTransaction = await Transaction.findOne({
      razorpayPaymentId: razorpayPaymentId,
      user: user._id
    });

    if (existingTransaction) {
      return res.status(400).json({
        success: false,
        message: 'Transaction already processed'
      });
    }

    // Create main transaction record first
    const transaction = new Transaction({
      user: user._id,
      type: 'razorpay_payment',
      amount: amount,
      description: `Added money via ${paymentMethod}`,
      status: 'completed',
      paymentMethod: paymentMethod,
      referenceId: razorpayPaymentId,
      razorpayPaymentId: razorpayPaymentId,
      razorpayOrderId: razorpayOrderId || null,
      razorpaySignature: razorpaySignature || null
    });

    await transaction.save();

    // Add to user's wallet array and update balance
    await user.addToWallet(
      transaction._id,
      amount,
      `Added money via ${paymentMethod}`,
      paymentMethod
    );

    res.json({
      success: true,
      message: 'Money added to wallet successfully',
      data: {
        newBalance: user.total_balance,
        transaction: transaction.getSummary(),
        walletTransaction: {
          id: transaction._id,
          type: 'credit',
          amount: amount,
          description: `Added money via ${paymentMethod}`,
          createdAt: transaction.createdAt
        }
      }
    });
  } catch (error) {
    console.error('Add money to wallet error:', error);
    console.error('Error stack:', error.stack);
    console.error('Request body:', req.body);
    console.error('User:', req.user ? req.user._id : 'No user');
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error while adding money to wallet',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// @route   POST /api/wallet/deduct-money
// @desc    Deduct money from wallet (for purchases)
// @access  Private
router.post('/deduct-money', [
  verifyJWTToken,
  body('amount').isNumeric().withMessage('Amount must be a number'),
  body('amount').isFloat({ min: 1 }).withMessage('Amount must be at least ₹1'),
  body('description').notEmpty().withMessage('Description is required'),
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const { amount, description, orderId } = req.body;
    const user = req.user;

    // Check if user has sufficient balance
    if (user.total_balance < amount) {
      return res.status(400).json({
        success: false,
        message: 'Insufficient wallet balance'
      });
    }

    // Create main transaction record first
    const transaction = new Transaction({
      user: user._id,
      type: 'wallet_debit',
      amount: amount,
      description: description,
      status: 'completed',
      paymentMethod: 'wallet',
      orderId: orderId || null
    });

    await transaction.save();

    // Deduct from user's wallet array and update balance
    await user.deductFromWallet(
      transaction._id,
      amount,
      description,
      'wallet'
    );

    res.json({
      success: true,
      message: 'Money deducted from wallet successfully',
      data: {
        newBalance: user.total_balance,
        transaction: transaction.getSummary(),
        walletTransaction: {
          id: transaction._id,
          type: 'debit',
          amount: amount,
          description: description,
          createdAt: transaction.createdAt
        }
      }
    });
  } catch (error) {
    console.error('Deduct money from wallet error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error while deducting money from wallet'
    });
  }
});

// @route   GET /api/wallet/transactions
// @desc    Get user's wallet transactions
// @access  Private
router.get('/transactions', verifyJWTToken, async (req, res) => {
  try {
    const user = req.user;
    const { limit = 50, skip = 0 } = req.query;

    // Get wallet transactions from user's embedded array
    const walletTransactions = user.getWalletTransactions(parseInt(limit));
    
    // Also get all transactions from Transaction collection for complete history
    const allTransactions = await Transaction.getUserWalletTransactions(
      user._id,
      parseInt(limit),
      parseInt(skip)
    );

    res.json({
      success: true,
      data: {
        walletTransactions: walletTransactions,
        allTransactions: allTransactions.map(t => t.getSummary()),
        total: walletTransactions.length
      }
    });
  } catch (error) {
    console.error('Get wallet transactions error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error while fetching transactions'
    });
  }
});

// @route   GET /api/wallet/stats
// @desc    Get user's wallet transaction statistics
// @access  Private
router.get('/stats', verifyJWTToken, async (req, res) => {
  try {
    const user = req.user;

    const stats = await Transaction.getUserTransactionStats(user._id);
    const userStats = stats[0] || {
      totalCredit: 0,
      totalDebit: 0,
      totalRazorpay: 0,
      totalTransactions: 0,
      completedTransactions: 0,
      pendingTransactions: 0,
      failedTransactions: 0
    };

    res.json({
      success: true,
      data: {
        currentBalance: user.total_balance,
        totalAdded: userStats.totalCredit,
        totalSpent: userStats.totalDebit,
        totalRazorpay: userStats.totalRazorpay,
        totalTransactions: userStats.totalTransactions,
        completedTransactions: userStats.completedTransactions,
        pendingTransactions: userStats.pendingTransactions,
        failedTransactions: userStats.failedTransactions,
        walletTransactionCount: user.wallet.length
      }
    });
  } catch (error) {
    console.error('Get wallet stats error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error while fetching wallet statistics'
    });
  }
});

module.exports = router;
