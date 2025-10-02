const admin = require('firebase-admin');

// Note: We don't need google-auth-library since we're using Firebase Admin SDK
// Firebase Admin SDK handles Google ID token verification internally

/**
 * Verify Firebase Google ID token
 * @param {string} idToken - Firebase ID token
 * @returns {Object} - Verification result
 */
const verifyFirebaseGoogleToken = async (idToken) => {
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    
    // Check if it's a Google sign-in
    if (decodedToken.firebase.sign_in_provider !== 'google.com') {
      return {
        success: false,
        error: 'Token is not from Google sign-in'
      };
    }
    
    return {
      success: true,
      userData: {
        firebaseUid: decodedToken.uid,
        googleId: decodedToken.sub,
        email: decodedToken.email,
        name: decodedToken.name,
        picture: decodedToken.picture,
        emailVerified: decodedToken.email_verified
      }
    };
  } catch (error) {
    console.error('Firebase Google token verification error:', error);
    return {
      success: false,
      error: error.message
    };
  }
};

/**
 * Extract user data from Google token payload
 * @param {Object} payload - Google token payload
 * @returns {Object} - Formatted user data
 */
const extractGoogleUserData = (payload) => {
  return {
    googleId: payload.sub,
    email: payload.email,
    name: payload.name,
    firstName: payload.given_name,
    lastName: payload.family_name,
    picture: payload.picture,
    emailVerified: payload.email_verified,
    locale: payload.locale
  };
};

/**
 * Generate user profile from Google data
 * @param {Object} googleData - Google user data
 * @returns {Object} - User profile for database
 */
const createUserProfileFromGoogle = (googleData) => {
  return {
    name: googleData.name,
    email: googleData.email,
    googleId: googleData.googleId,
    firebaseUid: googleData.firebaseUid || null,
    authProvider: 'google',
    emailVerified: googleData.emailVerified || false,
    profilePicture: googleData.picture || null,
    isActive: true,
    preferences: {
      language: googleData.locale === 'hi' ? 'hi' : 'en',
      currency: 'INR',
      notifications: {
        email: true,
        sms: false,
        push: true
      }
    }
  };
};

module.exports = {
  verifyFirebaseGoogleToken,
  extractGoogleUserData,
  createUserProfileFromGoogle
};
