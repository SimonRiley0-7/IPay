# 🛒 iPay - Smart Shopping App

A complete e-commerce mobile application built with Flutter and Node.js, featuring barcode scanning, wallet management, and order processing.

## 🌟 Features

- **🔐 Authentication**: Google Sign-In, OTP verification
- **📱 Barcode Scanning**: Add products by scanning barcodes
- **💳 Wallet System**: Add money via Razorpay, manage transactions
- **🛍️ Shopping Cart**: Add/remove items, quantity management
- **📦 Order Management**: Place orders, track status, download receipts
- **👤 User Profile**: Update profile picture, manage personal info
- **📊 Order History**: View past orders with detailed information

## 🏗️ Architecture

- **Frontend**: Flutter (Dart)
- **Backend**: Node.js + Express
- **Database**: MongoDB Atlas
- **Storage**: Cloudinary (images)
- **Payments**: Razorpay
- **SMS**: Twilio

## 🚀 Quick Start

### Prerequisites
- Flutter SDK
- Node.js
- MongoDB Atlas account
- Cloudinary account
- Razorpay account
- Twilio account

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/ipay-app.git
   cd ipay-app
   ```

2. **Backend Setup**
   ```bash
   cd backend
   npm install
   cp env.example .env
   # Update .env with your credentials
   npm start
   ```

3. **Frontend Setup**
   ```bash
   cd frontend
   flutter pub get
   flutter run
   ```

### Cloud Deployment

See [CLOUD_DEPLOYMENT_GUIDE.md](CLOUD_DEPLOYMENT_GUIDE.md) for detailed deployment instructions.

## 📱 APK Distribution

To build APK for distribution:

1. Deploy backend to cloud (Render/Railway)
2. Update `frontend/lib/config/app_config.dart`:
   ```dart
   static const bool isProduction = true;
   static const String productionBackendUrl = 'https://your-app.onrender.com';
   ```
3. Build APK:
   ```bash
   flutter build apk --release
   ```

## 🔧 Configuration

### Backend Environment Variables
```env
NODE_ENV=production
MONGODB_URI=mongodb+srv://...
JWT_SECRET=your-secret
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
TWILIO_ACCOUNT_SID=your-twilio-sid
TWILIO_AUTH_TOKEN=your-twilio-token
TWILIO_PHONE_NUMBER=your-twilio-phone
RAZORPAY_KEY_ID=your-razorpay-key
RAZORPAY_KEY_SECRET=your-razorpay-secret
```

### Frontend Configuration
- Update `app_config.dart` for production URLs
- Set `isProduction = true` for APK builds

## 📂 Project Structure

```
ipay-app/
├── frontend/                 # Flutter app
│   ├── lib/
│   │   ├── config/          # App configuration
│   │   ├── models/          # Data models
│   │   ├── screens/         # UI screens
│   │   ├── services/        # API services
│   │   └── widgets/         # Reusable widgets
│   └── assets/              # Images, fonts
├── backend/                 # Node.js API
│   ├── config/             # Database config
│   ├── controllers/        # Route controllers
│   ├── middleware/         # Auth, validation
│   ├── models/             # Database models
│   ├── routes/             # API routes
│   └── services/           # External services
└── docs/                   # Documentation
```

## 🛠️ Development

### Backend Development
- Uses Express.js with MongoDB
- JWT authentication
- File upload with Multer + Cloudinary
- RESTful API design

### Frontend Development
- Flutter with Material Design
- State management with setState
- HTTP client with Dio
- Image handling with CachedNetworkImage

## 📱 Screenshots

[Add screenshots of your app here]

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Your Name**
- GitHub: [@yourusername](https://github.com/yourusername)
- Email: your.email@example.com

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Node.js community for excellent packages
- MongoDB Atlas for database hosting
- Cloudinary for image management
- Razorpay for payment processing

---

**Happy Coding! 🚀✨**