# 🚀 Cloud Deployment Guide for iPay Backend

This guide will help you deploy your iPay backend to cloud platforms like Render or Railway, making your app accessible to everyone.

## 📋 Prerequisites

- [x] MongoDB Atlas account (free tier available)
- [x] Cloudinary account (free tier available)
- [x] Render/Railway account (free tier available)
- [x] GitHub repository with your code

## 🌐 Step 1: Database Setup (MongoDB Atlas)

### 1.1 Create MongoDB Atlas Account
1. Go to [MongoDB Atlas](https://www.mongodb.com/atlas)
2. Sign up for a free account
3. Create a new cluster (choose the free M0 tier)

### 1.2 Configure Database Access
1. Go to "Database Access" → "Add New Database User"
2. Create a user with read/write permissions
3. Note down the username and password

### 1.3 Configure Network Access
1. Go to "Network Access" → "Add IP Address"
2. Add `0.0.0.0/0` to allow access from anywhere (for cloud deployment)
3. Or add your cloud provider's IP ranges

### 1.4 Get Connection String
1. Go to "Clusters" → "Connect" → "Connect your application"
2. Copy the connection string
3. Replace `<password>` with your actual password
4. Example: `mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/neocart?retryWrites=true&w=majority`

## ☁️ Step 2: Cloud Storage Setup (Cloudinary)

### 2.1 Create Cloudinary Account
1. Go to [Cloudinary](https://cloudinary.com)
2. Sign up for a free account
3. Go to Dashboard → Settings → API Keys

### 2.2 Get API Credentials
Note down these values:
- Cloud Name
- API Key
- API Secret

## 🚀 Step 3: Deploy to Render (Recommended)

### 3.1 Prepare Your Repository
1. Push your code to GitHub
2. Make sure `backend/server_production.js` exists
3. Make sure `backend/package_production.json` exists

### 3.2 Deploy on Render
1. Go to [Render](https://render.com)
2. Sign up with GitHub
3. Click "New" → "Web Service"
4. Connect your GitHub repository
5. Configure the service:
   - **Name**: `ipay-backend`
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Node Version**: `18`

### 3.3 Set Environment Variables
In Render dashboard, go to "Environment" tab and add:

```env
NODE_ENV=production
MONGODB_URI=mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/neocart?retryWrites=true&w=majority
JWT_SECRET=your-super-secret-jwt-key-here
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
TWILIO_ACCOUNT_SID=your-twilio-sid
TWILIO_AUTH_TOKEN=your-twilio-token
TWILIO_PHONE_NUMBER=your-twilio-phone
RAZORPAY_KEY_ID=your-razorpay-key
RAZORPAY_KEY_SECRET=your-razorpay-secret
```

### 3.4 Deploy
1. Click "Create Web Service"
2. Wait for deployment to complete
3. Note down your service URL (e.g., `https://ipay-backend.onrender.com`)

## 🚂 Step 4: Deploy to Railway (Alternative)

### 4.1 Deploy on Railway
1. Go to [Railway](https://railway.app)
2. Sign up with GitHub
3. Click "New Project" → "Deploy from GitHub repo"
4. Select your repository
5. Railway will auto-detect it's a Node.js project

### 4.2 Set Environment Variables
In Railway dashboard, go to "Variables" tab and add the same environment variables as above.

### 4.3 Deploy
1. Railway will automatically deploy
2. Note down your service URL (e.g., `https://ipay-backend-production.up.railway.app`)

## 📱 Step 5: Update Frontend Configuration

### 5.1 Update Network Config
Replace the production URL in `frontend/lib/config/network_config_production.dart`:

```dart
static const String productionURL = 'https://your-actual-url.onrender.com';
```

### 5.2 Switch to Production Config
In your Flutter app, update the import in your main files:

```dart
// Change from:
import 'package:ipay/config/network_config.dart';

// To:
import 'package:ipay/config/network_config_production.dart';
```

### 5.3 Build for Production
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

## 🔧 Step 6: Backend Configuration Updates

### 6.1 Update CORS Settings
In `backend/server_production.js`, update the allowed origins:

```javascript
const allowedOrigins = [
  'https://your-frontend-app.vercel.app', // If you deploy frontend to Vercel
  'https://your-app-name.onrender.com',   // Your actual frontend URL
  'http://localhost:3000',                // For local development
  'http://localhost:8080',                // For local development
];
```

### 6.2 Update Package.json
Rename `package_production.json` to `package.json` in your backend folder, or update your existing `package.json` to use the production server.

## ✅ Step 7: Testing Your Deployment

### 7.1 Test Backend Health
Visit: `https://your-backend-url.onrender.com/health`

Expected response:
```json
{
  "status": "OK",
  "timestamp": "2025-10-02T15:00:00.000Z",
  "uptime": 123.45,
  "environment": "production"
}
```

### 7.2 Test API Endpoints
Visit: `https://your-backend-url.onrender.com/api/auth`

Expected response:
```json
{
  "message": "Auth routes working",
  "timestamp": "2025-10-02T15:00:00.000Z"
}
```

### 7.3 Test with Flutter App
1. Update your Flutter app with the production URL
2. Build and install the app
3. Test all features (login, products, cart, orders, etc.)

## 🚨 Common Issues & Solutions

### Issue 1: CORS Errors
**Problem**: Frontend can't connect to backend
**Solution**: Update CORS origins in `server_production.js`

### Issue 2: Database Connection Failed
**Problem**: MongoDB connection errors
**Solution**: Check MongoDB Atlas network access settings

### Issue 3: Environment Variables Not Working
**Problem**: Backend can't access environment variables
**Solution**: Double-check variable names and values in cloud platform

### Issue 4: File Upload Issues
**Problem**: Profile picture upload fails
**Solution**: Verify Cloudinary credentials and file size limits

## 📊 Monitoring & Maintenance

### 7.1 Monitor Performance
- Use Render/Railway dashboards to monitor uptime
- Check logs for errors
- Monitor database usage

### 7.2 Regular Updates
- Keep dependencies updated
- Monitor security advisories
- Backup your database regularly

## 🎉 You're Done!

Your iPay backend is now deployed and accessible worldwide! 

**Next Steps:**
1. Deploy your Flutter frontend to Google Play Store
2. Set up custom domain (optional)
3. Configure SSL certificates (usually automatic)
4. Set up monitoring and alerts

## 📞 Support

If you encounter any issues:
1. Check the logs in your cloud platform dashboard
2. Verify all environment variables are set correctly
3. Test the backend endpoints directly
4. Check MongoDB Atlas connection status

---

**Happy Deploying! 🚀✨**

