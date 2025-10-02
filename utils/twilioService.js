const twilio = require('twilio');

class TwilioService {
  constructor() {
    this.accountSid = process.env.TWILIO_ACCOUNT_SID;
    this.authToken = process.env.TWILIO_AUTH_TOKEN;
    this.phoneNumber = process.env.TWILIO_PHONE_NUMBER;
    
    if (!this.accountSid || !this.authToken || !this.phoneNumber) {
      console.error('⚠️ Twilio credentials not found in environment variables');
      this.client = null;
    } else {
      this.client = twilio(this.accountSid, this.authToken);
      console.log('📱 Twilio service initialized successfully');
    }
    
    // In-memory OTP storage (use Redis in production)
    this.otpStore = new Map();
  }

  // Generate 6-digit OTP
  generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  // Send OTP via SMS
  async sendOTP(phoneNumber) {
    try {
      if (!this.client) {
        throw new Error('Twilio client not initialized');
      }

      const otp = this.generateOTP();
      const message = `Your iPay verification code is: ${otp}. Valid for 5 minutes.`;

      // Send SMS
      const result = await this.client.messages.create({
        body: message,
        from: this.phoneNumber,
        to: phoneNumber
      });

      // Store OTP with expiry (5 minutes)
      this.otpStore.set(phoneNumber, {
        otp: otp,
        expires: Date.now() + 5 * 60 * 1000, // 5 minutes
        attempts: 0
      });

      console.log(`📱 OTP sent to ${phoneNumber}: ${otp} (SID: ${result.sid})`);

      return {
        success: true,
        message: 'OTP sent successfully',
        sid: result.sid
      };

    } catch (error) {
      console.error('❌ Twilio SMS error:', error);
      
      // Handle specific Twilio errors
      if (error.code === 21614) {
        return {
          success: false,
          message: 'Invalid phone number format'
        };
      } else if (error.code === 21408) {
        return {
          success: false,
          message: 'Permission denied to send SMS to this number'
        };
      }
      
      return {
        success: false,
        message: error.message || 'Failed to send OTP'
      };
    }
  }

  // Verify OTP
  async verifyOTP(phoneNumber, inputOTP) {
    try {
      const stored = this.otpStore.get(phoneNumber);

      if (!stored) {
        return {
          success: false,
          message: 'No OTP found. Please request a new one.'
        };
      }

      // Check if OTP expired
      if (Date.now() > stored.expires) {
        this.otpStore.delete(phoneNumber);
        return {
          success: false,
          message: 'OTP expired. Please request a new one.'
        };
      }

      // Check attempt limit
      if (stored.attempts >= 3) {
        this.otpStore.delete(phoneNumber);
        return {
          success: false,
          message: 'Too many failed attempts. Please request a new OTP.'
        };
      }

      // Verify OTP
      if (stored.otp === inputOTP) {
        this.otpStore.delete(phoneNumber);
        console.log(`✅ OTP verified successfully for ${phoneNumber}`);
        return {
          success: true,
          message: 'OTP verified successfully'
        };
      } else {
        // Increment attempts
        stored.attempts += 1;
        this.otpStore.set(phoneNumber, stored);
        
        return {
          success: false,
          message: `Invalid OTP. ${3 - stored.attempts} attempts remaining.`
        };
      }

    } catch (error) {
      console.error('❌ OTP verification error:', error);
      return {
        success: false,
        message: 'OTP verification failed'
      };
    }
  }

  // Resend OTP (with rate limiting)
  async resendOTP(phoneNumber) {
    try {
      const stored = this.otpStore.get(phoneNumber);
      
      // Rate limiting: Allow resend only after 1 minute
      if (stored && (Date.now() - (stored.expires - 5 * 60 * 1000)) < 60 * 1000) {
        return {
          success: false,
          message: 'Please wait 1 minute before requesting a new OTP'
        };
      }

      return await this.sendOTP(phoneNumber);

    } catch (error) {
      console.error('❌ Resend OTP error:', error);
      return {
        success: false,
        message: 'Failed to resend OTP'
      };
    }
  }

  // Get service status
  getStatus() {
    return {
      initialized: !!this.client,
      activeOTPs: this.otpStore.size,
      phoneNumber: this.phoneNumber
    };
  }
}

// Export singleton instance
module.exports = new TwilioService();
