const express = require('express');
const { body, validationResult } = require('express-validator');
const messageCentralService = require('../services/messageCentralService');
const User = require('../models/User');
const { generateJWTToken } = require('../middleware/auth');

const router = express.Router();

// @route   POST /api/otp/send
// @desc    Send OTP to mobile number
// @access  Public
router.post('/send', [
  body('mobileNumber')
    .isMobilePhone('en-IN')
    .withMessage('Please provide a valid Indian mobile number')
    .isLength({ min: 10, max: 10 })
    .withMessage('Mobile number must be exactly 10 digits')
], async (req, res) => {
  try {
    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const { mobileNumber } = req.body;
    
    // Format mobile number with country code
    const formattedNumber = `+91${mobileNumber}`;
    
    console.log(`📱 Sending OTP to: ${formattedNumber}`);

    // Send OTP using MessageCentral
    const result = await messageCentralService.sendOTP(formattedNumber, '+91');
    
    if (result.success) {
      res.status(200).json({
        success: true,
        message: 'OTP sent successfully',
        data: {
          verificationId: result.verificationId,
          mobileNumber: result.mobileNumber,
          message: 'OTP sent to your mobile number'
        }
      });
    } else {
      res.status(400).json({
        success: false,
        message: result.message || 'Failed to send OTP',
        error: result.error
      });
    }
  } catch (error) {
    console.error('Send OTP error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// @route   POST /api/otp/verify
// @desc    Verify OTP and login/register user
// @access  Public
router.post('/verify', [
  body('verificationId')
    .notEmpty()
    .withMessage('Verification ID is required'),
  body('otp')
    .isLength({ min: 4, max: 6 })
    .withMessage('OTP must be between 4 and 6 digits')
    .isNumeric()
    .withMessage('OTP must contain only numbers'),
  body('mobileNumber')
    .isMobilePhone('en-IN')
    .withMessage('Please provide a valid Indian mobile number')
    .isLength({ min: 10, max: 10 })
    .withMessage('Mobile number must be exactly 10 digits')
], async (req, res) => {
  try {
    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const { verificationId, otp, mobileNumber } = req.body;
    
    console.log(`🔍 Verifying OTP for mobile: ${mobileNumber}`);

    // Verify OTP using MessageCentral
    const verifyResult = await messageCentralService.verifyOTP(verificationId, otp);
    
    if (!verifyResult.success) {
      return res.status(400).json({
        success: false,
        message: verifyResult.message || 'Invalid OTP',
        error: verifyResult.error
      });
    }

    // OTP verified successfully, now handle user login/registration
    const formattedNumber = `+91${mobileNumber}`;
    
    try {
      // Check if user exists with this mobile number
      let user = await User.findOne({ phone: formattedNumber });
      
      if (!user) {
        // Create new user
        user = new User({
          phone: formattedNumber,
          isPhoneVerified: true,
          isActive: true,
          createdAt: new Date()
        });
        
        await user.save();
        console.log('✅ New user created:', user._id);
      } else {
        // Update existing user's phone verification status
        user.isPhoneVerified = true;
        await user.save();
        console.log('✅ Existing user phone verified:', user._id);
      }

      // Generate JWT token
      const token = generateJWTToken(user._id);
      
      res.status(200).json({
        success: true,
        message: 'OTP verified successfully',
        data: {
          user: user.getSafeUserData(),
          token: token,
          isNewUser: !user.name || user.name.trim() === ''
        }
      });
      
    } catch (userError) {
      console.error('User creation/update error:', userError);
      res.status(500).json({
        success: false,
        message: 'OTP verified but failed to process user data'
      });
    }
    
  } catch (error) {
    console.error('Verify OTP error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// @route   POST /api/otp/resend
// @desc    Resend OTP to mobile number
// @access  Public
router.post('/resend', [
  body('mobileNumber')
    .isMobilePhone('en-IN')
    .withMessage('Please provide a valid Indian mobile number')
    .isLength({ min: 10, max: 10 })
    .withMessage('Mobile number must be exactly 10 digits')
], async (req, res) => {
  try {
    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const { mobileNumber } = req.body;
    const formattedNumber = `+91${mobileNumber}`;
    
    console.log(`🔄 Resending OTP to: ${formattedNumber}`);

    // Send OTP using MessageCentral
    const result = await messageCentralService.sendOTP(formattedNumber, '+91');
    
    if (result.success) {
      res.status(200).json({
        success: true,
        message: 'OTP resent successfully',
        data: {
          verificationId: result.verificationId,
          mobileNumber: result.mobileNumber,
          message: 'OTP resent to your mobile number'
        }
      });
    } else {
      res.status(400).json({
        success: false,
        message: result.message || 'Failed to resend OTP',
        error: result.error
      });
    }
  } catch (error) {
    console.error('Resend OTP error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// @route   GET /api/otp/test
// @desc    Test MessageCentral connection
// @access  Public
router.get('/test', async (req, res) => {
  try {
    const result = await messageCentralService.testConnection();
    
    res.status(result.success ? 200 : 500).json({
      success: result.success,
      message: result.message,
      data: {
        service: 'MessageCentral',
        status: result.success ? 'Connected' : 'Failed',
        token: result.token
      }
    });
  } catch (error) {
    console.error('Test MessageCentral error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to test MessageCentral connection',
      error: error.message
    });
  }
});

module.exports = router;
