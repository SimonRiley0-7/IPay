# 🚀 Cloudinary Setup Guide

## Step 1: Create Cloudinary Account

1. Go to [cloudinary.com](https://cloudinary.com)
2. Sign up for a free account
3. Go to your Dashboard
4. Copy your credentials:
   - Cloud Name
   - API Key
   - API Secret

## Step 2: Update Backend Environment Variables

Add these to your `backend/.env` file:

```env
# Cloudinary Configuration (for image uploads)
CLOUDINARY_CLOUD_NAME=your_cloudinary_cloud_name
CLOUDINARY_API_KEY=your_cloudinary_api_key
CLOUDINARY_API_SECRET=your_cloudinary_api_secret
```

## Step 3: Test the Setup

1. Start the backend server:
   ```bash
   cd backend
   node server.js
   ```

2. Run the Flutter app:
   ```bash
   cd frontend
   flutter run
   ```

3. Go to Profile screen and try uploading a profile picture

## ✅ What's Working Now:

- **Cloud Storage**: Images are uploaded to Cloudinary
- **Automatic Optimization**: Images are automatically resized and optimized
- **CDN Delivery**: Images are served via Cloudinary's global CDN
- **Face Detection**: Profile pictures are cropped to focus on faces
- **Multiple Sizes**: Thumbnail, medium, and large versions available
- **Cleanup**: Old images are automatically deleted when new ones are uploaded

## 🎯 Features:

- **Thumbnail URLs**: `CloudinaryService.getThumbnailUrl(url)` - 100x100px
- **Medium URLs**: `CloudinaryService.getMediumUrl(url)` - 400x400px  
- **Large URLs**: `CloudinaryService.getLargeUrl(url)` - 800x800px
- **Custom Sizes**: `CloudinaryService.getOptimizedImageUrl(url, width: 300, height: 300)`

## 📱 Usage in Flutter:

```dart
// Upload profile picture
final result = await CloudinaryService().uploadProfilePicture(imageFile);

// Get optimized URLs
final thumbnailUrl = CloudinaryService.getThumbnailUrl(cloudinaryUrl);
final mediumUrl = CloudinaryService.getMediumUrl(cloudinaryUrl);
```

## 🔧 Backend API:

- **POST** `/api/auth/profile-picture` - Upload profile picture
- **POST** `/api/auth/profile-picture` with `null` - Remove profile picture

The backend automatically handles:
- Image upload to Cloudinary
- Old image cleanup
- Database updates
- Error handling
