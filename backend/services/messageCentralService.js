const axios = require('axios');
const crypto = require('crypto');

class MessageCentralService {
  constructor() {
    this.baseUrl = 'https://cpaas.messagecentral.com';
    this.customerId = process.env.MESSAGECENTRAL_CUSTOMER_ID;
    this.email = process.env.MESSAGECENTRAL_EMAIL;
    this.password = process.env.MESSAGECENTRAL_PASSWORD
    this.authToken = null;
    this.tokenExpiry = null;
  }

  // Generate authentication token (matching Next.js implementation)
  async getAuthToken() {
    try {
      // Check if we have a valid token
      if (this.authToken && this.tokenExpiry && Date.now() < this.tokenExpiry) {
        return this.authToken;
      }

      console.log('🔄 Generating new MessageCentral auth token...');
      
      const base64String = Buffer.from(this.password).toString('base64');
      
      const response = await axios.get(`${this.baseUrl}/auth/v1/authentication/token`, {
        params: {
          country: 'IN',
          customerId: this.customerId,
          email: this.email,
          key: base64String,
          scope: 'NEW'
        },
        headers: {
          'accept': '*/*'
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

  // Send OTP to mobile number (matching Next.js implementation)
  async sendOTP(mobileNumber, countryCode = '+91') {
    try {
      const authToken = await this.getAuthToken();
      
      // Extract country code and mobile number like Next.js
      const cleanCountryCode = countryCode.substring(1); // Remove + from +91
      const cleanMobileNumber = mobileNumber.substring(3); // Remove +91 from +91XXXXXXXXXX
      
      console.log(`📱 Sending OTP to ${countryCode}${cleanMobileNumber}`);

      const response = await axios.post(`${this.baseUrl}/verification/v3/send`, {}, {
        params: {
          countryCode: cleanCountryCode,
          customerId: this.customerId,
          flowType: 'SMS',
          mobileNumber: cleanMobileNumber
        },
        headers: {
          'Content-Type': 'application/json',
          'accept': '*/*',
          'authToken': authToken
        }
      });

      if (response.data && response.data.responseCode === 200) {
        console.log('✅ OTP sent successfully via MessageCentral');
        return {
          success: true,
          verificationId: response.data.data.verificationId,
          mobileNumber: `${countryCode}${cleanMobileNumber}`,
          message: 'OTP sent successfully'
        };
      } else {
        throw new Error(response.data.message || 'Invalid response from MessageCentral');
      }
    } catch (error) {
      console.error('❌ MessageCentral send OTP error:', error.response?.data || error.message);
      return {
        success: false,
        message: error.response?.data?.message || 'Failed to send OTP. Please try again.',
        error: error.response?.data || error.message
      };
    }
  }

  // Verify OTP (matching Next.js implementation)
  async verifyOTP(verificationId, otp, mobileNumber, countryCode = '+91') {
    try {
      const authToken = await this.getAuthToken();
      
      // Extract country code and mobile number like Next.js
      const cleanCountryCode = countryCode.substring(1); // Remove + from +91
      const cleanMobileNumber = mobileNumber.substring(3); // Remove +91 from +91XXXXXXXXXX
      
      console.log(`🔍 Verifying OTP for verification ID: ${verificationId}`);

      const response = await axios.get(`${this.baseUrl}/verification/v3/validateOtp`, {
        params: {
          countryCode: cleanCountryCode,
          mobileNumber: cleanMobileNumber,
          verificationId: verificationId,
          customerId: this.customerId,
          code: otp
        },
        headers: {
          'accept': 'application/json',
          'authToken': authToken
        }
      });

      if (response.data && (response.data.responseCode === 200 || response.data.message === 'SUCCESS' || response.data.data?.status === 'VERIFIED')) {
        console.log('✅ OTP verified successfully via MessageCentral');
        return {
          success: true,
          message: 'OTP verified successfully'
        };
      } else {
        console.log('❌ OTP verification failed:', response.data);
        return {
          success: false,
          message: response.data.message || 'Invalid OTP. Please try again.',
          error: response.data
        };
      }
    } catch (error) {
      console.error('❌ MessageCentral verify OTP error:', error.response?.data || error.message);
      return {
        success: false,
        message: error.response?.data?.message || 'OTP verification failed. Please try again.',
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
