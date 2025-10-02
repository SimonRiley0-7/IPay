const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const router = express.Router();
const User = require('../models/User');

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadsDir = path.join(__dirname, '../uploads');
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }
    cb(null, uploadsDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'profile-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed!'), false);
    }
  }
});
const { 
  verifyFirebaseToken, 
  verifyJWTToken, 
  generateJWTToken,
  firebaseAdmin 
} = require('../middleware/auth');
const {
  validatePhoneLogin,
  validateGoogleLogin,
  validateUserRegistration,
  validateFirebaseToken
} = require('../middleware/validation');
const {
  verifyFirebaseGoogleToken,
  createUserProfileFromGoogle
} = require('../utils/googleAuth');
const twilioService = require('../utils/twilioService');

// @route   GET /api/auth
// @desc    Get auth service info
// @access  Public
router.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'iPay Auth Service',
    version: '1.0.0',
    status: 'Running',
    timestamp: new Date().toISOString(),
    endpoints: {
      test: '/api/auth/test',
      google: '/api/auth/google',
      register: '/api/auth/register',
      login: '/api/auth/login',
      verify: '/api/auth/verify',
      me: '/api/auth/me'
    }
  });
});

// @route   GET /api/auth/test
// @desc    Test endpoint for mobile connectivity
// @access  Public
router.get('/test', (req, res) => {
  console.log('🧪 Test endpoint hit from:', req.ip);
  res.json({
    success: true,
    message: 'Backend connection successful!',
    timestamp: new Date().toISOString(),
    clientIP: req.ip
  });
});

// @route   GET /api/auth/razorpay-config
// @desc    Get Razorpay configuration for frontend
// @access  Public
router.get('/razorpay-config', (req, res) => {
  try {
    const razorpayConfig = {
      keyId: process.env.RAZORPAY_KEY_ID,
      environment: process.env.NODE_ENV === 'production' ? 'production' : 'test'
    };
    
    if (!razorpayConfig.keyId) {
      return res.status(500).json({
        success: false,
        message: 'Razorpay configuration not found'
      });
    }
    
    res.json({
      success: true,
      data: razorpayConfig
    });
  } catch (error) {
    console.error('Razorpay config error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get Razorpay configuration'
    });
  }
});

// @route   POST /api/auth/send-otp
// @desc    Send OTP via Twilio SMS
// @access  Public
router.post('/send-otp', async (req, res) => {
  try {
    const { phoneNumber } = req.body;

    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        message: 'Phone number is required'
      });
    }

    // Format phone number (ensure it has country code)
    let formattedPhone = phoneNumber;
    if (!phoneNumber.startsWith('+')) {
      formattedPhone = '+91' + phoneNumber;
    }

    console.log(`📱 Sending OTP to: ${formattedPhone}`);
    
    const result = await twilioService.sendOTP(formattedPhone);
    
    if (result.success) {
      res.status(200).json({
        success: true,
        message: result.message,
        phoneNumber: formattedPhone
      });
    } else {
      res.status(400).json({
        success: false,
        message: result.message
      });
    }

  } catch (error) {
    console.error('Send OTP error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error while sending OTP'
    });
  }
});

// @route   POST /api/auth/verify-otp
// @desc    Verify OTP and login/register user
// @access  Public
router.post('/verify-otp', async (req, res) => {
  try {
    const { phoneNumber, otp } = req.body;

    if (!phoneNumber || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Phone number and OTP are required'
      });
    }

    console.log(`🔍 Verifying OTP for: ${phoneNumber}`);
    
    const verification = await twilioService.verifyOTP(phoneNumber, otp);
    
    if (!verification.success) {
      return res.status(400).json({
        success: false,
        message: verification.message
      });
    }

    // OTP verified, now check if user exists
    let user = await User.findOne({ phone: phoneNumber });

    if (user) {
      // Existing user - login
      user.phoneVerified = true;
      await user.updateLastLogin();
      
      const token = generateJWTToken(user._id);
      
      return res.status(200).json({
        success: true,
        message: 'Login successful',
        data: {
          user: user.getSafeUserData(),
          token,
          isNewUser: false
        }
      });
    } else {
      // New user - needs registration
      return res.status(202).json({
        success: true,
        message: 'Phone verified. Please complete registration.',
        data: {
          phone: phoneNumber,
          requiresRegistration: true
        }
      });
    }

  } catch (error) {
    console.error('Verify OTP error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error while verifying OTP'
    });
  }
});


