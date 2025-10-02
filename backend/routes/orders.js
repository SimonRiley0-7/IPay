const express = require('express');
const { body, validationResult } = require('express-validator');
const Order = require('../models/Order');
const User = require('../models/User');
const Transaction = require('../models/Transaction');
const { verifyJWTToken } = require('../middleware/auth');

const router = express.Router();

// @route   POST /api/orders/create
// @desc    Create a new order
// @access  Private
router.post('/create', [
  verifyJWTToken,
  body('products').isArray().withMessage('Products must be an array'),
  body('products.*.productId').isMongoId().withMessage('Invalid product ID'),
  body('products.*.name').notEmpty().withMessage('Product name is required'),
  body('products.*.price').isNumeric().withMessage('Product price must be a number'),
  body('products.*.quantity').isInt({ min: 1 }).withMessage('Quantity must be at least 1'),
  body('totalAmount').isNumeric().withMessage('Total amount must be a number'),
  body('paymentMethod').isIn(['razorpay', 'wallet', 'upi', 'card', 'netbanking', 'cod']).withMessage('Invalid payment method'),
  body('shippingAddress').optional().isObject().withMessage('Shipping address must be an object'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        success: false, 
        message: 'Validation failed', 
        errors: errors.array() 
      });
    }

    const { 
      products, 
      totalAmount, 
      paymentMethod, 
      shippingAddress,
      razorpayPaymentId,
      razorpayOrderId,
      razorpaySignature,
      notes 
    } = req.body;
    const user = req.user;

    console.log('Creating order for user:', user._id);
    console.log('Order details:', { products: products.length, totalAmount, paymentMethod });
    console.log('Products data:', products);

    // Validate products
    if (!products || products.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Order must contain at least one product'
      });
    }

    // Check if user has sufficient wallet balance for wallet payment
    if (paymentMethod === 'wallet') {
      const userDoc = await User.findById(user._id);
      if (!userDoc) {
        return res.status(404).json({
          success: false,
          message: 'User not found'
        });
      }

      if (userDoc.total_balance < totalAmount) {
        return res.status(400).json({
          success: false,
          message: 'Insufficient wallet balance',
          data: {
            required: totalAmount,
            available: userDoc.total_balance,
            shortfall: totalAmount - userDoc.total_balance
          }
        });
      }
    }

    // Create order
    const orderData = {
      user: user._id,
      products: products.map(product => ({
        productId: product.productId,
        name: product.name,
        price: product.price,
        quantity: product.quantity,
        image: product.image || '',
        category: product.category || '',
        productSnapshot: product.productSnapshot || {}
      })),
      totalAmount,
      paymentMethod,
      shippingAddress: shippingAddress || {},
      notes: notes || ''
    };

    // Add Razorpay fields if payment method is razorpay
    if (paymentMethod === 'razorpay') {
      orderData.razorpayPaymentId = razorpayPaymentId;
      orderData.razorpayOrderId = razorpayOrderId;
      orderData.razorpaySignature = razorpaySignature;
      orderData.status = 'completed'; // Razorpay payments are considered completed
    }

    const order = new Order(orderData);
    await order.save();

    // If wallet payment, deduct from wallet and create transaction
    if (paymentMethod === 'wallet') {
      try {
        // Get fresh user document for wallet operations
        const userDoc = await User.findById(user._id);
        if (!userDoc) {
          throw new Error('User not found for wallet operations');
        }

        // Create wallet transaction
        const walletTransaction = new Transaction({
          user: user._id,
          type: 'wallet_debit',
          amount: totalAmount,
          description: `Payment for order ${order.orderNumber}`,
          status: 'completed',
          paymentMethod: 'wallet',
          orderId: order._id,
          referenceId: `order_${order.orderNumber}`
        });
        await walletTransaction.save();

        // Deduct from user's wallet
        await userDoc.deductFromWallet(
          walletTransaction._id,
          totalAmount,
          `Payment for order ${order.orderNumber}`,
          'wallet'
        );

        // Update order with wallet transaction reference
        order.walletTransactionId = walletTransaction._id;
        order.status = 'completed';
        await order.save();

        console.log('Wallet payment processed successfully');
      } catch (walletError) {
        console.error('Wallet payment error:', walletError);
        console.error('Error stack:', walletError.stack);
        console.error('Order ID:', order._id);
        console.error('User ID:', user._id);
        console.error('Amount:', totalAmount);
        
        // If wallet deduction fails, mark order as failed
        order.status = 'failed';
        await order.save();
        
        return res.status(500).json({
          success: false,
          message: 'Failed to process wallet payment',
          error: process.env.NODE_ENV === 'development' ? walletError.message : undefined
        });
      }
    }

    // Populate order with product details
    await order.populate('products.productId', 'name price image category');

    res.status(201).json({
      success: true,
      message: 'Order created successfully',
      order: order
    });

  } catch (error) {
    console.error('Create order error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create order',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// @route   GET /api/orders
// @desc    Get user's orders
// @access  Private
router.get('/', [
  verifyJWTToken
], async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;
    const userId = req.user._id;

    const orders = await Order.getUserOrders(userId, parseInt(limit), skip);
    const totalOrders = await Order.countDocuments({ user: userId });

    res.json({
      success: true,
      data: {
        orders,
        pagination: {
          currentPage: parseInt(page),
          totalPages: Math.ceil(totalOrders / limit),
          totalOrders,
          hasNext: skip + orders.length < totalOrders,
          hasPrev: page > 1
        }
      }
    });

  } catch (error) {
    console.error('Get orders error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch orders'
    });
  }
});

// @route   GET /api/orders/:id
// @desc    Get specific order details
// @access  Private
router.get('/:id', [
  verifyJWTToken
], async (req, res) => {
  try {
    const orderId = req.params.id;
    const userId = req.user._id;

    const order = await Order.findOne({ 
      _id: orderId, 
      user: userId 
    }).populate('products.productId', 'name price image category');

    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }

    res.json({
      success: true,
      data: { order }
    });

  } catch (error) {
    console.error('Get order error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch order'
    });
  }
});

// @route   GET /api/orders/stats/summary
// @desc    Get user's order statistics
// @access  Private
router.get('/stats/summary', [
  verifyJWTToken
], async (req, res) => {
  try {
    const userId = req.user._id;
    const stats = await Order.getOrderStats(userId);

    res.json({
      success: true,
      data: {
        stats: stats[0] || {
          totalOrders: 0,
          totalAmount: 0,
          completedOrders: 0,
          pendingOrders: 0,
          failedOrders: 0,
          razorpayOrders: 0,
          walletOrders: 0
        }
      }
    });

  } catch (error) {
    console.error('Get order stats error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch order statistics'
    });
  }
});

// @route   PUT /api/orders/:id/status
// @desc    Update order status (admin only - for future use)
// @access  Private
router.put('/:id/status', [
  verifyJWTToken,
  body('status').isIn(['pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded']).withMessage('Invalid status')
], async (req, res) => {
  try {
    const orderId = req.params.id;
    const { status } = req.body;
    const userId = req.user._id;

    const order = await Order.findOneAndUpdate(
      { _id: orderId, user: userId },
      { status },
      { new: true }
    );

    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }

    res.json({
      success: true,
      message: 'Order status updated successfully',
      data: { order: order.getSummary() }
    });

  } catch (error) {
    console.error('Update order status error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update order status'
    });
  }
});

module.exports = router;
