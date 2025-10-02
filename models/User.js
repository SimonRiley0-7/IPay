const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true,
    maxlength: 100
  },
  email: {
    type: String,
    trim: true,
    lowercase: true,
    match: [/^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/, 'Please enter a valid email'],
    sparse: true // Allows null values but ensures uniqueness when present
  },
  phone: {
    type: String,
    trim: true,
    match: [/^\+?[\d\s-()]+$/, 'Please enter a valid phone number'],
    sparse: true // Allows null values but ensures uniqueness when present
  },
  googleId: {
    type: String,
    sparse: true
  },
  firebaseUid: {
    type: String,
    sparse: true
  },
  authProvider: {
    type: String,
    enum: ['phone', 'google', 'both'],
    required: true
  },
  phoneVerified: {
    type: Boolean,
    default: false
  },
  emailVerified: {
    type: Boolean,
    default: false
  },
  profilePicture: {
    type: String,
    default: null
  },
  address: {
    type: String,
    default: null
  },
  // Wallet functionality
  wallet: [{
    transactionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Transaction',
      required: true
    },
    type: {
      type: String,
      enum: ['credit', 'debit', 'refund'],
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
    paymentMethod: {
      type: String,
      enum: ['wallet', 'razorpay', 'upi', 'UPI', 'card', 'netbanking', 'cod'],
      default: 'wallet'
    },
    status: {
      type: String,
      enum: ['completed', 'pending', 'failed', 'cancelled'],
      default: 'completed'
    },
    createdAt: {
      type: Date,
      default: Date.now
    }
  }],
  total_balance: {
    type: Number,
    default: 0.0,
    min: 0
  },
  isActive: {
    type: Boolean,
    default: true
  },
  lastLogin: {
    type: Date,
    default: null
  },
  // Shopping-related fields
  cart: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Cart',
    default: null
  },
  addresses: [{
    type: {
      type: String,
      enum: ['home', 'work', 'other'],
      default: 'home'
    },
    street: String,
    city: String,
    state: String,
    pincode: String,
    country: {
      type: String,
      default: 'India'
    },
    isDefault: {
      type: Boolean,
      default: false
    }
  }],
  preferences: {
    language: {
      type: String,
      default: 'en'
    },
    currency: {
      type: String,
      default: 'INR'
    },
    notifications: {
      email: {
        type: Boolean,
        default: true
      },
      sms: {
        type: Boolean,
        default: true
      },
      push: {
        type: Boolean,
        default: true
      }
    }
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
userSchema.index({ email: 1 });
userSchema.index({ phone: 1 });
userSchema.index({ googleId: 1 });
userSchema.index({ firebaseUid: 1 });
userSchema.index({ createdAt: -1 });

// Virtual for user's full profile
userSchema.virtual('fullProfile').get(function() {
  return {
    id: this._id,
    name: this.name,
    email: this.email,
    phone: this.phone,
    authProvider: this.authProvider,
    phoneVerified: this.phoneVerified,
    emailVerified: this.emailVerified,
    profilePicture: this.profilePicture,
    lastLogin: this.lastLogin,
    createdAt: this.createdAt
  };
});

// Static method to find user by email or phone
userSchema.statics.findByEmailOrPhone = function(identifier) {
  return this.findOne({
    $or: [
      { email: identifier },
      { phone: identifier }
    ]
  });
};

// Static method to find user by Firebase UID
userSchema.statics.findByFirebaseUid = function(uid) {
  return this.findOne({ firebaseUid: uid });
};

// Static method to find user by Google ID
userSchema.statics.findByGoogleId = function(googleId) {
  return this.findOne({ googleId: googleId });
};

// Instance method to update last login
userSchema.methods.updateLastLogin = function() {
  this.lastLogin = new Date();
  return this.save();
};

// Instance method to add address
userSchema.methods.addAddress = function(addressData) {
  // If this is the first address or marked as default, make others non-default
  if (this.addresses.length === 0 || addressData.isDefault) {
    this.addresses.forEach(addr => addr.isDefault = false);
  }
  
  this.addresses.push(addressData);
  return this.save();
};

// Instance method to add money to wallet
userSchema.methods.addToWallet = function(transactionId, amount, description, paymentMethod = 'wallet') {
  if (amount <= 0) {
    throw new Error('Amount must be positive');
  }
  
  // Add to wallet array
  this.wallet.push({
    transactionId: transactionId,
    type: 'credit',
    amount: amount,
    description: description,
    paymentMethod: paymentMethod,
    status: 'completed'
  });
  
  // Update total balance
  this.total_balance += amount;
  return this.save();
};

// Instance method to deduct money from wallet
userSchema.methods.deductFromWallet = function(transactionId, amount, description, paymentMethod = 'wallet') {
  if (amount <= 0) {
    throw new Error('Amount must be positive');
  }
  if (this.total_balance < amount) {
    throw new Error('Insufficient wallet balance');
  }
  
  // Add to wallet array
  this.wallet.push({
    transactionId: transactionId,
    type: 'debit',
    amount: amount,
    description: description,
    paymentMethod: paymentMethod,
    status: 'completed'
  });
  
  // Update total balance
  this.total_balance -= amount;
  return this.save();
};

// Instance method to get wallet balance
userSchema.methods.getWalletBalance = function() {
  return this.total_balance;
};

// Instance method to get wallet transactions
userSchema.methods.getWalletTransactions = function(limit = 50) {
  return this.wallet
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
    .slice(0, limit);
};

// Instance method to get safe user data (without sensitive info)
userSchema.methods.getSafeUserData = function() {
  return {
    id: this._id,
    name: this.name,
    email: this.email,
    phone: this.phone,
    authProvider: this.authProvider,
    phoneVerified: this.phoneVerified,
    emailVerified: this.emailVerified,
    profilePicture: this.profilePicture,
    address: this.address,
    wallet: this.wallet,
    total_balance: this.total_balance,
    isActive: this.isActive,
    preferences: this.preferences,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt
  };
};

module.exports = mongoose.model('User', userSchema);