// @route   POST /api/auth/register
// @desc    Complete registration after OTP verification
// @access  Public
router.post('/register', async (req, res) => {
  try {
    const { name, email, phone } = req.body;

    if (!name || !phone) {
      return res.status(400).json({
        success: false,
        message: 'Name and phone number are required'
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({
      $or: [
        { phone: phone },
        ...(email ? [{ email: email }] : [])
      ]
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'User already exists with this phone or email'
      });
    }

    // Create new user
    const userData = {
      name,
      phone,
      authProvider: 'phone',
      phoneVerified: true,
      isActive: true
    };

    // Add email if provided
    if (email) {
      userData.email = email;
      userData.emailVerified = false;
    }

    const user = new User(userData);
    await user.save();
    await user.updateLastLogin();

    const token = generateJWTToken(user._id);

    res.status(201).json({
      success: true,
      message: 'Registration successful',
      data: {
        user: user.getSafeUserData(),
        token,
        isNewUser: true
      }
    });

  } catch (error) {
    console.error('Registration error:', error);
    
    if (error.code === 11000) {
      const field = Object.keys(error.keyPattern)[0];
      return res.status(400).json({
        success: false,
        message: `User already exists with this ${field}`
      });
    }

    res.status(500).json({
      success: false,
      message: 'Internal server error during registration'
    });
  }
});

// @route   POST /api/auth/google
// @desc    Google OAuth login/register via Firebase
// @access  Public
router.post('/google', async (req, res) => {
  try {
    console.log('🔐 Google authentication request received');
    console.log('📱 Request from:', req.ip);
    
    const { idToken } = req.body;

    if (!idToken) {
      console.log('❌ No Firebase ID token provided');
      return res.status(400).json({
        success: false,
        message: 'Firebase ID token is required'
      });
    }

    console.log('🔍 Verifying Firebase Google ID token...');
    // Verify Firebase Google ID token
    const verification = await verifyFirebaseGoogleToken(idToken);
    
    if (!verification.success) {
      return res.status(400).json({
        success: false,
        message: 'Google token verification failed',
        error: verification.error
      });
    }

    const googleData = verification.userData;

    // Check if user exists by email, Google ID, or Firebase UID
    let user = await User.findOne({
      $or: [
        { email: googleData.email },
        { googleId: googleData.googleId },
        { firebaseUid: googleData.firebaseUid }
      ]
    });

    if (user) {
      // Existing user - update Google info if needed
      let updated = false;
      
      if (!user.googleId && googleData.googleId) {
        user.googleId = googleData.googleId;
        updated = true;
      }
      
      if (!user.firebaseUid && googleData.firebaseUid) {
        user.firebaseUid = googleData.firebaseUid;
        updated = true;
      }
      
      if (!user.emailVerified && googleData.emailVerified) {
        user.emailVerified = true;
        updated = true;
      }
      
      if (!user.profilePicture && googleData.picture) {
        user.profilePicture = googleData.picture;
        updated = true;
      }
      
      // Update auth provider if it was only phone before
      if (user.authProvider === 'phone') {
        user.authProvider = 'both';
        updated = true;
      }

      if (updated) {
        await user.save();
      }
      
      await user.updateLastLogin();

      const token = generateJWTToken(user._id);

      return res.status(200).json({
        success: true,
        message: 'Google login successful',
        data: {
          user: user.getSafeUserData(),
          token,
          isNewUser: false,
          requiresPhoneSetup: !user.phone // Indicate if phone setup is needed
        }
      });
    }

    // New user - create account with Google data
    const userProfile = createUserProfileFromGoogle(googleData);
    userProfile.firebaseUid = googleData.firebaseUid;
    
    const newUser = new User(userProfile);
    await newUser.save();
    await newUser.updateLastLogin();

    const token = generateJWTToken(newUser._id);

    res.status(201).json({
      success: true,
      message: 'Google registration successful',
      data: {
        user: newUser.getSafeUserData(),
        token,
        isNewUser: true,
        showPhonePrompt: true, // Frontend can show optional phone number prompt
        requiresPhoneSetup: true
      }
    });

  } catch (error) {
    console.error('Google auth error:', error);
    
    if (error.code === 11000) {
      const field = Object.keys(error.keyPattern)[0];
      return res.status(400).json({
        success: false,
        message: `Account already exists with this ${field}`
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Internal server error during Google authentication'
    });
  }
});

// @route   POST /api/auth/google/add-phone
// @desc    Add phone number to Google user (after OTP verification via Twilio)
// @access  Private
router.post('/google/add-phone', verifyJWTToken, async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({
        success: false,
        message: 'Phone number is required'
      });
    }

    // Check if phone is already used
    const existingUser = await User.findOne({ phone: phone, _id: { $ne: req.user._id } });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Phone number already registered with another account'
      });
    }

    // Update user with phone number (OTP verification handled separately)
    req.user.phone = phone;
    req.user.phoneVerified = true;
    req.user.authProvider = 'both';
    await req.user.save();

    res.status(200).json({
      success: true,
      message: 'Phone number added successfully',
      data: {
        user: req.user.getSafeUserData()
      }
    });

  } catch (error) {
    console.error('Add phone error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error while adding phone number'
    });
  }
});

