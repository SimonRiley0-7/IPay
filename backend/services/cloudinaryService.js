const cloudinary = require('../config/cloudinary');
const fs = require('fs');
const path = require('path');

class CloudinaryService {
  /**
   * Upload image to Cloudinary
   * @param {string} filePath - Local file path
   * @param {string} folder - Cloudinary folder (optional)
   * @param {string} publicId - Custom public ID (optional)
   * @returns {Promise<Object>} - Cloudinary upload result
   */
  static async uploadImage(filePath, folder = 'ipay/profile-pictures', publicId = null) {
    try {
      const options = {
        folder: folder,
        resource_type: 'auto',
        quality: 'auto:good',
        fetch_format: 'auto',
        transformation: [
          { width: 400, height: 400, crop: 'fill', gravity: 'face' },
          { quality: 'auto:good' }
        ]
      };

      if (publicId) {
        options.public_id = publicId;
      }

      const result = await cloudinary.uploader.upload(filePath, options);
      
      // Clean up local file after upload
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }

      return {
        success: true,
        url: result.secure_url,
        publicId: result.public_id,
        assetId: result.asset_id
      };
    } catch (error) {
      console.error('Cloudinary upload error:', error);
      
      // Clean up local file even if upload failed
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }

      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Delete image from Cloudinary
   * @param {string} publicId - Cloudinary public ID
   * @returns {Promise<Object>} - Deletion result
   */
  static async deleteImage(publicId) {
    try {
      const result = await cloudinary.uploader.destroy(publicId);
      
      return {
        success: result.result === 'ok',
        result: result.result
      };
    } catch (error) {
      console.error('Cloudinary delete error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Extract public ID from Cloudinary URL
   * @param {string} url - Cloudinary URL
   * @returns {string|null} - Public ID or null
   */
  static extractPublicId(url) {
    if (!url || !url.includes('cloudinary.com')) {
      return null;
    }

    const parts = url.split('/');
    const filename = parts[parts.length - 1];
    const publicId = filename.split('.')[0];
    
    // Reconstruct full public ID with folder
    const folderIndex = url.indexOf('/ipay/');
    if (folderIndex !== -1) {
      const folderPath = url.substring(folderIndex + 1, url.lastIndexOf('/'));
      return `${folderPath}/${publicId}`;
    }
    
    return publicId;
  }
}

module.exports = CloudinaryService;
