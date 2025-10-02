const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  type: {
    type: String,
    enum: ['wallet_credit', 'wallet_debit', 'razorpay_payment', 'order_payment', 'refund'],
    required: true
  },
  amount: {
    type: Number,
    required: true,
    min: 0
  },
  description: {
    type: String,
    required: true,
    trim: true
  },
  status: {
    type: String,
    enum: ['completed', 'pending', 'failed', 'cancelled', 'processing'],
    default: 'pending'
  },
  paymentMethod: {
    type: String,
    enum: ['wallet', 'razorpay', 'upi', 'UPI', 'card', 'netbanking', 'cod'],
    default: 'wallet'
  },
  // Razorpay specific fields
  razorpayPaymentId: {
    type: String,
    default: null
  },
  razorpayOrderId: {
    type: String,
    default: null
  },
  razorpaySignature: {
    type: String,
    default: null
  },
  // Order related fields
  orderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Order',
    default: null
  },
  // Wallet transaction reference
  walletTransactionId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Transaction',
    default: null
  },
  // Additional metadata
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  // Transaction reference for tracking
  referenceId: {
    type: String,
    default: null
  },
  // Failure reason if transaction failed
  failureReason: {
    type: String,
    default: null
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

// Indexes for better performance
transactionSchema.index({ user: 1, createdAt: -1 });
transactionSchema.index({ type: 1 });
transactionSchema.index({ status: 1 });
transactionSchema.index({ razorpayPaymentId: 1 });
transactionSchema.index({ orderId: 1 });
transactionSchema.index({ referenceId: 1 });

// Static method to get user transactions
transactionSchema.statics.getUserTransactions = function(userId, limit = 50, skip = 0) {
  return this.find({ user: userId })
    .sort({ createdAt: -1 })
    .limit(limit)
    .skip(skip)
    .populate('user', 'name email')
    .populate('orderId', 'orderNumber totalAmount')
    .exec();
};

// Static method to get wallet transactions only
transactionSchema.statics.getUserWalletTransactions = function(userId, limit = 50, skip = 0) {
  return this.find({ 
    user: userId,
    type: { $in: ['wallet_credit', 'wallet_debit', 'razorpay_payment'] }
  })
    .sort({ createdAt: -1 })
    .limit(limit)
    .skip(skip)
    .populate('user', 'name email')
    .exec();
};

// Static method to get transaction statistics
transactionSchema.statics.getUserTransactionStats = function(userId) {
  return this.aggregate([
    { $match: { user: mongoose.Types.ObjectId(userId) } },
    {
      $group: {
        _id: null,
        totalCredit: {
          $sum: {
            $cond: [{ $eq: ['$type', 'wallet_credit'] }, '$amount', 0]
          }
        },
        totalDebit: {
          $sum: {
            $cond: [{ $eq: ['$type', 'wallet_debit'] }, '$amount', 0]
          }
        },
        totalRazorpay: {
          $sum: {
            $cond: [{ $eq: ['$type', 'razorpay_payment'] }, '$amount', 0]
          }
        },
        totalTransactions: { $sum: 1 },
        completedTransactions: {
          $sum: {
            $cond: [{ $eq: ['$status', 'completed'] }, 1, 0]
          }
        },
        pendingTransactions: {
          $sum: {
            $cond: [{ $eq: ['$status', 'pending'] }, 1, 0]
          }
        },
        failedTransactions: {
          $sum: {
            $cond: [{ $eq: ['$status', 'failed'] }, 1, 0]
          }
        }
      }
    }
  ]);
};

// Static method to get monthly statistics
transactionSchema.statics.getMonthlyStats = function(userId, year, month) {
  const startDate = new Date(year, month - 1, 1);
  const endDate = new Date(year, month, 0, 23, 59, 59);
  
  return this.aggregate([
    { 
      $match: { 
        user: mongoose.Types.ObjectId(userId),
        createdAt: { $gte: startDate, $lte: endDate }
      } 
    },
    {
      $group: {
        _id: null,
        totalCredit: {
          $sum: {
            $cond: [{ $eq: ['$type', 'wallet_credit'] }, '$amount', 0]
          }
        },
        totalDebit: {
          $sum: {
            $cond: [{ $eq: ['$type', 'wallet_debit'] }, '$amount', 0]
          }
        },
        totalRazorpay: {
          $sum: {
            $cond: [{ $eq: ['$type', 'razorpay_payment'] }, '$amount', 0]
          }
        },
        totalTransactions: { $sum: 1 }
      }
    }
  ]);
};

// Instance method to get transaction summary
transactionSchema.methods.getSummary = function() {
  return {
    id: this._id,
    type: this.type,
    amount: this.amount,
    description: this.description,
    status: this.status,
    paymentMethod: this.paymentMethod,
    referenceId: this.referenceId,
    razorpayPaymentId: this.razorpayPaymentId,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt
  };
};

// Instance method to mark as completed
transactionSchema.methods.markCompleted = function() {
  this.status = 'completed';
  return this.save();
};

// Instance method to mark as failed
transactionSchema.methods.markFailed = function(reason) {
  this.status = 'failed';
  this.failureReason = reason;
  return this.save();
};

module.exports = mongoose.model('Transaction', transactionSchema);