// @route   GET /api/auth/me
// @desc    Get current user profile
// @access  Private
router.get('/me', verifyJWTToken, async (req, res) => {
  try {
    res.status(200).json({
      success: true,
      message: 'User profile retrieved successfully',
      data: {
        user: req.user.getSafeUserData()
      }
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// @route   POST /api/auth/refresh
// @desc    Refresh JWT token
// @access  Private
router.post('/refresh', verifyJWTToken, async (req, res) => {
  try {
    const newToken = generateJWTToken(req.user._id);
    
    res.status(200).json({
      success: true,
      message: 'Token refreshed successfully',
      data: {
        token: newToken
      }
    });
  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error during token refresh'
    });
  }
});

// @route   PUT /api/auth/profile
// @desc    Update user profile
// @access  Private
router.put('/profile', verifyJWTToken, async (req, res) => {
  try {
    const { name, email, phone, address } = req.body;
    const user = req.user;
    
    // Update fields if provided
    if (name !== undefined) {
      user.name = name ? name.trim() : '';
    }
    
    if (email !== undefined && email !== user.email) {
      const trimmedEmail = email ? email.toLowerCase().trim() : '';
      
      // Only check for duplicates if email is not empty
      if (trimmedEmail) {
        const existingUser = await User.findOne({ 
          email: trimmedEmail,
          _id: { $ne: user._id }
        });
        
        if (existingUser) {
          return res.status(400).json({
            success: false,
            message: 'Email is already taken by another user'
          });
        }
      }
      
      user.email = trimmedEmail;
      user.emailVerified = false; // Reset verification when email changes
    }
    
    if (phone !== undefined && phone !== user.phone) {
      const trimmedPhone = phone ? phone.trim() : '';
      
      // Only check for duplicates if phone is not empty
      if (trimmedPhone) {
        const existingUser = await User.findOne({ 
          phone: trimmedPhone,
          _id: { $ne: user._id }
        });
        
        if (existingUser) {
          return res.status(400).json({
            success: false,
            message: 'Phone number is already taken by another user'
          });
        }
      }
      
      user.phone = trimmedPhone;
      user.phoneVerified = false; // Reset verification when phone changes
    }
    
    if (address !== undefined) {
      user.address = address ? address.trim() : '';
    }
    
    // Save the updated user
    await user.save();
    
    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      data: {
        user: user.getSafeUserData()
      }
    });
    
  } catch (error) {
    console.error('Profile update error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error while updating profile'
    });
  }
});

