const { body, param, query, validationResult } = require('express-validator');

// Helper to handle validation errors
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array().map(error => ({
        field: error.path,
        message: error.msg,
        value: error.value
      }))
    });
  }
  next();
};

// Phone number validation
const validatePhone = () => [
  body('phone')
    .optional()
    .isMobilePhone('any', { strictMode: false })
    .withMessage('Please provide a valid phone number')
    .isLength({ min: 10, max: 15 })
    .withMessage('Phone number must be between 10-15 digits'),
  handleValidationErrors
];

// Email validation
const validateEmail = () => [
  body('email')
    .optional()
    .isEmail()
    .withMessage('Please provide a valid email address')
    .normalizeEmail(),
  handleValidationErrors
];

// Name validation
const validateName = () => [
  body('name')
    .notEmpty()
    .withMessage('Name is required')
    .isLength({ min: 2, max: 100 })
    .withMessage('Name must be between 2-100 characters')
    .matches(/^[a-zA-Z\s.'-]+$/)
    .withMessage('Name can only contain letters, spaces, dots, hyphens and apostrophes'),
  handleValidationErrors
];

// Firebase ID Token validation
const validateFirebaseToken = () => [
  body('idToken')
    .notEmpty()
    .withMessage('Firebase ID token is required')
    .isString()
    .withMessage('ID token must be a string'),
  handleValidationErrors
];

// Phone login validation
const validatePhoneLogin = () => [
  body('phone')
    .notEmpty()
    .withMessage('Phone number is required')
    .isMobilePhone('any', { strictMode: false })
    .withMessage('Please provide a valid phone number'),
  body('idToken')
    .notEmpty()
    .withMessage('Firebase ID token is required'),
  handleValidationErrors
];

// User registration validation
const validateUserRegistration = () => [
  body('name')
    .notEmpty()
    .withMessage('Name is required')
    .isLength({ min: 2, max: 100 })
    .withMessage('Name must be between 2-100 characters')
    .matches(/^[a-zA-Z\s.'-]+$/)
    .withMessage('Name can only contain letters, spaces, dots, hyphens and apostrophes'),
  body('email')
    .optional()
    .isEmail()
    .withMessage('Please provide a valid email address')
    .normalizeEmail(),
  body('phone')
    .optional()
    .isMobilePhone('any', { strictMode: false })
    .withMessage('Please provide a valid phone number'),
  body('authProvider')
    .isIn(['phone', 'google', 'both'])
    .withMessage('Auth provider must be phone, google, or both'),
  handleValidationErrors
];

// Google login validation
const validateGoogleLogin = () => [
  body('idToken')
    .notEmpty()
    .withMessage('Google ID token is required'),
  body('userData')
    .isObject()
    .withMessage('User data is required'),
  body('userData.name')
    .notEmpty()
    .withMessage('Name is required'),
  body('userData.email')
    .isEmail()
    .withMessage('Valid email is required'),
  handleValidationErrors
];

// Address validation
const validateAddress = () => [
  body('type')
    .optional()
    .isIn(['home', 'work', 'other'])
    .withMessage('Address type must be home, work, or other'),
  body('street')
    .notEmpty()
    .withMessage('Street address is required')
    .isLength({ max: 200 })
    .withMessage('Street address cannot exceed 200 characters'),
  body('city')
    .notEmpty()
    .withMessage('City is required')
    .isLength({ max: 50 })
    .withMessage('City cannot exceed 50 characters'),
  body('state')
    .notEmpty()
    .withMessage('State is required')
    .isLength({ max: 50 })
    .withMessage('State cannot exceed 50 characters'),
  body('pincode')
    .notEmpty()
    .withMessage('Pincode is required')
    .matches(/^[0-9]{6}$/)
    .withMessage('Pincode must be 6 digits'),
  body('country')
    .optional()
    .isLength({ max: 50 })
    .withMessage('Country cannot exceed 50 characters'),
  handleValidationErrors
];

// Profile update validation
const validateProfileUpdate = () => [
  body('name')
    .optional()
    .isLength({ min: 2, max: 100 })
    .withMessage('Name must be between 2-100 characters')
    .matches(/^[a-zA-Z\s.'-]+$/)
    .withMessage('Name can only contain letters, spaces, dots, hyphens and apostrophes'),
  body('email')
    .optional()
    .isEmail()
    .withMessage('Please provide a valid email address')
    .normalizeEmail(),
  body('preferences.language')
    .optional()
    .isIn(['en', 'hi', 'ta', 'te', 'bn'])
    .withMessage('Language must be one of: en, hi, ta, te, bn'),
  body('preferences.currency')
    .optional()
    .isIn(['INR', 'USD'])
    .withMessage('Currency must be INR or USD'),
  handleValidationErrors
];

// Pagination validation
const validatePagination = () => [
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Page must be a positive integer'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100'),
  handleValidationErrors
];

// ObjectId validation
const validateObjectId = (paramName = 'id') => [
  param(paramName)
    .isMongoId()
    .withMessage(`Invalid ${paramName} format`),
  handleValidationErrors
];

module.exports = {
  handleValidationErrors,
  validatePhone,
  validateEmail,
  validateName,
  validateFirebaseToken,
  validatePhoneLogin,
  validateUserRegistration,
  validateGoogleLogin,
  validateAddress,
  validateProfileUpdate,
  validatePagination,
  validateObjectId
};


