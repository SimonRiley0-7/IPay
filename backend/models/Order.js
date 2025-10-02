const mongoose = require('mongoose');

const orderSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  orderNumber: {
    type: String,
    required: true,
    unique: true,
    default: function() {
      return `ORD${Date.now()}${Math.floor(Math.random() * 10000)}`;
    }
  },
  numericalID: {
    type: String,
    required: true,
    unique: true,
    default: function() {
      // Generate a random 6-digit number
      return Math.floor(100000 + Math.random() * 900000).toString();
    }
  },
  products: [{
    productId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Product',
      required: true
    },
    name: {
      type: String,
      required: true,
      trim: true
    },
    price: {
      type: Number,
      required: true,
      min: 0
    },
    quantity: {
      type: Number,
      required: true,
      min: 1
    },
    image: {
      type: String,
      default: ''
    },
    category: {
      type: String,
      default: ''
    },
    // Store product details at time of purchase
    productSnapshot: {
      type: mongoose.Schema.Types.Mixed,
      default: {}
    }
  }],
  totalAmount: {
    type: Number,
    required: true,
    min: 0
  },
  paymentMethod: {
    type: String,
    enum: ['razorpay', 'wallet', 'upi', 'card', 'netbanking', 'cod'],
    required: true
  },
  status: {
    type: String,
    enum: ['pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded'],
    default: 'pending'
  },
  // Razorpay specific fields
  razorpayPaymentId: {
    type: String,
    default: null,
    sparse: true
  },
  razorpayOrderId: {
    type: String,
    default: null,
    sparse: true
  },
  razorpaySignature: {
    type: String,
    default: null
  },
  // Wallet transaction reference
  walletTransactionId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Transaction',
    default: null
  },
  // Shipping and delivery info
  shippingAddress: {
    name: String,
    phone: String,
    address: String,
    city: String,
    state: String,
    pincode: String,
    country: {
      type: String,
      default: 'India'
    }
  },
  // Order tracking
  trackingNumber: {
    type: String,
    default: null
  },
  estimatedDelivery: {
    type: Date,
    default: null
  },
  // Additional metadata
  notes: {
    type: String,
    default: ''
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  }
}, {
  timestamps: true,
  toJSON: {
    transform: function(doc, ret) {
      delete ret.__v;
      return ret;
    }
  }
});

// Indexes for efficient querying
orderSchema.index({ user: 1, createdAt: -1 });
orderSchema.index({ orderNumber: 1 });
orderSchema.index({ status: 1 });
orderSchema.index({ paymentMethod: 1 });
orderSchema.index({ razorpayPaymentId: 1 }, { unique: true, sparse: true });

// Generate order number and numerical ID before saving
orderSchema.pre('save', async function(next) {
  if (this.isNew) {
    try {
      // Generate order number
      if (!this.orderNumber) {
        const count = await this.constructor.countDocuments();
        this.orderNumber = `ORD${Date.now()}${String(count + 1).padStart(4, '0')}`;
        console.log('Generated order number:', this.orderNumber);
      }
      
      // Generate numerical ID
      if (!this.numericalID) {
        let numericalID;
        let isUnique = false;
        let attempts = 0;
        const maxAttempts = 10;
        
        while (!isUnique && attempts < maxAttempts) {
          numericalID = Math.floor(100000 + Math.random() * 900000).toString();
          const existingOrder = await this.constructor.findOne({ numericalID });
          if (!existingOrder) {
            isUnique = true;
          }
          attempts++;
        }
        
        if (isUnique) {
          this.numericalID = numericalID;
          console.log('Generated numerical ID:', this.numericalID);
        } else {
          // Fallback: use timestamp-based ID
          this.numericalID = Date.now().toString().slice(-6);
          console.log('Using fallback numerical ID:', this.numericalID);
        }
      }
    } catch (error) {
      console.error('Error generating order identifiers:', error);
      // Fallback order number
      if (!this.orderNumber) {
        this.orderNumber = `ORD${Date.now()}${Math.floor(Math.random() * 10000)}`;
      }
      // Fallback numerical ID
      if (!this.numericalID) {
        this.numericalID = Date.now().toString().slice(-6);
      }
      console.log('Using fallback identifiers - Order:', this.orderNumber, 'Numerical:', this.numericalID);
    }
  }
  next();
});

// Static method to get user's orders
orderSchema.statics.getUserOrders = async function(userId, limit = 20, skip = 0) {
  return this.find({ user: userId })
    .populate('products.productId', 'name price image category')
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(limit);
};

// Static method to get order statistics
orderSchema.statics.getOrderStats = async function(userId) {
  return this.aggregate([
    { $match: { user: userId } },
    {
      $group: {
        _id: null,
        totalOrders: { $sum: 1 },
        totalAmount: { $sum: '$totalAmount' },
        completedOrders: {
          $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] }
        },
        pendingOrders: {
          $sum: { $cond: [{ $eq: ['$status', 'pending'] }, 1, 0] }
        },
        failedOrders: {
          $sum: { $cond: [{ $eq: ['$status', 'failed'] }, 1, 0] }
        },
        razorpayOrders: {
          $sum: { $cond: [{ $eq: ['$paymentMethod', 'razorpay'] }, 1, 0] }
        },
        walletOrders: {
          $sum: { $cond: [{ $eq: ['$paymentMethod', 'wallet'] }, 1, 0] }
        }
      }
    }
  ]);
};

// Instance method to get order summary
orderSchema.methods.getSummary = function() {
  return {
    id: this._id,
    orderNumber: this.orderNumber,
    numericalID: this.numericalID,
    totalAmount: this.totalAmount,
    paymentMethod: this.paymentMethod,
    status: this.status,
    productCount: this.products.length,
    createdAt: this.createdAt,
    razorpayPaymentId: this.razorpayPaymentId,
    walletTransactionId: this.walletTransactionId
  };
};

module.exports = mongoose.model('Order', orderSchema);