// @route   POST /api/auth/verify-email
// @desc    Send email verification
// @access  Private
router.post('/verify-email', verifyJWTToken, async (req, res) => {
  try {
    const user = req.user;
    
    if (!user.email) {
      return res.status(400).json({
        success: false,
        message: 'No email address found. Please add an email first.'
      });
    }
    
    if (user.emailVerified) {
      return res.status(400).json({
        success: false,
        message: 'Email is already verified'
      });
    }
    
    // TODO: Implement actual email verification logic
    // For now, we'll simulate the process
    console.log(`Sending verification email to: ${user.email}`);
    
    res.status(200).json({
      success: true,
      message: 'Verification email sent successfully',
      data: {
        email: user.email
      }
    });
    
  } catch (error) {
    console.error('Email verification error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error while sending verification email'
    });
  }
});

// @route   POST /api/auth/verify-phone
// @desc    Send phone verification OTP
// @access  Private
router.post('/verify-phone', verifyJWTToken, async (req, res) => {
  try {
    const user = req.user;
    
    if (!user.phone) {
      return res.status(400).json({
        success: false,
        message: 'No phone number found. Please add a phone number first.'
      });
    }
    
    if (user.phoneVerified) {
      return res.status(400).json({
        success: false,
        message: 'Phone number is already verified'
      });
    }
    
    // TODO: Implement actual SMS OTP logic
    // For now, we'll simulate the process
    console.log(`Sending verification OTP to: ${user.phone}`);
    
    res.status(200).json({
      success: true,
      message: 'Verification OTP sent successfully',
      data: {
        phone: user.phone
      }
    });
    
  } catch (error) {
    console.error('Phone verification error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error while sending verification OTP'
    });
  }
});

// @route   POST /api/auth/logout
// @desc    Logout user (client-side token removal)
// @access  Private
router.post('/logout', verifyJWTToken, async (req, res) => {
  try {
    // In a more complex setup, you might want to blacklist the token
    // For now, we'll just send a success response
    res.status(200).json({
      success: true,
      message: 'Logout successful'
    });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error during logout'
    });
  }
});

// @route   POST /api/auth/profile-picture
// @desc    Update profile picture (Cloudinary upload)
// @access  Private
router.post('/profile-picture', verifyJWTToken, upload.single('profilePicture'), async (req, res) => {
  try {
    const user = req.user;

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'Profile picture file is required'
      });
    }

    // Upload to Cloudinary
    const CloudinaryService = require('../services/cloudinaryService');
    const uploadResult = await CloudinaryService.uploadImage(
      req.file.path, 
      'ipay/profile-pictures',
      `user_${user._id}_${Date.now()}`
    );

    if (!uploadResult.success) {
      // Delete uploaded file if Cloudinary upload fails
      if (req.file && fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path);
      }
      return res.status(500).json({
        success: false,
        message: 'Failed to upload image to cloud storage',
        error: uploadResult.error
      });
    }

    // Delete old profile picture from Cloudinary if it exists
    if (user.profilePicture && user.profilePicture.includes('cloudinary.com')) {
      const oldPublicId = CloudinaryService.extractPublicId(user.profilePicture);
      if (oldPublicId) {
        await CloudinaryService.deleteImage(oldPublicId);
      }
    }

    // Delete local file after successful Cloudinary upload
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }

    // Update user's profile picture with Cloudinary URL
    user.profilePicture = uploadResult.url;
    await user.save();

    res.json({
      success: true,
      message: 'Profile picture updated successfully',
      data: {
        user: user.getSafeUserData(),
        cloudinaryUrl: uploadResult.url
      }
    });

  } catch (error) {
    console.error('Profile picture update error:', error);
    
    // Delete uploaded file if there was an error
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to update profile picture',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

module.exports = router;

