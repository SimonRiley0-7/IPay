const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const verifyJWTToken = require('../middleware/auth');
const User = require('../models/User');

const router = express.Router();

// Create uploads directory if it doesn't exist
const uploadsDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Configure multer for image uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadsDir);
  },
  filename: function (req, file, cb) {
    // Generate unique filename with timestamp
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'profile-' + uniqueSuffix + path.extname(file.originalname));
  }
});

// File filter to only allow images
const fileFilter = (req, file, cb) => {
  if (file.mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Only image files are allowed!'), false);
  }
};

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: fileFilter
});

// @route   POST /api/upload/profile-picture
// @desc    Upload profile picture
// @access  Private
router.post('/profile-picture', verifyJWTToken, (req, res) => {
  upload.single('profilePicture')(req, res, async (err) => {
    try {
      if (err) {
        return res.status(400).json({
          success: false,
          message: err.message
        });
      }

      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: 'No image file provided'
        });
      }

      const userId = req.user._id;
      const imagePath = `/uploads/${req.file.filename}`;
      const fullImageUrl = `${req.protocol}://${req.get('host')}${imagePath}`;

      // Update user's profile picture in database
      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'User not found'
        });
      }

      // Delete old profile picture if it exists and is not a URL
      if (user.profilePicture && !user.profilePicture.startsWith('http')) {
        const oldImagePath = path.join(__dirname, '..', user.profilePicture);
        if (fs.existsSync(oldImagePath)) {
          fs.unlinkSync(oldImagePath);
        }
      }

      // Update user's profile picture
      user.profilePicture = fullImageUrl;
      await user.save();

      res.json({
        success: true,
        message: 'Profile picture updated successfully',
        data: {
          profilePicture: fullImageUrl
        }
      });

    } catch (error) {
      console.error('Profile picture upload error:', error);
      
      // Delete uploaded file if there was an error
      if (req.file) {
        const filePath = path.join(uploadsDir, req.file.filename);
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
        }
      }

      res.status(500).json({
        success: false,
        message: 'Failed to upload profile picture',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  });
});

// @route   DELETE /api/upload/profile-picture
// @desc    Remove profile picture
// @access  Private
router.delete('/profile-picture', verifyJWTToken, async (req, res) => {
  try {
    const userId = req.user._id;
    const user = await User.findById(userId);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Delete old profile picture file if it exists and is not a URL
    if (user.profilePicture && !user.profilePicture.startsWith('http')) {
      const oldImagePath = path.join(__dirname, '..', user.profilePicture);
      if (fs.existsSync(oldImagePath)) {
        fs.unlinkSync(oldImagePath);
      }
    }

    // Remove profile picture from user
    user.profilePicture = null;
    await user.save();

    res.json({
      success: true,
      message: 'Profile picture removed successfully',
      data: {
        profilePicture: null
      }
    });

  } catch (error) {
    console.error('Profile picture removal error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to remove profile picture',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

module.exports = router;
