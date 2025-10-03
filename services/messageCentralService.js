const axios = require('axios');
const crypto = require('crypto');

class MessageCentralService {
  constructor() {
    this.baseUrl = 'https://cpaas.messagecentral.com';
    this.customerId = process.env.MESSAGECENTRAL_CUSTOMER_ID;
    this.email = process.env.MESSAGECENTRAL_EMAIL;
    this.password = process.env.MESSAGECENTRAL_PASSWORD;
    this.senderId = process.env.MESSAGECENTRAL_SENDER_ID || 'iPay';
    this.authToken = null;
    this.tokenExpiry = null;
  }

  // Generate authentication token
  async getAuthToken() {
    try {
      // Check if we have a valid token
      if (this.authToken && this.tokenExpiry && Date.now() < this.tokenExpiry) {
        return this.authToken;
      }

      console.log('🔄 Generating new MessageCentral auth token...');
      
      const key = Buffer.from(this.password).toString('base64');
      
      const response = await axios.get(`${this.baseUrl}/auth/v1/authentication/token`, {
        params: {
          customerId: this.customerId,
          key: key,
          scope: 'NEW',
          country: 'IN', // India
          email: this.email
        }
      });

      if (response.data && response.data.token) {
        this.authToken = response.data.token;
        // Set token expiry to 1 hour (3600000 ms)
        this.tokenExpiry = Date.now() + 3600000;
        console.log('✅ MessageCentral auth token generated successfully');
        return this.authToken;
      } else {
        throw new Error('Failed to get auth token from MessageCentral');
      }
    } catch (error) {
      console.error('❌ MessageCentral auth token error:', error.response?.data || error.message);
      throw new Error('Failed to authenticate with MessageCentral');
    }
  }

  // Send OTP to mobile number
  async sendOTP(mobileNumber, countryCode = '+91') {
    try {
      const authToken = await this.getAuthToken();
      
      // Remove + from country code if present
      const cleanCountryCode = countryCode.replace('+', '');
      
      // Remove + from mobile number if present
      const cleanMobileNumber = mobileNumber.replace('+', '').replace(countryCode, '');
      
      console.log(`📱 Sending OTP to ${countryCode}${cleanMobileNumber}`);

      const response = await axios.post(`${this.baseUrl}/verification/v3/send`, {
        countryCode: cleanCountryCode,
        flowType: 'SMS',
        mobileNumber: cleanMobileNumber,
        senderId: this.senderId,
        type: 'SMS',
        message: `Your iPay verification code is: {{otp}}. Valid for 5 minutes. Do not share this code with anyone.`,
        messageType: 'OTP'
      }, {
        headers: {
          'Authorization': `Bearer ${authToken}`,
          'Content-Type': 'application/json'
        }
      });

      if (response.data && response.data.verificationId) {
        console.log('✅ OTP sent successfully via MessageCentral');
        return {
          success: true,
          verificationId: response.data.verificationId,
          mobileNumber: `${countryCode}${cleanMobileNumber}`,
          message: 'OTP sent successfully'
        };
      } else {
        throw new Error('Invalid response from MessageCentral');
      }
    } catch (error) {
      console.error('❌ MessageCentral send OTP error:', error.response?.data || error.message);
      return {
        success: false,
        message: 'Failed to send OTP. Please try again.',
        error: error.response?.data || error.message
      };
    }
  }

  // Verify OTP
  async verifyOTP(verificationId, otp) {
    try {
      const authToken = await this.getAuthToken();
      
      console.log(`🔍 Verifying OTP for verification ID: ${verificationId}`);

      const response = await axios.post(`${this.baseUrl}/verification/v3/validate`, {
        verificationId: verificationId,
        otp: otp
      }, {
        headers: {
          'Authorization': `Bearer ${authToken}`,
          'Content-Type': 'application/json'
        }
      });

      if (response.data && response.data.responseCode === '200') {
        console.log('✅ OTP verified successfully via MessageCentral');
        return {
          success: true,
          message: 'OTP verified successfully'
        };
      } else {
        console.log('❌ OTP verification failed:', response.data);
        return {
          success: false,
          message: 'Invalid OTP. Please try again.',
          error: response.data
        };
      }
    } catch (error) {
      console.error('❌ MessageCentral verify OTP error:', error.response?.data || error.message);
      return {
        success: false,
        message: 'OTP verification failed. Please try again.',
        error: error.response?.data || error.message
      };
    }
  }

  // Test connection to MessageCentral
  async testConnection() {
    try {
      const authToken = await this.getAuthToken();
      return {
        success: true,
        message: 'MessageCentral connection successful',
        token: authToken ? 'Generated' : 'Failed'
      };
    } catch (error) {
      return {
        success: false,
        message: 'MessageCentral connection failed',
        error: error.message
      };
    }
  }
}

module.exports = new MessageCentralService();
