const jwt = require('jsonwebtoken');
const admin = require('firebase-admin');
const User = require('../models/User');

// Initialize Firebase Admin (only if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      privateKeyId: process.env.FIREBASE_PRIVATE_KEY_ID,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    })
  });
}

// Middleware to verify JWT token
const verifyJWTToken = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Access denied. No token provided.'
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(decoded.userId).select('-__v');
    
    if (!user || !user.isActive) {
      return res.status(401).json({
        success: false,
        message: 'Invalid token or user not found.'
      });
    }

    req.user = user;
    next();
  } catch (error) {
    console.error('JWT verification error:', error);
    console.error('Token received:', token ? token.substring(0, 20) + '...' : 'No token');
    res.status(401).json({
      success: false,
      message: 'Invalid token.'
    });
  }
};

// Middleware to verify Firebase ID token
const verifyFirebaseToken = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Access denied. No Firebase token provided.'
      });
    }

    const decodedToken = await admin.auth().verifyIdToken(token);
    req.firebaseUser = decodedToken;
    next();
  } catch (error) {
    console.error('Firebase token verification error:', error);
    res.status(401).json({
      success: false,
      message: 'Invalid Firebase token.'
    });
  }
};

// Middleware to verify either JWT or Firebase token
const verifyAnyToken = async (req, res, next) => {
  const token = req.header('Authorization')?.replace('Bearer ', '');
  
  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Access denied. No token provided.'
    });
  }

  try {
    // Try JWT first
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(decoded.userId).select('-__v');
    
    if (user && user.isActive) {
      req.user = user;
      req.tokenType = 'jwt';
      return next();
    }
  } catch (jwtError) {
    // JWT failed, try Firebase token
    try {
      const decodedToken = await admin.auth().verifyIdToken(token);
      const user = await User.findByFirebaseUid(decodedToken.uid);
      
      if (user && user.isActive) {
        req.user = user;
        req.firebaseUser = decodedToken;
        req.tokenType = 'firebase';
        return next();
      }
    } catch (firebaseError) {
      console.error('Token verification failed:', { jwtError, firebaseError });
    }
  }

  res.status(401).json({
    success: false,
    message: 'Invalid token.'
  });
};

// Optional auth middleware (doesn't fail if no token)
const optionalAuth = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (token) {
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const user = await User.findById(decoded.userId).select('-__v');
        
        if (user && user.isActive) {
          req.user = user;
        }
      } catch (error) {
        // Token invalid, but continue without user
        console.log('Optional auth failed, continuing without user');
      }
    }
    
    next();
  } catch (error) {
    console.error('Optional auth error:', error);
    next();
  }
};

// Generate JWT token
const generateJWTToken = (userId) => {
  return jwt.sign(
    { userId },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
};


module.exports = {
  verifyJWTToken,
  verifyFirebaseToken,
  verifyAnyToken,
  optionalAuth,
  generateJWTToken,
  firebaseAdmin: admin
};


